#!/usr/bin/env bash
# Puts the live demo back where it starts, in the demo macOS account only.
#
#   anchor-demo.sh save      Take the starting point (asks before replacing one)
#   anchor-demo.sh restore   Go back to it; on the iPhone, tap 从 Mac 重新同步 first
#   anchor-demo.sh status    Show what the starting point holds
#   anchor-demo.sh remove    Delete the starting point and the repos' demo tags
#
# The starting point holds every git repository in ~/AnchorDemo (its branch
# and commit, as the tag anchor-demo-start), the agents' conversations
# (~/.codex without sign-in files; Claude Code's sessions, also the Claude
# app's Code list) and Anchor's Mac data and settings. Codex, Claude and
# Anchor quit while it is copied and open again after.
#
# Runs only as the account named by ANCHOR_DEMO_USER (default: anchordemo).
set -euo pipefail

DEMO_USER="${ANCHOR_DEMO_USER:-anchordemo}"
DEMO_ROOT="$HOME/AnchorDemo"
SNAPSHOT="$DEMO_ROOT/.snapshot"
TAG="anchor-demo-start"
PREFS_DOMAIN="${ANCHOR_DEMO_PREFS:-com.andywang.anchor}"
# Apps to quit and reopen, by bundle ID. Empty skips quitting entirely.
APPS="${ANCHOR_DEMO_APPS-com.andywang.anchor com.openai.codex com.anthropic.claudefordesktop}"

# Conversation data, relative to home. Paths missing from the starting point
# are removed on restore, except ~/.codex, which also holds sign-in.
MANAGED=(
  ".codex"
  ".claude/projects"
  ".claude/file-history"
  ".claude/todos"
  ".claude/session-env"
  ".claude/sessions"
  ".claude/shell-snapshots"
  ".claude/plans"
  ".claude/history.jsonl"
  "Library/Application Support/Claude/claude-code-sessions"
  "Library/Application Support/Anchor"
)
# Never copied, never deleted: sign-in, locks and scratch.
EXCLUDES=(--exclude "auth*.json" --exclude "*.lock" --exclude "tmp/" --exclude "cache/" --exclude "*.bak")

say() { printf '%s\n' "$*"; }
fail() { printf 'anchor-demo: %s\n' "$*" >&2; exit 1; }

if [[ "$(id -un)" != "$DEMO_USER" ]]; then
  fail "this is the '$(id -un)' account. Run it in the demo account '$DEMO_USER' only."
fi

repos() {
  local dir
  for dir in "$DEMO_ROOT"/*/; do
    [[ -d "$dir/.git" ]] && printf '%s\n' "${dir%/}"
  done
  return 0
}

RUNNING=()

quit_apps() {
  [[ -z "$APPS" ]] && return 0
  local id
  for id in $APPS; do
    if [[ "$(osascript -e "application id \"$id\" is running" 2>/dev/null)" == "true" ]]; then
      RUNNING+=("$id")
      osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1 || true
    fi
  done
  for _ in $(seq 1 30); do
    local busy=0
    for id in $APPS; do
      [[ "$(osascript -e "application id \"$id\" is running" 2>/dev/null)" == "true" ]] && busy=1
    done
    [[ $busy == 0 ]] && break
    sleep 0.5
  done
  # Agents running in Terminal write to the same folders.
  pkill -x claude 2>/dev/null || true
  pkill -x codex 2>/dev/null || true
  sleep 1
}

reopen_apps() {
  [[ -z "$APPS" ]] && return 0
  local id
  # Anchor last, so it reads the agents' folders once they are back.
  for id in "${RUNNING[@]:-}"; do
    [[ -n "$id" && "$id" != "com.andywang.anchor" ]] && open -g -b "$id" || true
  done
  open -b com.andywang.anchor 2>/dev/null || say "Open Anchor yourself; macOS could not find it."
}

copy_in() { # copy_in <from> <to>
  if [[ -d "$1" ]]; then
    mkdir -p "$2"
    rsync -a --delete --ignore-times "${EXCLUDES[@]}" "$1/" "$2/"
  else
    mkdir -p "$(dirname "$2")"
    cp -p "$1" "$2"
  fi
}

save() {
  [[ -d "$DEMO_ROOT" ]] || fail "make $DEMO_ROOT and put the demo's git repositories in it first."
  local repo
  local list
  list="$(repos)"
  [[ -n "$list" ]] || fail "no git repositories in $DEMO_ROOT."
  while IFS= read -r repo; do
    [[ -z "$(git -C "$repo" status --porcelain)" ]] \
      || fail "$(basename "$repo") has uncommitted changes. Commit or discard them, then save."
    git -C "$repo" symbolic-ref -q --short HEAD >/dev/null \
      || fail "$(basename "$repo") is not on a branch."
  done <<< "$list"
  if [[ -e "$SNAPSHOT" && "${1:-}" != "-y" ]]; then
    read -r -p "Replace the saved starting point? [y/N] " answer
    [[ "$answer" == [yY] ]] || exit 0
  fi

  quit_apps
  rm -rf "$SNAPSHOT.new"
  mkdir -p "$SNAPSHOT.new/home"
  while IFS= read -r repo; do
    git -C "$repo" tag -f "$TAG" >/dev/null
    printf '%s\t%s\t%s\n' "$(basename "$repo")" "$(git -C "$repo" symbolic-ref --short HEAD)" \
      "$(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads | tr '\n' ' ')" \
      >> "$SNAPSHOT.new/repos.tsv"
  done <<< "$list"
  local path
  for path in "${MANAGED[@]}"; do
    [[ -e "$HOME/$path" ]] && copy_in "$HOME/$path" "$SNAPSHOT.new/home/$path"
  done
  defaults export "$PREFS_DOMAIN" "$SNAPSHOT.new/anchor-prefs.plist" 2>/dev/null || true
  date '+%Y-%m-%d %H:%M' > "$SNAPSHOT.new/saved-at"
  rm -rf "$SNAPSHOT"
  mv "$SNAPSHOT.new" "$SNAPSHOT"
  reopen_apps
  say "Saved the starting point ($(wc -l < "$SNAPSHOT/repos.tsv" | tr -d ' ') repositories)."
}

restore() {
  [[ -f "$SNAPSHOT/saved-at" ]] || fail "nothing saved yet. Run: anchor-demo.sh save"
  quit_apps

  local name branch branches repo
  while IFS=$'\t' read -r name branch branches; do
    repo="$DEMO_ROOT/$name"
    [[ -d "$repo/.git" ]] || { say "Skipped $name: it is gone."; continue; }
    git -C "$repo" checkout -q -f "$branch"
    git -C "$repo" reset -q --hard "$TAG"
    git -C "$repo" clean -q -fd
    # Branches an agent made on stage go; the saved ones stay.
    local current
    for current in $(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads); do
      [[ " $branches " == *" $current "* ]] || git -C "$repo" branch -q -D "$current"
    done
    git -C "$repo" worktree prune
  done < "$SNAPSHOT/repos.tsv"

  local path
  for path in "${MANAGED[@]}"; do
    if [[ -e "$SNAPSHOT/home/$path" ]]; then
      copy_in "$SNAPSHOT/home/$path" "$HOME/$path"
    elif [[ "$path" != ".codex" && -e "$HOME/$path" ]]; then
      rm -rf "${HOME:?}/$path"
    fi
  done
  if [[ -f "$SNAPSHOT/anchor-prefs.plist" ]]; then
    defaults delete "$PREFS_DOMAIN" >/dev/null 2>&1 || true
    defaults import "$PREFS_DOMAIN" "$SNAPSHOT/anchor-prefs.plist"
  fi
  reopen_apps
  say "Back to the starting point saved $(cat "$SNAPSHOT/saved-at")."
}

status() {
  [[ -f "$SNAPSHOT/saved-at" ]] || { say "Nothing saved yet."; return; }
  say "Saved $(cat "$SNAPSHOT/saved-at"), $(du -sh "$SNAPSHOT" | cut -f1):"
  local name branch _
  while IFS=$'\t' read -r name branch _; do
    say "  $name  ($branch)"
  done < "$SNAPSHOT/repos.tsv"
}

remove() {
  read -r -p "Delete the saved starting point and the repos' $TAG tags? [y/N] " answer
  [[ "$answer" == [yY] ]] || exit 0
  local repo
  while IFS= read -r repo; do
    [[ -n "$repo" ]] && git -C "$repo" tag -d "$TAG" >/dev/null 2>&1 || true
  done <<< "$(repos)"
  rm -rf "$SNAPSHOT" "$SNAPSHOT.new"
  say "Removed. To remove everything else, delete the '$DEMO_USER' account in System Settings › Users & Groups."
}

case "${1:-}" in
  save) save "${2:-}" ;;
  restore) restore ;;
  status) status ;;
  remove) remove ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
