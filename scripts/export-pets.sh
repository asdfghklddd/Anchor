#!/usr/bin/env bash
# Exports every desk pet's every act for print and merchandise, as one zip.
#
#   scripts/export-pets.sh [--device NAME|UDID] [--out DIR]
#
# Draws each act with the app's own pet renderer (DeskPetExport in the
# package tests) on a simulator: per pet, transparent PNG frames, a looping
# GIF and an SVG key frame per act, a portrait, an overview sheet and the
# palette. Saves <out>/AnchorPets-<date>.zip. Defaults: "iPhone 17 Pro"
# and a Deliverables folder beside the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="iPhone 17 Pro"
OUT="$(cd "$ROOT/.." && pwd)/Deliverables"
DERIVED="$(cd "$ROOT/.." && pwd)/Build/DerivedData/pets"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ "$DEVICE" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  DESTINATION="platform=iOS Simulator,id=$DEVICE"
else
  DESTINATION="platform=iOS Simulator,name=$DEVICE"
fi

mkdir -p "$OUT" "$DERIVED"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOG="$DERIVED/pets-$STAMP.log"

echo "▸ Drawing (log: $LOG)"
(cd "$ROOT/Packages/AnchorKit" && TEST_RUNNER_ANCHOR_PET_EXPORT="$WORK/AnchorPets" xcodebuild test \
  -scheme IOSFeatureTests -destination "$DESTINATION" -derivedDataPath "$DERIVED" \
  -only-testing:AnchorIOSFeaturesTests/DeskPetExport) >"$LOG" 2>&1 || { tail -30 "$LOG"; exit 1; }
[[ -f "$WORK/AnchorPets/README.txt" ]] || { echo "Nothing was drawn; see $LOG" >&2; exit 1; }

ZIP="$OUT/AnchorPets-$STAMP.zip"
(cd "$WORK" && ditto -c -k --sequesterRsrc --keepParent AnchorPets "$ZIP")
echo "▸ $ZIP"
