#!/usr/bin/env bash
# Films the iPhone first-run tour from start to finish on a simulator.
#
#   scripts/record-onboarding.sh [--lang zh|en] [--device NAME|UDID] [--out DIR]
#
# Each run builds the current code, installs Anchor fresh on the simulator
# (its Anchor data there is erased, so the tour and the notification question
# come up as on a new phone), walks the whole tour with
# OnboardingRecordingUITests and saves the film as
# <out>/onboarding-<lang>-<date>.mp4. Defaults: Chinese, "iPhone 17 Pro",
# and a Recordings folder beside the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LANGUAGE=zh
DEVICE="iPhone 17 Pro"
OUT="$(cd "$ROOT/.." && pwd)/Recordings"
DERIVED="$(cd "$ROOT/.." && pwd)/Build/DerivedData/record"
BUNDLE=com.andywang.anchor

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang) LANGUAGE="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$LANGUAGE" == zh || "$LANGUAGE" == en ]] || { echo "--lang is zh or en" >&2; exit 2; }

# A name picks that simulator, a booted one first.
if [[ "$DEVICE" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  UDID="$DEVICE"
else
  UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = [d for runtime in json.load(sys.stdin)["devices"].values() for d in runtime if d["name"] == name]
devices.sort(key=lambda d: d["state"] != "Booted")
print(devices[0]["udid"] if devices else "")
' "$DEVICE")"
fi
[[ -n "$UDID" ]] || { echo "No available simulator named \"$DEVICE\"." >&2; exit 1; }

mkdir -p "$OUT" "$DERIVED"
STAMP="$(date +%Y%m%d-%H%M%S)"
FILM="$OUT/onboarding-$LANGUAGE-$STAMP.mp4"
LOG="$DERIVED/onboarding-$LANGUAGE-$STAMP.log"

echo "▸ Simulator $UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null

echo "▸ Building (log: $LOG)"
xcodebuild build-for-testing -project "$ROOT/Anchor.xcodeproj" -scheme "Anchor iOS" -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO >"$LOG" 2>&1 || { tail -30 "$LOG"; exit 1; }

# A first launch, in light mode, under a tidy status bar.
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4

RECORDER=""
finish() {
  if [[ -n "$RECORDER" ]] && kill -0 "$RECORDER" 2>/dev/null; then
    kill -INT "$RECORDER"
    wait "$RECORDER" 2>/dev/null || true
  fi
  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
}
trap finish EXIT

echo "▸ Recording"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$FILM" >/dev/null 2>&1 &
RECORDER=$!
sleep 2

echo "▸ Walking the tour ($LANGUAGE)"
if ! TEST_RUNNER_ANCHOR_RECORD_LANG="$LANGUAGE" xcodebuild test-without-building \
  -project "$ROOT/Anchor.xcodeproj" -scheme "Anchor iOS" -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:AnchorIOSUITests/OnboardingRecordingUITests/testWalkTheTourForTheCamera \
  >>"$LOG" 2>&1; then
  echo "The walk stopped part way; the film so far is kept. See $LOG" >&2
  finish
  echo "▸ $FILM"
  exit 1
fi

finish
echo "▸ Saved $FILM"
