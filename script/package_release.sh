#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.2.20}"
APP_NAME="GoldSun"
BUNDLE_ID="com.goldsun.browser"
MIN_SYSTEM_VERSION="14.0"
SIGNING_IDENTITY="${GOLDSUN_SIGNING_IDENTITY:--}"
INSTALLER_SIGNING_IDENTITY="${GOLDSUN_INSTALLER_SIGNING_IDENTITY:-}"
ENABLE_PASSKEY_ENTITLEMENT="${GOLDSUN_ENABLE_PASSKEY_ENTITLEMENT:-0}"
NOTARIZE="${GOLDSUN_NOTARIZE:-0}"
NOTARY_PROFILE="${GOLDSUN_NOTARY_PROFILE:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release/$VERSION"
BUILD_DIR="${TMPDIR:-/tmp}/goldsun-release-$VERSION-build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/GoldSun.icns"
ENTITLEMENTS="$ROOT_DIR/Packaging/GoldSun.entitlements"
PASSKEY_ENTITLEMENTS="$ROOT_DIR/Packaging/GoldSun.passkeys.entitlements"
PKG_ROOT="$BUILD_DIR/pkgroot"
COMPONENT_PKG="$BUILD_DIR/$APP_NAME-component.pkg"
INSTALLER_RESOURCES="$BUILD_DIR/installer-resources"
DISTRIBUTION_XML="$BUILD_DIR/Distribution.xml"
INSTALLER_PKG="$RELEASE_DIR/$APP_NAME-$VERSION.pkg"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.app.zip"

export MACOSX_DEPLOYMENT_TARGET="$MIN_SYSTEM_VERSION"
export COPYFILE_DISABLE=1

cd "$ROOT_DIR"

rm -rf "$RELEASE_DIR" "$BUILD_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$RELEASE_DIR"

swift build -c release --product "$APP_NAME"
swift build -c release --product GoldSunCEFHelper
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
CEF_HELPER_BINARY="$(swift build -c release --show-bin-path)/GoldSunCEFHelper"
cp -X "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON" ]]; then
  cp -X "$APP_ICON" "$APP_RESOURCES/GoldSun.icns"
fi

if [[ -d "$ROOT_DIR/Resources/StartPage" ]]; then
  ditto --noextattr --norsrc "$ROOT_DIR/Resources/StartPage" "$APP_RESOURCES/StartPage"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>GoldSun</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>Web site URL</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>http</string>
        <string>https</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleURLName</key>
      <string>Local file URL</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>file</string>
      </array>
    </dict>
  </array>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.html</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.xhtml</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.url</string>
      </array>
    </dict>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Bundle the Chromium runtime (no-op when the CEF cache is absent, e.g. CI).
# Nested code must be signed before the main app below.
"$ROOT_DIR/script/bundle_cef.sh" "$APP_BUNDLE" "$CEF_HELPER_BINARY"

xattr -cr "$APP_BUNDLE" 2>/dev/null || true

if [[ "$ENABLE_PASSKEY_ENTITLEMENT" == "1" ]]; then
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "GOLDSUN_ENABLE_PASSKEY_ENTITLEMENT=1 requires a Developer ID signing identity." >&2
    exit 2
  fi

  ENTITLEMENTS="$PASSKEY_ENTITLEMENTS"
fi

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
else
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
fi
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

mkdir -p "$PKG_ROOT/Applications"
ditto --noextattr --norsrc "$APP_BUNDLE" "$PKG_ROOT/Applications/$APP_NAME.app"

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  --scripts "$ROOT_DIR/Packaging/pkg-scripts" \
  "$COMPONENT_PKG"

mkdir -p "$INSTALLER_RESOURCES"

cat >"$INSTALLER_RESOURCES/Welcome.html" <<HTML
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <style>
      body {
        color: #1f1b14;
        font: -apple-system-body;
        margin: 0;
      }

      h1 {
        font: -apple-system-title1;
        font-weight: 700;
        margin: 0 0 12px;
      }

      p {
        line-height: 1.45;
        margin: 0 0 10px;
      }
    </style>
  </head>
  <body>
    <h1>Install $APP_NAME $VERSION</h1>
    <p>This installer will install $APP_NAME $VERSION into the Applications folder.</p>
    <p>$APP_NAME is a native macOS browser focused on speed, security, and a calm Mac-first browsing experience.</p>
  </body>
</html>
HTML

cat >"$INSTALLER_RESOURCES/ReadMe.html" <<HTML
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <style>
      body {
        color: #1f1b14;
        font: -apple-system-body;
        margin: 0;
      }

      h1 {
        font: -apple-system-title2;
        font-weight: 700;
        margin: 0 0 12px;
      }

      ul {
        margin: 0;
        padding-left: 20px;
      }

      li {
        margin-bottom: 8px;
      }
    </style>
  </head>
  <body>
    <h1>$APP_NAME $VERSION</h1>
    <ul>
      <li>Installs $APP_NAME.app to /Applications.</li>
      <li>Includes the pinned Chromium/CEF runtime when it was fetched before packaging.</li>
      <li>Quit $APP_NAME before installing a replacement version.</li>
      <li>Prerelease builds may be unsigned or unnotarized unless Developer ID signing is configured.</li>
    </ul>
  </body>
</html>
HTML

cat >"$DISTRIBUTION_XML" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
  <title>Install $APP_NAME $VERSION</title>
  <organization>com.goldsun</organization>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <options customize="never" require-scripts="true" rootVolumeOnly="true"/>
  <welcome file="Welcome.html" mime-type="text/html"/>
  <readme file="ReadMe.html" mime-type="text/html"/>
  <choices-outline>
    <line choice="$BUNDLE_ID"/>
  </choices-outline>
  <choice id="$BUNDLE_ID" title="$APP_NAME $VERSION" description="Install $APP_NAME $VERSION into /Applications.">
    <pkg-ref id="$BUNDLE_ID"/>
  </choice>
  <pkg-ref id="$BUNDLE_ID" version="$VERSION" auth="Root">$(basename "$COMPONENT_PKG")</pkg-ref>
</installer-gui-script>
XML

if [[ -n "$INSTALLER_SIGNING_IDENTITY" ]]; then
  productbuild --sign "$INSTALLER_SIGNING_IDENTITY" --distribution "$DISTRIBUTION_XML" --resources "$INSTALLER_RESOURCES" --package-path "$BUILD_DIR" "$INSTALLER_PKG"
else
  productbuild --distribution "$DISTRIBUTION_XML" --resources "$INSTALLER_RESOURCES" --package-path "$BUILD_DIR" "$INSTALLER_PKG"
fi

ditto -c -k --keepParent --noextattr --norsrc "$APP_BUNDLE" "$ZIP_PATH"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "GOLDSUN_NOTARY_PROFILE is required when GOLDSUN_NOTARIZE=1" >&2
    exit 2
  fi

  xcrun notarytool submit "$INSTALLER_PKG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$INSTALLER_PKG"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

pkgutil --check-signature "$INSTALLER_PKG" || true
spctl -a -vv "$APP_BUNDLE" || true

echo "Release artifacts:"
echo "  $APP_BUNDLE"
echo "  $INSTALLER_PKG"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
