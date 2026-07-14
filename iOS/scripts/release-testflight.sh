#!/usr/bin/env bash
#
# release-testflight.sh — one-command FastWeather iOS TestFlight release.
#
# Archives the app, exports a signed App Store IPA, uploads it to App Store
# Connect, waits for processing, then sets the What-to-Test notes, assigns the
# beta groups, and submits external Beta App Review.
#
# Credentials + the ASC API client live in ~/.fastweather-keys/
# (asc.json + asc.py). See scripts/RELEASE.md for the full workflow.
#
# Usage:
#   scripts/release-testflight.sh --notes RELEASE_NOTES.txt
#   scripts/release-testflight.sh --notes notes.txt --groups "Internal test,External"
#   scripts/release-testflight.sh --notes notes.txt --no-external-review
#   scripts/release-testflight.sh --wire-only --version 1.5.9 --build 4 --notes notes.txt
#       (skip build/upload; just wire an already-uploaded build — e.g. one you
#        uploaded from Xcode)
#
set -euo pipefail

# --- locate repo/iOS dir (script lives in iOS/scripts) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$HOME/.fastweather-keys"
ASC="$KEYS_DIR/asc.py"
ASC_JSON="$KEYS_DIR/asc.json"

PROJECT="$IOS_DIR/FastWeather.xcodeproj"
SCHEME="FastWeather"
CONFIG="Release"
BUILD_DIR="$IOS_DIR/build/release"
EXPORT_PLIST="$SCRIPT_DIR/ExportOptions.plist"

# --- defaults ---
NOTES=""
# NB: not "GROUPS" — that is a reserved bash array (current user's group IDs).
BETA_GROUPS="Internal test,External"
SUBMIT_EXTERNAL=1
WIRE_ONLY=0
UPLOAD_ONLY=0
VERSION=""
BUILD=""

die() { echo "❌ $*" >&2; exit 1; }
step() { echo ""; echo "▶ $*"; }

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2;;
    --groups) BETA_GROUPS="$2"; shift 2;;
    --no-external-review) SUBMIT_EXTERNAL=0; shift;;
    --wire-only) WIRE_ONLY=1; shift;;
    --upload-only) UPLOAD_ONLY=1; shift;;
    --version) VERSION="$2"; shift 2;;
    --build) BUILD="$2"; shift 2;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

[[ -f "$ASC" && -f "$ASC_JSON" ]] || die "missing $ASC / $ASC_JSON (ASC credentials not set up)"
# Notes are the TestFlight What-to-Test text; not needed for --upload-only.
if [[ "$UPLOAD_ONLY" -eq 0 ]]; then
  [[ -n "$NOTES" ]] || die "--notes <file> is required (the What-to-Test text)"
  NOTES="$(cd "$(dirname "$NOTES")" && pwd)/$(basename "$NOTES")"   # absolutize
  [[ -f "$NOTES" ]] || die "notes file not found: $NOTES"
  [[ -s "$NOTES" ]] || die "notes file is empty: $NOTES"
fi

# Read key id + issuer from the config (no secrets duplicated in this script).
read_cfg() { python3 -c "import json,sys;print(json.load(open('$ASC_JSON'))['$1'])"; }
KEY_ID="$(read_cfg key_id)"
ISSUER="$(read_cfg issuer_id)"

wire_testflight() {
  local ver="$1" bld="$2"
  local args=(testflight --version "$ver" --build "$bld" --notes-file "$NOTES" --groups "$BETA_GROUPS")
  [[ "$SUBMIT_EXTERNAL" -eq 0 ]] && args+=(--no-submit-external)
  step "Wiring TestFlight (notes + groups + review) for $ver ($bld)"
  python3 "$ASC" "${args[@]}"
}

# --- wire-only fast path (build already uploaded, e.g. from Xcode) ---
if [[ "$WIRE_ONLY" -eq 1 ]]; then
  [[ -n "$VERSION" && -n "$BUILD" ]] || die "--wire-only requires --version and --build"
  wire_testflight "$VERSION" "$BUILD"
  echo ""; echo "✅ Done (wire-only)."
  exit 0
fi

# --- read version/build from the project ---
step "Reading version from project"
SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" -showBuildSettings 2>/dev/null)"
VERSION="$(echo "$SETTINGS" | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')"
BUILD="$(echo "$SETTINGS"   | awk -F' = ' '/ CURRENT_PROJECT_VERSION /{print $2; exit}')"
[[ -n "$VERSION" && -n "$BUILD" ]] || die "could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION"
echo "  Version $VERSION (build $BUILD)"

ARCHIVE="$BUILD_DIR/FastWeather-$VERSION-$BUILD.xcarchive"
EXPORT_DIR="$BUILD_DIR/export-$VERSION-$BUILD"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

# --- archive ---
step "Archiving ($CONFIG, generic iOS device)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates clean archive

# --- export signed IPA ---
step "Exporting App Store IPA"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

IPA="$(/usr/bin/find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -1)"
[[ -n "$IPA" ]] || die "no .ipa produced in $EXPORT_DIR"
echo "  IPA: $IPA"

# --- validate then upload via altool (uses the same .p8 in ~/.appstoreconnect/private_keys) ---
step "Validating with App Store Connect"
xcrun altool --validate-app --type ios --file "$IPA" \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER"

step "Uploading to App Store Connect"
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER"
echo "  Upload accepted; App Store Connect is now processing the build."

# --- upload-only stops here (e.g. App Store submission handled separately) ---
if [[ "$UPLOAD_ONLY" -eq 1 ]]; then
  echo ""
  echo "✅ Built + uploaded $VERSION ($BUILD). Skipped TestFlight wiring (--upload-only)."
  exit 0
fi

# --- wire TestFlight (polls until the build is VALID) ---
wire_testflight "$VERSION" "$BUILD"

echo ""
echo "✅ Release complete: $VERSION ($BUILD)"
echo "   Internal testers can install now; external testers after Beta App Review clears."
