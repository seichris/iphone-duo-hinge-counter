#!/usr/bin/env bash
# Local, signed archive only. This script never uploads or submits an app.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPMENT_TEAM:?Set your Apple Developer Team ID locally; never commit signing credentials}"
python3 scripts/release_preflight.py --archive --evidence "${RELEASE_EVIDENCE:-.release/evidence.json}"
SDK=$(xcrun --sdk iphoneos --show-sdk-version)
python3 - "$SDK" <<'PY'
import sys
sys.path.insert(0, 'scripts')
from select_xcode import version_tuple
if version_tuple(sys.argv[1]) < (27, 1, 0):
    raise SystemExit('The Duo distribution archive requires the validated iOS 27.1+ SDK.')
PY
python3 scripts/build_site.py --check
python3 scripts/generate_project.py
ARCHIVE="${ARCHIVE_PATH:-.release/FoldCounter.xcarchive}"
if [[ -e "$ARCHIVE" ]]; then
  echo "Archive already exists: $ARCHIVE. Choose a new ARCHIVE_PATH; existing evidence will not be overwritten." >&2
  exit 2
fi
mkdir -p .release
xcodebuild -project FoldCounter.xcodeproj -scheme 'FoldCounter Duo' \
  -configuration 'Duo Release' -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" archive \
  2>&1 | tee .release/archive.log
codesign --verify --deep --strict "$ARCHIVE/Products/Applications/FoldCounter.app"
echo "Signed archive created: $ARCHIVE"
echo "Open it in Xcode Organizer. Validate, inspect the archive privacy report, then distribute to TestFlight. No upload or submission was performed."
