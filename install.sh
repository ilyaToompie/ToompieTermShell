#!/bin/bash
set -e
cd "$(dirname "$0")"

CERT="56B521C962ECC4F0AF85D3E630D2185B90A4B0C8"
DEST="$HOME/Applications/ToompieTermShell.app"

echo "Building release…"
swift build -c release

echo "Packaging…"
cp .build/release/ToompieTermShell ToompieTermShell.app/Contents/MacOS/ToompieTermShell

rm -rf "$DEST"
cp -R ToompieTermShell.app "$DEST"

echo "Signing…"
codesign --force --deep --sign "$CERT" "$DEST"

echo "Installed to $DEST"
open "$DEST"
