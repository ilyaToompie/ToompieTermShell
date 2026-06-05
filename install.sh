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

# No bundled frameworks needed — the Lottie dependency was removed.
rm -rf "$APP/Contents/Frameworks"

# Quit any running instance so `open` launches the freshly built binary instead of
# just re-focusing the old in-memory process.
osascript -e 'quit app "ToompieTermShell"' 2>/dev/null || true
killall ToompieTermShell 2>/dev/null || true
sleep 1

rm -rf "$DEST"
cp -R ToompieTermShell.app "$DEST"

echo "Signing…"
codesign --force --deep --sign "$CERT" "$DEST"

echo "Installed to $DEST"
open -n "$DEST"
