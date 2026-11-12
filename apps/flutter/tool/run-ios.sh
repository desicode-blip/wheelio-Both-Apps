#!/bin/bash
# Prepare, build and install the current Flutter apps. See docs/MAC-HANDOFF.md.
set -euo pipefail
TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$PATH:$HOME/development/flutter/bin:/opt/homebrew/bin:/usr/local/bin"
# CocoaPods fails without a UTF-8 locale (scripts started by Xcode have none).
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_PATH="$(command -v "$FLUTTER_BIN")" || { echo "Install Flutter 3.38.6 or set FLUTTER_BIN to its executable." >&2; exit 1; }
export FLUTTER_BIN="$FLUTTER_PATH"
exec "$(dirname "$FLUTTER_PATH")/dart" "$TOOL_DIR/ios.dart" build "$@"
