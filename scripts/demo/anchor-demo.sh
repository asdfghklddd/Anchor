#!/usr/bin/env bash
# Keeps the live demo's three project copies in ~/AnchorDemo.
#
#   anchor-demo.sh setup    Make the copies and mark where they start
#   anchor-demo.sh reset    Put every copy back where it started
#   anchor-demo.sh status   Show how far each copy has moved
#
# It only ever changes repositories that setup made: ones with no remote and
# the anchor-demo.branch setting. Agent conversations, Anchor's data and the
# original projects are never touched.
set -euo pipefail

DEMO_ROOT="$HOME/AnchorDemo"
TAG="anchor-demo-start"
BRANCH_KEY="anchor-demo.branch"

# The last Anchor before the real folder-picker, CPU and rotation fixes.
OLD_ANCHOR_COMMIT="4990ba5"
ANCHOR_SOURCE="${ANCHOR_DEMO_ANCHOR_SOURCE:-$HOME/Desktop/Anchor/Anchor}"
PHASE_SOURCE="${ANCHOR_DEMO_PHASE_SOURCE:-$HOME/Desktop/phase-ios-app}"
SITE_SOURCE="${ANCHOR_DEMO_SITE_SOURCE:-$HOME/Desktop/Qihua_Wang_Personal_Site}"

say() { printf '%s\n' "$*"; }
fail() { printf 'anchor-demo: %s\n' "$*" >&2; exit 1; }

demo_repos() {
  local dir
  for dir in "$DEMO_ROOT"/*/; do
    [[ -d "$dir/.git" ]] || continue
    git -C "$dir" config --get "$BRANCH_KEY" >/dev/null || continue
    printf '%s\n' "${dir%/}"
  done
  return 0
}

# Marks a finished copy as a demo repository and moves it into place.
finish_copy() { # finish_copy <building folder> <name>
  local repo="$1" name="$2"
  git -C "$repo" config user.name "Anchor Demo"
  git -C "$repo" config user.email "demo@anchor.invalid"
  git -C "$repo" config "$BRANCH_KEY" "$(git -C "$repo" symbolic-ref --short HEAD)"
  git -C "$repo" tag -f "$TAG" >/dev/null
  mv "$repo" "$DEMO_ROOT/$name"
  say "Made $name."
}

setup_old_anchor() {
  local repo="$DEMO_ROOT/.new-anchor-old"
  rm -rf "$repo"
  git clone -q --no-hardlinks --no-tags "$ANCHOR_SOURCE" "$repo"
  git -C "$repo" checkout -q -B demo "$OLD_ANCHOR_COMMIT"
  git -C "$repo" remote remove origin
  # No later branch: the agent must not find the real fixes in its history.
  git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads | while IFS= read -r branch; do
    [[ "$branch" == "demo" ]] || git -C "$repo" branch -q -D "$branch"
  done
  finish_copy "$repo" anchor-old
}

setup_phase() {
  local repo="$DEMO_ROOT/.new-phase-ios"
  rm -rf "$repo"
  git clone -q --no-hardlinks --no-tags "$PHASE_SOURCE" "$repo"
  git -C "$repo" remote remove origin
  finish_copy "$repo" phase-ios
}

setup_site() {
  local repo="$DEMO_ROOT/.new-personal-site"
  rm -rf "$repo"
  mkdir -p "$repo"
  # Leaves private materials and bulky build output behind. Dependencies come
  # along, ignored by git, so the build works offline.
  rsync -a --exclude /dist --exclude /output \
    --exclude /private_materials --exclude /verification_screenshots \
    --exclude /_template_unused --exclude /preview_screenshot.png --exclude '*.bak' \
    "$SITE_SOURCE/" "$repo/"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.name "Anchor Demo"
  git -C "$repo" config user.email "demo@anchor.invalid"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "Demo starting point"
  finish_copy "$repo" personal-site
}

setup() {
  mkdir -p "$DEMO_ROOT"
  [[ -e "$DEMO_ROOT/anchor-old" ]] && say "Skipped anchor-old: it already exists." || setup_old_anchor
  [[ -e "$DEMO_ROOT/phase-ios" ]] && say "Skipped phase-ios: it already exists." || setup_phase
  [[ -e "$DEMO_ROOT/personal-site" ]] && say "Skipped personal-site: it already exists." || setup_site
  say "Ready in $DEMO_ROOT."
}

reset_repo() { # reset_repo <repository>
  local repo="$1" branch path other
  branch="$(git -C "$repo" config --get "$BRANCH_KEY")"
  [[ -z "$(git -C "$repo" remote)" ]] || fail "$(basename "$repo") has a remote, so it was left alone."
  git -C "$repo" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
    || fail "$(basename "$repo") has lost its $TAG tag, so it was left alone."
  # Worktrees an agent made hold their branches until they are gone.
  git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p' | tail -n +2 | while IFS= read -r path; do
    git -C "$repo" worktree remove --force "$path"
  done
  git -C "$repo" worktree prune
  git -C "$repo" checkout -q -f "$branch"
  git -C "$repo" reset -q --hard "$TAG"
  # Ignored files stay, so dependencies and build caches need no rebuild.
  git -C "$repo" clean -q -ffd
  git -C "$repo" stash clear
  git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads | while IFS= read -r other; do
    [[ "$other" == "$branch" ]] || git -C "$repo" branch -q -D "$other"
  done
  say "Reset $(basename "$repo")."
}

reset() {
  local list repo
  list="$(demo_repos)"
  [[ -n "$list" ]] || fail "no demo copies in $DEMO_ROOT. Run: anchor-demo.sh setup"
  while IFS= read -r repo; do
    reset_repo "$repo"
  done <<< "$list"
  say "Every copy is back at its start. Conversations and Anchor were not touched."
}

status() {
  local list repo ahead changed
  list="$(demo_repos)"
  [[ -n "$list" ]] || { say "No demo copies yet."; return; }
  while IFS= read -r repo; do
    ahead="$(git -C "$repo" rev-list --count "$TAG..HEAD")"
    changed="$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')"
    say "$(basename "$repo"): $(git -C "$repo" branch --show-current), $ahead new commits, $changed changed files"
  done <<< "$list"
}

case "${1:-}" in
  setup) setup ;;
  reset) reset ;;
  status) status ;;
  *) sed -n '2,10p' "$0"; exit 2 ;;
esac
