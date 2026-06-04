#!/bin/bash
set -e
cd "$(dirname "$0")"

CERT="56B521C962ECC4F0AF85D3E630D2185B90A4B0C8"
DEST="$HOME/Applications/ToompieTermShell.app"

APP="ToompieTermShell.app"

echo "Building release…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "Packaging…"
cp "$BIN_DIR/ToompieTermShell" "$APP/Contents/MacOS/ToompieTermShell"

# Embed the dynamic Lottie framework so the bundle is self-contained.
mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Lottie.framework"
cp -R "$BIN_DIR/Lottie.framework" "$APP/Contents/Frameworks/Lottie.framework"
# Point @rpath at the embedded framework (binary is copied fresh each run, so no duplicate rpaths).
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/ToompieTermShell" 2>/dev/null || true

rm -rf "$DEST"
cp -R ToompieTermShell.app "$DEST"

echo "Signing…"
codesign --force --deep --sign "$CERT" "$DEST"

echo "Installed to $DEST"
open "$DEST"
