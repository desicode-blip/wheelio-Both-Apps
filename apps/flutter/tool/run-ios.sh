#!/bin/bash
# Build the Flutter apps for iPhone and install them on the connected phone.
#
#   apps/flutter/tool/run-ios.sh            # both apps
#   apps/flutter/tool/run-ios.sh captain    # one app (customer | captain)
#
# Phone builds use sample data for now (WHEELIO_DEMO=true): the live Firebase
# backend needs iOS apps registered in Firebase, native phone sign-in and native
# Razorpay first (see docs/BACKEND-HOOKUP.md, "Native iPhone builds").
# Bundle IDs match the SwiftUI apps, so these replace them on the phone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export PATH="$HOME/development/flutter/bin:$PATH"
APPS="${1:-customer captain}"

command -v flutter >/dev/null || { echo "Flutter not found in ~/development/flutter/bin"; exit 1; }
# CocoaPods fetches Firebase for iPhone builds. Install it once if it's missing.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v pod >/dev/null; then
  if command -v brew >/dev/null; then
    echo "=== Installing CocoaPods (one time, a few minutes) ==="
    brew install cocoapods
  else
    echo "Homebrew is needed to install CocoaPods. Install it from https://brew.sh (it asks for your Mac password), then run this again."
    exit 1
  fi
fi

DEVICE="$(flutter devices --machine 2>/dev/null | node -e '
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  const d = JSON.parse(s).find(x => x.targetPlatform === "ios" && !x.emulator);
  if (!d) { console.error("No iPhone found. Plug it in (or keep it on the same Wi-Fi), unlock it and trust this Mac."); process.exit(1); }
  console.log(d.id);
});')"

for APP in $APPS; do
  echo ""
  echo "=== $APP: building for iPhone (first build takes several minutes) ==="
  cd "$ROOT/apps/flutter/$APP"
  flutter pub get
  flutter build ios --release --dart-define=WHEELIO_DEMO=true
  echo "=== $APP: installing on the phone ==="
  flutter install -d "$DEVICE" --release
done
echo ""
echo "Done. Open the app on your iPhone."
