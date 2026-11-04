#!/bin/bash
# Export both App Store IPAs locally. Does not upload or submit either app.
set -euo pipefail
TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$PATH:$HOME/development/flutter/bin:/opt/homebrew/bin:/usr/local/bin"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_PATH="$(command -v "$FLUTTER_BIN")" || { echo "Install Flutter 3.38.6 or set FLUTTER_BIN." >&2; exit 1; }
export FLUTTER_BIN="$FLUTTER_PATH"
exec "$(dirname "$FLUTTER_PATH")/dart" "$TOOL_DIR/ios.dart" archive "$@"
