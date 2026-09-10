#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "usage: $0 /absolute/path/to/Anchor macOS.app"
  exit 64
fi

app_path=$1
if [[ ! -d "$app_path" ]]; then
  print -u2 "Anchor app not found: $app_path"
  exit 66
fi

validation_dir=$(mktemp -d /tmp/anchor-mac-local-e2e.XXXXXX)
codex_file="$validation_dir/session.jsonl"
touch "$codex_file"
app_pid=''

stop_validation_app() {
  local target_pid=$app_pid
  local attempt
  app_pid=''
  if [[ -z "$target_pid" ]] || ! kill -0 "$target_pid" 2>/dev/null; then
    return 0
  fi
  kill "$target_pid" 2>/dev/null || true
  for attempt in {1..40}; do
    if ! kill -0 "$target_pid" 2>/dev/null; then return 0; fi
    sleep 0.05
  done
  kill -KILL "$target_pid" 2>/dev/null || true
}

cleanup() {
  stop_validation_app
}
trap cleanup EXIT

find_validation_pid() {
  local pid command
  for pid in $(pgrep -x 'Anchor macOS' || true); do
    command=$(ps eww -p "$pid" -o command= 2>/dev/null || true)
    if [[ "$command" == *"ANCHOR_LOCAL_VALIDATION_ROOT=$validation_dir"* ]]; then
      print "$pid"
      return 0
    fi
  done
  return 1
}

wait_until() {
  local condition=$1
  local attempt
  for attempt in {1..160}; do
    if eval "$condition"; then return 0; fi
    sleep 0.05
  done
  print -u2 "Timed out: $condition"
  return 1
}

launch_app() {
  open -n \
    --stdout "$validation_dir/app.out" \
    --stderr "$validation_dir/app.err" \
    --env "ANCHOR_LOCAL_VALIDATION_ROOT=$validation_dir" \
    --env "ANCHOR_LOCAL_VALIDATION_CODEX_FILE=$codex_file" \
    "$app_path"
  wait_until 'app_pid=$(find_validation_pid)'
}

launch_app
wait_until '[[ -f "$validation_dir/task-runs.json" ]] && jq -e ".associations | length == 1" "$validation_dir/task-runs.json" >/dev/null 2>&1'
jq -e '.tasks | length == 1' "$validation_dir/task-runs.json" >/dev/null
jq -e '.workItems | length == 1' "$validation_dir/task-runs.json" >/dev/null
jq -e '.runs | length == 0' "$validation_dir/task-runs.json" >/dev/null
jq -e '.events | length == 0' "$validation_dir/task-runs.json" >/dev/null
print 'phase=bound-empty-source'

print '{"timestamp":"2099-09-09T01:02:03.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"mac-local-turn-1"}}' >> "$codex_file"
wait_until 'jq -e "(.runs | length) == 1 and .runs[0].execution == \"running\" and .runs[0].sourceSessionID == \"mac-local-turn-1\" and (.events | length) == 1 and .events[0].kind == \"started\"" "$validation_dir/task-runs.json" >/dev/null 2>&1'
print 'phase=running-captured'

print '{"timestamp":"2099-09-09T01:02:04.123Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"mac-local-turn-1"}}' >> "$codex_file"
wait_until 'jq -e "(.runs | length) == 1 and .runs[0].outcome == \"completed\" and (.events | length) == 2" "$validation_dir/task-runs.json" >/dev/null 2>&1'
print 'phase=completion-captured'

stop_validation_app
launch_app
wait_until '[[ -f "$validation_dir/codex-checkpoints.json" ]]'
sleep 0.5
jq -e '(.runs | length) == 1 and .runs[0].outcome == "completed" and (.events | length) == 2' "$validation_dir/task-runs.json" >/dev/null
jq -e 'keys | length == 1 and all(.[]; startswith("codex.lifecycle."))' "$validation_dir/codex-checkpoints.json" >/dev/null
if grep -Fq "$codex_file" "$validation_dir/codex-checkpoints.json"; then
  print -u2 'Checkpoint leaked the selected Codex file path.'
  exit 1
fi
print 'phase=restart-no-replay'

print '{"timestamp":"2099-09-09T01:02:05.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"mac-local-turn-2"}}' >> "$codex_file"
wait_until 'jq -e "(.runs | length) == 2 and (.events | length) == 3 and ([.runs[].sourceSessionID] | index(\"mac-local-turn-2\") != null)" "$validation_dir/task-runs.json" >/dev/null 2>&1'
print 'phase=post-restart-append-captured'

# Deliver completion before start, then redeliver completion. The terminal
# result must survive while immutable facts sort by source time and dedupe.
print '{"timestamp":"2099-09-09T01:02:08.123Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"mac-local-turn-3"}}' >> "$codex_file"
wait_until 'jq -e "(.runs | length) == 3 and any(.runs[]; .sourceSessionID == \"mac-local-turn-3\" and .outcome == \"completed\") and (.events | length) == 4" "$validation_dir/task-runs.json" >/dev/null 2>&1'
print '{"timestamp":"2099-09-09T01:02:07.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"mac-local-turn-3"}}' >> "$codex_file"
wait_until 'jq -e "any(.runs[]; .sourceSessionID == \"mac-local-turn-3\" and .outcome == \"completed\" and .startedAt == 3114291727.123) and (.events | length) == 5" "$validation_dir/task-runs.json" >/dev/null 2>&1'
print '{"timestamp":"2099-09-09T01:02:08.123Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"mac-local-turn-3"}}' >> "$codex_file"
sleep 0.5
jq -e '(.events | length) == 5 and ([.events[].id] | length) == ([.events[].id] | unique | length)' "$validation_dir/task-runs.json" >/dev/null
jq -e '[.events[] | select(.sourceSessionID == "mac-local-turn-3") | .kind] | sort == ["completed", "started"]' "$validation_dir/task-runs.json" >/dev/null
print 'phase=out-of-order-and-duplicate-preserved'

# Codex distinguishes an interrupted turn from a model failure. The legacy
# process projection stays failed-compatible while task history keeps the
# dedicated interrupted outcome and immutable event kind.
print '{"timestamp":"2099-09-09T01:02:09.123Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"mac-local-turn-4"}}' >> "$codex_file"
wait_until 'jq -e "(.runs | length) == 4 and any(.runs[]; .sourceSessionID == \"mac-local-turn-4\" and .outcome == \"interrupted\") and (.events | length) == 6 and any(.events[]; .sourceSessionID == \"mac-local-turn-4\" and .kind == \"interrupted\")" "$validation_dir/task-runs.json" >/dev/null 2>&1'
print 'phase=interruption-captured'

jq '{taskCount:(.tasks|length),workItemCount:(.workItems|length),runCount:(.runs|length),eventCount:(.events|length),associationCount:(.associations|length),runStates:[.runs[]|{sourceSessionID,execution,outcome}],eventKinds:[.events[].kind]}' "$validation_dir/task-runs.json"
jq '{checkpointCount:length}' "$validation_dir/codex-checkpoints.json"
print "validation_dir=$validation_dir"
