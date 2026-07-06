#!/usr/bin/env bash
#
# Copies the pinned CEF runtime into a GoldSun.app bundle:
#   Contents/Frameworks/Chromium Embedded Framework.framework
#   Contents/Frameworks/GoldSun Helper[ (Alerts|GPU|Plugin|Renderer)].app
#
# Signs nested code inside-out (dylibs, framework, helpers); the caller signs
# the main app afterwards. Skips quietly when the CEF cache is absent so
# WebKit-only builds keep working.
#
# Usage: bundle_cef.sh <app-bundle> <helper-binary>
set -euo pipefail

APP_BUNDLE="${1:?usage: bundle_cef.sh <app-bundle> <helper-binary>}"
HELPER_BINARY="${2:?usage: bundle_cef.sh <app-bundle> <helper-binary>}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CEF_DIST="${GOLDSUN_CEF_DIR:-$ROOT_DIR/ThirdParty/CEFCache/current}"
CEF_FRAMEWORK="$CEF_DIST/Release/Chromium Embedded Framework.framework"
SIGNING_IDENTITY="${GOLDSUN_SIGNING_IDENTITY:--}"
HELPER_ENTITLEMENTS="$ROOT_DIR/Packaging/GoldSunHelper.entitlements"
MIN_SYSTEM_VERSION="14.0"
APP_NAME="GoldSun"
BUNDLE_ID="com.goldsun.browser"

if [[ ! -d "$CEF_FRAMEWORK" ]]; then
  echo "bundle_cef: CEF cache not found ($CEF_DIST); skipping Chromium runtime. Run script/fetch_cef.sh to enable it."
  exit 0
fi

if [[ ! -f "$HELPER_BINARY" ]]; then
  echo "bundle_cef: helper binary not found at $HELPER_BINARY" >&2
  exit 2
fi

FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

echo "bundle_cef: copying Chromium Embedded Framework"
rm -rf "$FRAMEWORKS_DIR/Chromium Embedded Framework.framework"
ditto --noextattr --norsrc "$CEF_FRAMEWORK" "$FRAMEWORKS_DIR/Chromium Embedded Framework.framework"
xattr -cr "$FRAMEWORKS_DIR/Chromium Embedded Framework.framework" 2>/dev/null || true

sign() {
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$@"
  else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$@"
  fi
}

for dylib in "$FRAMEWORKS_DIR/Chromium Embedded Framework.framework/Libraries"/*.dylib; do
  sign "$dylib"
done
sign "$FRAMEWORKS_DIR/Chromium Embedded Framework.framework"

# Helper suffix / bundle-id suffix pairs, matching CEF_HELPER_APP_SUFFIXES.
HELPER_VARIANTS=(
  ":"
  " (Alerts):.alerts"
  " (GPU):.gpu"
  " (Plugin):.plugin"
  " (Renderer):.renderer"
)

for variant in "${HELPER_VARIANTS[@]}"; do
  NAME_SUFFIX="${variant%%:*}"
  ID_SUFFIX="${variant#*:}"
  HELPER_NAME="$APP_NAME Helper$NAME_SUFFIX"
  HELPER_APP="$FRAMEWORKS_DIR/$HELPER_NAME.app"

  echo "bundle_cef: creating $HELPER_NAME.app"
  rm -rf "$HELPER_APP"
  mkdir -p "$HELPER_APP/Contents/MacOS"
  cp -X "$HELPER_BINARY" "$HELPER_APP/Contents/MacOS/$HELPER_NAME"
  chmod +x "$HELPER_APP/Contents/MacOS/$HELPER_NAME"

  cat >"$HELPER_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$HELPER_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$HELPER_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID.helper$ID_SUFFIX</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$HELPER_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSEnvironment</key>
  <dict>
    <key>MallocNanoZone</key>
    <string>0</string>
  </dict>
  <key>LSFileQuarantineEnabled</key>
  <false/>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$HELPER_APP"
  else
    codesign --force --options runtime --timestamp \
      --entitlements "$HELPER_ENTITLEMENTS" \
      --sign "$SIGNING_IDENTITY" "$HELPER_APP"
  fi
done

echo "bundle_cef: Chromium runtime bundled"
