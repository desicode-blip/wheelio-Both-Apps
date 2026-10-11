#!/usr/bin/env bash
# One-time setup of the customer app once Flutter is installed.
# Generates the ios/ and android/ folders (they are not hand-written), adds
# the permission texts iOS requires, fetches packages and runs the tests.
#
#   bash legacy/tool/bootstrap_customer.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/customer"

command -v flutter >/dev/null || { echo "Flutter is not installed. See docs/CONNECT-LATER.md step 1."; exit 1; }

cd "$APP"
# Bundle id: com.wheelio.customer (change --org if the company domain differs).
flutter create --org com.wheelio --project-name wheelio_customer --platforms ios,android .
# flutter create adds a counter-app test that doesn't apply to this app.
if grep -q "MyApp" test/widget_test.dart 2>/dev/null; then rm test/widget_test.dart; fi

PLIST="$APP/ios/Runner/Info.plist"
add_key() {
  /usr/libexec/PlistBuddy -c "Delete :$1" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"
}
add_key NSCameraUsageDescription "Take photos so the washer can find your vehicle and so you can report a problem."
add_key NSLocationWhenInUseUsageDescription "Find washers in your society and confirm where your vehicle is parked."
add_key NSMicrophoneUsageDescription "Record a voice note for the washer about the gate or parking."
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Wheelio" "$PLIST" 2>/dev/null || true

flutter pub get
(cd "$ROOT/packages/wheelio_ui" && flutter pub get)
flutter analyze
flutter test

echo
echo "Ready. Run on the iPhone simulator with:"
echo "  open -a Simulator && cd legacy/apps/customer && flutter run"
