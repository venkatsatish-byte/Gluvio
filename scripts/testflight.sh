#!/usr/bin/env bash
# Archives Gluvio (iPhone app with the embedded Apple Watch app), signs it with
# an App Store Connect API key, and uploads it to TestFlight.
#
# Needs these environment variables (see docs/TESTFLIGHT.md):
#   TEAM_ID          Apple Developer team ID, e.g. A1B2C3D4E5
#   BUNDLE_ID        the app's bundle ID, e.g. com.yourname.gluvio
#   ASC_KEY_ID       App Store Connect API key ID
#   ASC_ISSUER_ID    App Store Connect API issuer ID
#   ASC_PRIVATE_KEY  contents of the AuthKey_XXXX.p8 file
#
# Without them, it still builds the app for real devices (unsigned) so the
# build is checked, then stops and lists what's missing.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_NUMBER=${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}
mkdir -p build
xcodegen generate

errors() {
  echo "::group::Build errors"
  grep -E "error:" "$1" | sort -u | head -60 || true
  grep -A5 "The following build commands failed" "$1" || true
  tail -20 "$1"
  echo "::endgroup::"
}

missing=()
[ -n "${TEAM_ID:-}" ] || missing+=("APPLE_TEAM_ID (repository variable)")
[ -n "${BUNDLE_ID:-}" ] || missing+=("APP_BUNDLE_ID (repository variable)")
[ -n "${ASC_KEY_ID:-}" ] || missing+=("ASC_KEY_ID (secret)")
[ -n "${ASC_ISSUER_ID:-}" ] || missing+=("ASC_ISSUER_ID (secret)")
[ -n "${ASC_PRIVATE_KEY:-}" ] || missing+=("ASC_PRIVATE_KEY (secret)")

if [ ${#missing[@]} -gt 0 ]; then
  echo "Apple credentials aren't set up yet, so this run only checks the device build (unsigned)."
  if ! xcodebuild archive -project Gluvio.xcodeproj -scheme Gluvio -configuration Release \
       -destination "generic/platform=iOS" -archivePath build/Gluvio-unsigned.xcarchive \
       CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION="$BUILD_NUMBER" > build/archive.log 2>&1; then
    errors build/archive.log
    exit 1
  fi
  APP=build/Gluvio-unsigned.xcarchive/Products/Applications/Gluvio.app
  echo "Device build succeeded."
  echo "  Apple Watch app: $(ls "$APP/Watch" 2>/dev/null || echo missing)"
  echo "  Widgets:         $(ls "$APP/PlugIns" 2>/dev/null || echo missing)"
  echo "  App icon:        $(ls "$APP" | grep -c AppIcon || true) icon files"
  for item in "${missing[@]}"; do echo "::error::Missing $item. See docs/TESTFLIGHT.md."; done
  exit 1
fi

KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${ASC_KEY_ID}.p8"
printf '%s\n' "$ASC_PRIVATE_KEY" > "$KEY_PATH"
chmod 600 "$KEY_PATH"
trap 'rm -f "$KEY_PATH"' EXIT

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")
SETTINGS=(DEVELOPMENT_TEAM="$TEAM_ID"
          APP_BUNDLE_ID="$BUNDLE_ID"
          APP_GROUP_ID="group.$BUNDLE_ID"
          CODE_SIGN_STYLE=Automatic
          CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

echo "Archiving build $BUILD_NUMBER of $BUNDLE_ID"
if ! xcodebuild archive -project Gluvio.xcodeproj -scheme Gluvio -configuration Release \
     -destination "generic/platform=iOS" -archivePath build/Gluvio.xcarchive \
     "${AUTH[@]}" "${SETTINGS[@]}" > build/archive.log 2>&1; then
  errors build/archive.log
  exit 1
fi

cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "Signing and uploading to App Store Connect"
if ! xcodebuild -exportArchive -archivePath build/Gluvio.xcarchive \
     -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
     "${AUTH[@]}" > build/export.log 2>&1; then
  errors build/export.log
  exit 1
fi
grep -iE "upload|success" build/export.log | tail -5 || true
echo "Uploaded build $BUILD_NUMBER. It appears in TestFlight after Apple finishes processing (usually 5–30 minutes)."
