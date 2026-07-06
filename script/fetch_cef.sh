#!/usr/bin/env bash
#
# Downloads the pinned CEF (Chromium Embedded Framework) binary distribution
# into ThirdParty/CEFCache and points ThirdParty/CEFCache/current at it.
#
# The version and checksums below are pinned on purpose. Do not float to
# "latest". To move to a new CEF build, update CEF_VERSION and both SHA-256
# values here, plus ChromiumRuntimeVersion.swift, its tests, and
# docs/ChromiumBackend.md together.
#
# Usage:
#   ./script/fetch_cef.sh          # download + verify + extract if needed
#   ./script/fetch_cef.sh --force  # re-download and re-extract
set -euo pipefail

CEF_VERSION="149.0.6+g0d0eeb6+chromium-149.0.7827.201"
CEF_FLAVOR="minimal"
CEF_CDN="https://cef-builds.spotifycdn.com"

# SHA-256 of the pinned distribution archives, one per architecture.
CEF_SHA256_MACOSARM64="232412125e50f61597151eba49cee4082ccde55dc900bd8fd3252662f8c230f4"
CEF_SHA256_MACOSX64="01fd96697c601c460387af8925e1bd09ad545509773e9f498f8240f036bf76f2"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$ROOT_DIR/ThirdParty/CEFCache"
FORCE="${1:-}"

case "$(uname -m)" in
  arm64)
    CEF_PLATFORM="macosarm64"
    CEF_SHA256="$CEF_SHA256_MACOSARM64"
    ;;
  x86_64)
    CEF_PLATFORM="macosx64"
    CEF_SHA256="$CEF_SHA256_MACOSX64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

DIST_NAME="cef_binary_${CEF_VERSION}_${CEF_PLATFORM}_${CEF_FLAVOR}"
ARCHIVE_NAME="$DIST_NAME.tar.bz2"
ARCHIVE_PATH="$CACHE_DIR/$ARCHIVE_NAME"
DIST_DIR="$CACHE_DIR/$DIST_NAME"
# CEF version strings contain "+" which must be percent-encoded in URLs.
ARCHIVE_URL="$CEF_CDN/${ARCHIVE_NAME//+/%2B}"

mkdir -p "$CACHE_DIR"

if [[ "$FORCE" == "--force" ]]; then
  rm -rf "$DIST_DIR" "$ARCHIVE_PATH"
fi

if [[ -d "$DIST_DIR/include" && -d "$DIST_DIR/Release/Chromium Embedded Framework.framework" ]]; then
  echo "CEF $CEF_VERSION ($CEF_PLATFORM) already present."
else
  if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "Downloading $ARCHIVE_NAME ..."
    curl -fL --retry 3 --progress-bar -o "$ARCHIVE_PATH.partial" "$ARCHIVE_URL"
    mv "$ARCHIVE_PATH.partial" "$ARCHIVE_PATH"
  fi

  echo "Verifying SHA-256 ..."
  echo "$CEF_SHA256  $ARCHIVE_PATH" | shasum -a 256 -c - >/dev/null

  echo "Extracting ..."
  rm -rf "$DIST_DIR"
  tar xjf "$ARCHIVE_PATH" -C "$CACHE_DIR"

  if [[ ! -d "$DIST_DIR/include" ]]; then
    echo "Extraction did not produce $DIST_DIR/include" >&2
    exit 1
  fi
fi

ln -sfn "$DIST_NAME" "$CACHE_DIR/current"

# The bridge sources decide stub-vs-real CEF via __has_include, which the
# build system cannot see change; force them to recompile.
touch "$ROOT_DIR/Sources/GoldSunCEFBridge/GoldSunCEFBridge.mm" \
      "$ROOT_DIR/Sources/GoldSunCEFHelper/main.mm"

echo "CEF ready at ThirdParty/CEFCache/current -> $DIST_NAME"
echo "Rebuild with: swift build (the GoldSunCEFBridge target picks up the cache automatically)"
