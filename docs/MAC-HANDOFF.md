# Latest handoff — 28 October 2026

Read [COMPLETION-2026-10-28.md](COMPLETION-2026-10-28.md) first. Separate WashKrew
live payments and test/live private photo processing are now active, and the
private Captain admin is deployed. This supersedes older test-only/merchant-
pending instructions below. Do not change global payment mode for a device test
or fabricate a production Captain. Training policy/content, human approvals,
approved support/legal/commercial inputs and physical iPhone/APNs acceptance
remain open. The preparation/signing commands below still apply.

# Historical handoff — 27 October 2026

**Latest owner update:** use [CLAUDE-MAC-CONTINUATION-2026-10-27.md](CLAUDE-MAC-CONTINUATION-2026-10-27.md) and its PDF in `output/pdf/` as the continuation brief. Aman will supply training design placeholders; these do not count as completed training. He is handling a separate WashKrew Razorpay merchant application/access. Do not activate the previous shared Trustkeyper live setup; new-merchant integration and acceptance remain pending. Native compilation can proceed independently of merchant onboarding.

Read [READINESS-2026-10-27.md](READINESS-2026-10-27.md) with this guide. Software and provider checks are distinct from an Xcode/device pass. Aman's content and other live business/provider gates remain separately pending; do not switch payments to live for the Mac test.

# Build and check WashKrew on the Mac

Customer and Captain are the **Flutter apps**. Their Firebase setup, phone login, camera/library, voice/video, booking, test payment/refund, assignment, photo evidence, tracking, approval and earnings code is included. The Windows checks do not prove an iOS compilation or physical-device pass. Apple signing/APNs and the checks below are the remaining Mac work.

## 1. Get this source

Use the `staging` branch containing this handoff. If transferring the folder directly, include the repository sources and both committed `pubspec.lock` files. Generated Windows `.dart_tool`, `build`, `Pods` and `Generated.xcconfig` files are not portable; a fresh Git checkout is preferable. The preparation command regenerates local Flutter configuration. Never transfer the private credential PDFs, merchant secrets or Apple signing keys with source.

A `WashKrew-Mac-source-COMMIT.zip` created with `git archive` contains the committed source, public Firebase app configuration and this guide; it excludes untracked local credentials and caches. Extract it on the Mac, open Terminal in its root folder and follow the commands below. The archive has no Git history; use a checkout of the same commit if you want to commit Mac-resolved dependency/signing changes.

## 2. Prepare the Mac once

- Install Flutter **3.38.6 stable**, the version used for these checks. Its Dart SDK is 3.10.7. The scripts also look in `~/development/flutter/bin`; alternatively put Flutter on PATH or set `FLUTTER_BIN` to the Flutter executable. Node, Firebase CLI, a Firebase login and Razorpay credentials are **not required** to compile the iPhone apps.
- Install Xcode, open it and complete its first-launch setup/license prompts. Select it as the command-line developer directory and install iOS platform support. Run `flutter doctor -v` and resolve its Xcode/iOS findings. See [Flutter's iOS setup](https://docs.flutter.dev/platform-integration/ios/setup).
- Install CocoaPods (for example, `brew install cocoapods` if Homebrew is installed). The scripts check for it without silently installing global software.
- For installation, connect an unlocked iPhone, trust the Mac and enable Developer Mode. The app deployment target is iOS 15 or later; Xcode must support the phone's actual iOS version.

From the repository root:

```sh
bash apps/flutter/tool/run-ios.sh --prepare
```

This checks both native configurations, downloads Flutter iOS artifacts, restores the **locked Dart dependencies**, updates CocoaPods specs and installs every required native plugin. Existing compatible pod versions are retained. Staging already includes Mac-resolved pod locks and project changes (`283e39b`). This follow-up adds `google_maps_flutter_ios` to both apps and `speech_to_text` to Captain; it preserves the Mac-resolved project and pod files. The preparation command must add these plugins to the native installation. Preparation checks native plugins and generates machine-local Release settings. It does not compile, sign or install an app. Commit the resulting `Podfile.lock` changes after successful compilation. Do not use `pod install --deployment` with the old locks.

If enforcing the Dart lock fails on a different Flutter version, use the tested SDK first. Do not resolve the problem by running a broad package upgrade. If CocoaPods reports an incompatible locked pod, retain the failure output and update only the named incompatible pod in that app's `ios` directory; do not delete all project/dependency files.

## 3. Signing and Apple notifications

Open each **workspace**, one at a time:

```sh
open apps/flutter/customer/ios/Runner.xcworkspace
open apps/flutter/captain/ios/Runner.xcworkspace
```

Select **Runner → Signing & Capabilities**, enable automatic signing and select the Apple team that owns these bundle IDs:

| App | Bundle ID |
| --- | --- |
| Customer | `com.amanmaheshwari.wheelio.customer` |
| Captain | `com.amanmaheshwari.wheelio.captain` |

The saved team is `8CCQQM7TP3`; verify access in Xcode rather than changing the bundle IDs to work around a signing error. The old `apps/ios/Wheelio.xcodeproj` is a SwiftUI reference and installs a different, sample-data implementation under those same bundle IDs. Use the Flutter workspaces above for this release.

Enable **Push Notifications** for both Runner targets and verify Background Modes → Remote notifications. Upload the owning team's APNs authentication key in Firebase `wheelio-apps` → Project settings → Cloud Messaging for the iOS apps. Keep Apple private keys outside Git. Native phone Auth also uses APNs and its configured reCAPTCHA return scheme; test both login and notifications. See [Firebase phone-auth setup](https://firebase.google.com/docs/auth/flutter/phone-auth).

The apps use location only while open. Before App Store submission, set `BYPASS_PERMISSION_LOCATION_ALWAYS=1` in the `geolocator_apple` pod target's Preprocessor Macros for each configuration, as described in the [plugin's iOS instructions](https://pub.dev/packages/geolocator#ios), so the app does not advertise unused Always-location authorization. Do not add background location or a promise of continuous tracking. Make persistent project changes with the native Mac tooling and commit them after checking the build.

## 4. Compile and install

With the phone connected, from the repository root:

```sh
bash apps/flutter/tool/run-ios.sh
```

This builds **Release** and installs the exact newly built artifact for Customer, then Captain. Normal builds connect to Firebase; server payments are currently **test mode**. No web Firebase JSON or payment secret is needed on the Mac. If several iPhones are connected the command asks for an explicit `--device ID`, using the IDs in its output.

Useful alternatives:

```sh
bash apps/flutter/tool/run-ios.sh customer
bash apps/flutter/tool/run-ios.sh captain
bash apps/flutter/tool/run-ios.sh --no-codesign
bash apps/flutter/tool/run-ios.sh --build-number 2
bash apps/flutter/tool/live.sh customer
```

`--no-codesign` compiles for a physical iPhone without installing or requiring a signing identity; it does not prove a signed-device pass. Hot reload runs one Debug app while the terminal remains connected. Use Release for the final check. `--demo` is only for the visibly labelled sample app and must not be used for acceptance.

## 5. Final check on real iPhones

Use actual consenting test users and an operator-approved **test-mode** captain. Do not seed fake captains or fixed OTPs into production. Prefer two phones, or use the Customer web app with the Captain phone.

- Open both Release apps after disconnecting Xcode. Verify WashKrew branding (there is no test-payment banner; it was removed on 25 Oct at the owner's request), then real SMS login, resend/edit number, profile and sign-out/reopen.
- Allow/deny/re-enable camera, photos, microphone and speech recognition; use the existing quiz microphone in English/Hindi/Telugu and test unavailable/denied recognition without losing tap answers. Test the native map and movement of its existing pin, including a failed map load and retry.
- Allow/deny/re-enable camera, photos and microphone; cancel capture; replace all four vehicle photos, Captain selfie/KYC and before/after wash photos. Record, preview, delete and retry voice/video uploads. Verify private media from the assigned Captain account.
- Make a test-payment booking. Check payment cancellation/retry, app switching and lost-callback status recovery. Verify a refundable cancellation reaches its real test-provider refund result. No live funds are required.
- Claim the offer, confirm the same assignment for both users, share optional foreground GPS, arrive, start/finish with four evidence photos, approve and rate from Customer, then check Captain earnings. The face check must use the consenting Captain’s approved reference photo; check a clear match, a bad/different capture and the human-review path. Inspect real advisory photo warnings, retake the correct side, and check that send-anyway still leaves Customer approval in control. Check future-slot restrictions and Customer cancellation while Captain is viewing a job.
- Test denied notifications, inbox persistence, foreground/background push and notification taps. Lock/background the Captain app and confirm the Customer sees stale location instead of a claim of continuous tracking.

Record the device/iOS/Xcode versions and outcomes in `docs/WEB-ACCEPTANCE.md` or a separate iOS acceptance record. Failed signing, APNs delivery, camera and UPI checks remain open until tested on hardware. Razorpay website approval, reviewed commercial settings and real live-mode captains are separate launch gates in [LIVE-LAUNCH.md](LIVE-LAUNCH.md); do not switch the server to live payments as part of compiling.

## Checks completed before transfer

On Windows, 27 October: all **89 backend/rules tests**, **24 Flutter tests** (8 Customer, 14 shared Firebase, 1 Captain speech parser, 1 shared image-quality check) and **3 actual local model tests** passed. Analyses of both apps, both shared packages and the iOS preparation tool are clean. Both release web builds passed and were published in test mode. Standalone tooling tests validate both native configurations and device/plugin safety checks; native compilation is intentionally guarded to macOS.

Authenticated local HTTP acceptance exercised booking, assignment, a real private local face comparison, eight image uploads, wash tracking, Customer approval/rating/earnings and a single-use receipt. Its payment capture was simulated; the previous actual merchant test captures/refunds remain a separate acceptance record. Actual deployed private-model/Gemini checks and Google Routes requests passed without a production QA user or booking. Fresh local browser checks verified both restored accounts, the Captain's completed order and the real draggable map with its persisted parking coordinates. Deployed API access/signature checks and hosted bundle hashes passed. Exact boundaries are recorded in [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md); these checks do not substitute for Xcode and device acceptance.
