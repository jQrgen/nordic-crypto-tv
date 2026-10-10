#!/usr/bin/env bash
# Generates NordicCrypto.xcodeproj from project.yml with a pinned XcodeGen.
#
#   scripts/xcodegen.sh
#
# The release zip is downloaded once into build/tools/ and checked against its
# SHA-256, so CI and local builds use the same generator. Bump both values
# together (shasum -a 256 xcodegen.zip).
set -euo pipefail

XCODEGEN_VERSION="2.46.0"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLS="$ROOT/build/tools/xcodegen-$XCODEGEN_VERSION"
BIN="$TOOLS/xcodegen/bin/xcodegen"

if [ ! -x "$BIN" ]; then
  rm -rf "$TOOLS"
  mkdir -p "$TOOLS"
  curl -fsSL --retry 3 -o "$TOOLS/xcodegen.zip" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
  echo "$XCODEGEN_SHA256  $TOOLS/xcodegen.zip" | shasum -a 256 -c - >/dev/null
  unzip -q "$TOOLS/xcodegen.zip" -d "$TOOLS"
fi

"$BIN" generate --spec "$ROOT/project.yml" --project "$ROOT"
