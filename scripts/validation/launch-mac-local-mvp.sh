#!/bin/zsh
set -euo pipefail

if [[ $# -gt 1 ]]; then
  print -u2 "usage: $0 [absolute-validation-root]"
  exit 64
fi

repo_root=${0:A:h:h:h}
derived_data=/private/tmp/anchor-mac-mvp-user-test-derived
if [[ $# -eq 1 ]]; then
  validation_dir=$1
  if [[ "$validation_dir" != /* || "$validation_dir" == "/" || "$validation_dir" == "/tmp" || "$validation_dir" == "/private/tmp" ]]; then
    print -u2 "validation root must be a specific absolute directory"
    exit 64
  fi
  mkdir -p "$validation_dir"
else
  validation_dir=$(mktemp -d /tmp/anchor-mac-mvp-user-test.XXXXXX)
fi

if pgrep -x 'Anchor macOS' >/dev/null; then
  print -u2 "Anchor macOS is already running. Quit it, then run this launcher again."
  exit 75
fi

build_log="$validation_dir/build.log"
xcodebuild \
  -project "$repo_root/Anchor.xcodeproj" \
  -scheme 'Anchor macOS' \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build > "$build_log" 2>&1 || {
    tail -80 "$build_log" >&2
    exit 1
  }

app_path="$derived_data/Build/Products/Debug/Anchor macOS.app"
defaults_suffix=$(basename "$validation_dir" | tr -cd '[:alnum:]._-')
open -n \
  --stdout "$validation_dir/app.out" \
  --stderr "$validation_dir/app.err" \
  --env "ANCHOR_LOCAL_VALIDATION_ROOT=$validation_dir" \
  --env "ANCHOR_LOCAL_VALIDATION_SEED_SESSION=1" \
  --env "ANCHOR_LOCAL_VALIDATION_DEFAULTS_SUITE=anchor.mac.mvp.$defaults_suffix" \
  "$app_path"

for attempt in {1..200}; do
  if [[ -f "$validation_dir/launch-marker.txt" && -f "$validation_dir/session-repository.json" ]]; then
    print "Anchor macOS MVP test app is ready."
    print "Validation data: $validation_dir"
    print "Next: open Sources, choose the proposed Codex JSONL, verify it, then click Open."
    print "Quit the app with Command-Q when finished. Reuse this test state by passing the validation path to this script."
    exit 0
  fi
  sleep 0.05
done

print -u2 "Anchor launched but the isolated validation state was not ready in time."
print -u2 "Inspect: $validation_dir/app.err"
exit 1
