#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  print -u2 "usage: $0 '/absolute/path/to/Anchor macOS.app' [turn-count] [interval-seconds]"
  exit 64
fi

app_path=$1
turn_count=${2:-60}
interval_seconds=${3:-1}
if [[ ! -d "$app_path" ]]; then
  print -u2 "Anchor app not found: $app_path"
  exit 66
fi
if (( turn_count < 4 )); then
  print -u2 'turn-count must be at least 4'
  exit 64
fi

validation_dir=$(mktemp -d /tmp/anchor-mac-soak-e2e.XXXXXX)
codex_file="$validation_dir/session.jsonl"
touch "$codex_file"
app_pid=''
max_rss_kb=0

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
  for attempt in {1..240}; do
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
  wait_until '[[ -f "$validation_dir/task-runs.json" ]] && jq -e ".associations | length == 1" "$validation_dir/task-runs.json" >/dev/null 2>&1'
}

restart_app() {
  local expected_count=$1
  stop_validation_app
  launch_app
  sleep 0.3
  jq -e "(.runs | length) == $expected_count and (.events | length) == ($expected_count * 2)" "$validation_dir/task-runs.json" >/dev/null
}

timestamp_for() {
  local total_seconds=$1
  local hour=$(( total_seconds / 3600 ))
  local minute=$(( (total_seconds / 60) % 60 ))
  local second=$(( total_seconds % 60 ))
  printf '2099-09-09T%02d:%02d:%02d.123Z' "$hour" "$minute" "$second"
}

write_turn() {
  local turn=$1
  local mode=$2
  local turn_id="soak-turn-$turn"
  local started_at=$(timestamp_for $(( turn * 2 )))
  local completed_at=$(timestamp_for $(( turn * 2 + 1 )))
  local start_line="{\"timestamp\":\"$started_at\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\",\"turn_id\":\"$turn_id\"}}"
  local complete_line="{\"timestamp\":\"$completed_at\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"$turn_id\"}}"

  case "$mode" in
    append)
      print "$start_line" >> "$codex_file"
      print "$complete_line" >> "$codex_file"
      ;;
    replace)
      local replacement="$validation_dir/replacement.jsonl"
      print "$start_line" > "$replacement"
      print "$complete_line" >> "$replacement"
      mv "$replacement" "$codex_file"
      ;;
    truncate)
      truncate -s 0 "$codex_file"
      sleep 0.3
      print "$start_line" >> "$codex_file"
      print "$complete_line" >> "$codex_file"
      ;;
  esac

  wait_until "jq -e 'any(.runs[]; .sourceSessionID == \"$turn_id\" and .outcome == \"completed\")' '$validation_dir/task-runs.json' >/dev/null 2>&1"
}

sample_memory() {
  local rss_kb=$(ps -p "$app_pid" -o rss= | tr -d ' ')
  if [[ -n "$rss_kb" ]] && (( rss_kb > max_rss_kb )); then
    max_rss_kb=$rss_kb
  fi
}

launch_app
replacement_turn=$(( turn_count / 2 ))
truncation_turn=$(( (turn_count * 3) / 4 ))
first_restart=$(( turn_count / 3 ))
second_restart=$(( (turn_count * 2) / 3 ))

for turn in $(seq 1 "$turn_count"); do
  mode=append
  if (( turn == replacement_turn )); then mode=replace; fi
  if (( turn == truncation_turn )); then mode=truncate; fi
  write_turn "$turn" "$mode"
  sample_memory
  if (( turn == first_restart || turn == second_restart )); then
    restart_app "$turn"
  fi
  sleep "$interval_seconds"
done

restart_app "$turn_count"
jq -e ".tasks | length == 1" "$validation_dir/task-runs.json" >/dev/null
jq -e ".workItems | length == 1" "$validation_dir/task-runs.json" >/dev/null
jq -e ".associations | length == 1" "$validation_dir/task-runs.json" >/dev/null
jq -e ".runs | length == $turn_count and all(.[]; .outcome == \"completed\")" "$validation_dir/task-runs.json" >/dev/null
jq -e ".events | length == ($turn_count * 2)" "$validation_dir/task-runs.json" >/dev/null
jq -e '[.runs[].id] | length == (unique | length)' "$validation_dir/task-runs.json" >/dev/null
jq -e '[.runs[].sourceSessionID] | length == (unique | length)' "$validation_dir/task-runs.json" >/dev/null
jq -e '[.events[].id] | length == (unique | length)' "$validation_dir/task-runs.json" >/dev/null
jq -e 'keys | length == 1 and all(.[]; startswith("codex.lifecycle."))' "$validation_dir/codex-checkpoints.json" >/dev/null
if grep -Fq "$codex_file" "$validation_dir/codex-checkpoints.json"; then
  print -u2 'Checkpoint leaked the selected Codex file path.'
  exit 1
fi

jq --argjson maxRSSKilobytes "$max_rss_kb" \
  '{taskCount:(.tasks|length),workItemCount:(.workItems|length),runCount:(.runs|length),eventCount:(.events|length),associationCount:(.associations|length),completedRuns:([.runs[]|select(.outcome == "completed")]|length),maxRSSKilobytes:$maxRSSKilobytes}' \
  "$validation_dir/task-runs.json"
jq '{checkpointCount:length,checkpointKeys:keys}' "$validation_dir/codex-checkpoints.json"
print "replacement_turn=$replacement_turn"
print "truncation_turn=$truncation_turn"
print "restart_turns=$first_restart,$second_restart,final"
print "validation_dir=$validation_dir"
