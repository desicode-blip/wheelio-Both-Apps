# Mac setup for the current native apps - 3 November 2026

Start with [the current build/test handoff](AMAN-IOS-HANDOFF-2026-11-02.md) and
[the Claude prompt](AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md). Those give the role
order and current policies. Superseded PDFs and duplicate guides were removed.

## Required on Aman's Mac

- Flutter **3.38.6 / Dart 3.10.7**, full Xcode with a compatible iPhone SDK,
  CocoaPods, and a physical iPhone that trusts the Mac and enables Developer Mode.
- Apple Developer access to paid **Sumit Mandal / 28JNT7H8KA**. Aman completes
  Apple/Xcode authentication, licenses, device trust and security prompts.
- Preserve bundle IDs `com.amanmaheshwari.wheelio.customer` and `.captain`.
  Use both `ios/Runner.xcworkspace` files, not the bare project without Pods.

## Prepare and install

```sh
flutter doctor -v
dart apps/flutter/tool/ios.dart check
dart apps/flutter/tool/ios_test.dart
bash apps/flutter/tool/run-ios.sh --prepare
bash apps/flutter/tool/run-ios.sh
```

Use `--device IPHONE_ID` when several devices are attached; `--no-codesign`
compiles only and does not establish signing/install success. Use a higher
positive `--build-number NUMBER` if the existing installed/TestFlight version
requires it. Do not rename apps, identifiers or teams to bypass signing problems.
Run Release apps from the iPhone Home screen after disconnecting Xcode.

The helper regenerates ignored machine-local Flutter configuration and installs
Pods. Keep compatible committed dependency locks. Captain's older native pod lock
may need the already-declared camera plugin resolved by `pod install`; do not
remove all locks or upgrade every package as a first step. Commit Mac-resolved
lockfile changes only after successful builds.

## APNs and errors

Key **Y5432Q73U8** is already saved in Firebase for both apps/environments.
No `.p8`, Firebase CLI login, service-account key or Razorpay secret is needed to
compile the clients. See [Apple setup](APPLE-PUSH-SETUP-2026-11-01.md).
If phone login falls back to Firebase verification, check the actual signed
`application-identifier`/`aps-environment` entitlements, Push Notifications,
Background fetch/Remote notifications and iPhone Background App Refresh.
Record safe error codes and token presence only; never token/key values.
Do not disable verification for real SMS.

Copy [the results template](IOS-ACCEPTANCE-RESULTS-TEMPLATE.md) and record the
commit, versions, Mac/Xcode/iOS and actual PASS/FAIL/BLOCKED/NOT RUN per case.
Windows preflight/source tests do not establish Mac signing or device success.
