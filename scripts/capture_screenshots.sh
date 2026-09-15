#!/usr/bin/env bash
# Capture only an explicitly selected simulator; never fabricate device renders.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIMULATOR_UDID:?Set the UDID of the simulator matching the intended screenshot slot}"
GROUP="${SCREENSHOT_GROUP:-iphone-6.9}"
case "$GROUP" in iphone-6.9|ipad-13|duo-inner|duo-outer) ;; *) echo 'Unknown screenshot group' >&2; exit 2;; esac
OUT=".release/captures/$GROUP"
if [[ -e "$OUT" ]]; then echo "Capture directory exists: $OUT. Preserve/review it before another run." >&2; exit 2; fi
mkdir -p "$OUT"
python3 scripts/generate_project.py
# Device Hub pose/inner-versus-outer selection must be set by the operator for Duo.
xcodebuild -project FoldCounter.xcodeproj -scheme "${CAPTURE_SCHEME:-FoldCounter}" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -resultBundlePath "$OUT/Captures.xcresult" \
  -only-testing:FoldCounterUITests/FoldCounterScreenshotTests \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$OUT/capture.log"
xcrun xcresulttool export attachments --path "$OUT/Captures.xcresult" --output-path "$OUT/attachments"
echo "Actual UI captures: $OUT/attachments. Review before copying selected PNGs to .release/screenshots/$GROUP/."
echo 'Manual test data is labeled. Widget screenshots and real Duo behavior need separate device validation.'
