#!/bin/bash
# Live mode: run one app on the connected iPhone with hot reload.
#
#   apps/flutter/tool/live.sh customer     (or: captain)
#
# Then press  r  in this window to show the latest code changes on the phone
# within a second,  R  to restart the app, and  q  to stop.
# A live-mode (debug) app only opens while this window is running. Afterwards,
# install a normal build with tool/run-ios.sh or Xcode's Run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export PATH="$HOME/development/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
APP="${1:-customer}"
DEVICE="$(flutter devices --machine 2>/dev/null | node -e '
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  const d = JSON.parse(s).find(x => x.targetPlatform === "ios" && !x.emulator);
  if (!d) { console.error("No iPhone found. Plug it in, unlock it and trust this Mac."); process.exit(1); }
  console.log(d.id);
});')"
cd "$ROOT/apps/flutter/$APP"
echo "=== $APP: starting live mode on your iPhone (first start takes a few minutes) ==="
exec flutter run -d "$DEVICE" --dart-define=WHEELIO_DEMO=true
