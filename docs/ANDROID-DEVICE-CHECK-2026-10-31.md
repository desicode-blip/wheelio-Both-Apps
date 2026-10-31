# Android installation and native OTP - 31 October 2026

The owner requested installation of both maintained Flutter apps on the connected
Android phone. Source starts at `af6d804`. No authored Customer/Captain screen,
layout, typography, palette, brand master or asset inside Flutter is replaced.

## Native setup

- Added only the Android platform directories to Customer and Captain. They use
  the existing `lib/main.dart`, shared packages and locked Flutter dependencies.
- Registered `com.amanmaheshwari.wheelio.customer` and
  `com.amanmaheshwari.wheelio.captain` in the existing `wheelio-apps` project.
  Android app IDs are `1:763324255731:android:d0687e4e12291913ef9686` and
  `1:763324255731:android:3370a35ef9bb652bef9686`. Native initialization selects
  the matching app rather than the Web app ID. Unrelated project overrides fail.
- Downloaded public `google-services.json` configuration, added the Google
  Services plugin, and registered this laptop's debug SHA-1 and SHA-256 for both
  apps. Private signing material stays outside Git. Android minimum is API 24.
- Android launch icons are density-sized copies of each existing iOS icon master.
  App labels use the existing Customer/Captain brand names. Added camera, audio,
  foreground location, notification and Internet declarations, with runtime
  permission decisions still handled by the existing app/plugin controls.
- Added UPI/browser/phone intent visibility. Payment policy is still server-owned;
  no checkout, real charge or booking was created by setup.
- Enabled Maps SDK for Android in the same project. Its public Android key is
  restricted to that API and the two package/debug-certificate combinations.
  Android reads its manifest key; iOS keeps its existing key/channel. Store or
  another developer's signed builds require their actual certificate registration.
- APKs use a debug certificate for USB acceptance only; the release configuration
  also deliberately uses that local certificate until private store signing exists.
  These are not Play Store distribution builds. Future store signing must use
  privately managed upload credentials and the Play signing certificate.

## OTP: what can and cannot be removed

Both apps already call native `verifyPhoneNumber` on Android/iOS. Browser login
alone calls `signInWithPhoneNumber`. There is no additional WashKrew bot-check
screen in the native Flutter screen tree.

Firebase itself can require reCAPTCHA as a fallback. Android normally uses Play
Integrity; Firebase documents that sideloaded apps can trigger reCAPTCHA. iPhone
normally uses silent APNs and falls back when silent verification is unavailable.
Suppressing the fallback would prevent real SMS login in those cases. App
verification is not disabled for real phone numbers. Only isolated `demo-*`
emulator builds keep the existing testing bypass.

Both iOS plists now include Background fetch alongside Remote notifications,
as required by Firebase's silent-verification setup. Bundle IDs, signing team,
existing URL callback scheme and SDK delegate handling remain intact. The owner
confirmed that Aman will provide the private Apple `.p8` key and Key ID later.
This is still needed for silent iPhone verification. A fully CAPTCHA-free
requirement needs a separate OTP-service decision; it is not achieved by hiding
Firebase's mandatory verification view.

Official references: [Flutter phone auth](https://firebase.google.com/docs/auth/flutter/phone-auth),
[Android verification](https://firebase.google.com/docs/auth/android/phone-auth),
[iPhone silent verification](https://firebase.google.com/docs/auth/ios/phone-auth).

## Rebuild

Use Flutter 3.38.6, Java 17 and Android SDK 36. For each app directory:

```sh
flutter pub get --enforce-lockfile
flutter build apk --debug --target-platform android-arm64
```

Public native Firebase identifiers are bundled; no Web `--dart-define` is needed.
The USB development APK is `build/app/outputs/flutter-apk/app-debug.apk` under each
app. `--release` builds the optimized variant separately; it needs its own build
and native acceptance result.
For installation use the selected authorized Android device with `flutter install`
or Android's `adb install -r`. Never clear an existing user's data or uninstall
to work around a signing mismatch without their approval.

## Acceptance evidence

Connected device: CPH2707, Android 16 / API 36, physical 1272 x 2800, density 560,
with Google Play services installed. The phone was initially
unauthorized; the owner explicitly accepted USB debugging. The initial optimized
Customer build reached R8 but was stopped after memory pressure on this 8 GB
Windows laptop. It is not a passed release build. Native UI acceptance switched
to ordinary development APKs with the same Flutter screens and Firebase backend;
no `WHEELIO_DEMO` or emulator bypass is enabled. Gradle memory, processor count,
workers and Kotlin process usage are bounded, with caching enabled for later
builds. Device serial, phone numbers and OTPs are not stored
in this report.

Four Flutter analyses and **83 Flutter tests** pass (48 Customer, 10 Captain,
25 shared Firebase). The new native-configuration tests cover Android role/project
selection, emulator isolation, platform-specific Maps keys and error propagation.
Existing native OTP session tests still pass. Both portable iOS source checks pass;
these are source checks, not Xcode compilation.

Build/install/manual results will be recorded after the final APK checks.
An Android result does not establish iPhone compilation, camera, payment switching
or APNs acceptance. No production Captain approval or payment is authorized merely
by this UI inspection.
