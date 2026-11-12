# WashKrew Customer and Captain: current Mac handoff

**11 November update:** Customer **1.0.6 (11)** and Captain **1.0.7 (12)** implement the approved refund coupons, successful-wash commission and admin price editing. Read [the coupon release](REFUND-COUPONS-2026-11-11.md) for the current rules and rollout. The wallet descriptions below record earlier releases.


**4 November update: read [the policy release](POLICY-RELEASE-2026-11-04.md) first. New source is Customer 1.0.4 (9) / Captain 1.0.5 (10); new cancellation credit is 98/50/0 with one-year credit expiry. Historical snapshots stay unchanged.**

**Updated 3 November 2026. This is the current starting point for Aman and Claude.**
For store archives/submission, the newer
[store release guide](STORE-RELEASE-2026-11-03.md) is the starting point.
This document continues to describe device build/install and functional checks.
It supersedes older build, society-approval, payment and APNs instructions.
The requested deliverables are the two native mobile apps and the private admin
portal. Customer/Captain web apps are not a prerequisite for this acceptance.

The same Flutter screens and functionality used on Android build for iOS.
The latest lifecycle fix is documented in
[ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md](ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md).
After deletion, test fresh signup with the same phone: old names, KYC, approval,
areas, wallet state and job/photo screens must not return from cache. A returning
deleted Captain completes the existing name form after phone verification.
Keep Aman's approved layouts, assets, typography and palette. Do not recreate
either app or restore the retired SwiftUI/React implementations.

## Pull safely and prepare

After Ajay pushes the handoff to staging, run from the existing Mac checkout:

```sh
git status --short
git fetch origin staging
git switch staging
git pull --ff-only origin staging
git rev-parse HEAD
flutter --version
flutter doctor -v
dart apps/flutter/tool/ios.dart check
dart apps/flutter/tool/ios_test.dart
bash apps/flutter/tool/run-ios.sh --prepare
```

Preserve local changes and stop to inspect a failed fast-forward; do not reset or
force-push. Use Flutter **3.38.6 / Dart 3.10.7**, full Xcode with the iPhone's iOS
SDK, and CocoaPods. Aman completes Apple sign-in, Xcode setup/license, device
trust and Developer Mode. No Firebase CLI login, Node, Razorpay secret, private
credential PDF or `.p8` file is needed to build the clients.

Preparation restores locked Dart dependencies, regenerates machine-local Flutter
files, installs Pods and checks every required native plugin. Captain's committed
Pod lock predates the guided-camera dependency; let `pod install` add the camera
pod. Keep compatible existing native locks; do not delete all locks or upgrade
all packages. Commit Mac-resolved Podfile.lock changes after successful builds.

## Sign, build and install both apps

```sh
open apps/flutter/customer/ios/Runner.xcworkspace
open apps/flutter/captain/ios/Runner.xcworkspace
```

In each Runner target, verify automatic signing with paid **Sumit Mandal** team
**28JNT7H8KA**. Keep these bundle IDs:

| App | Bundle ID | Source version/build |
| --- | --- | --- |
| Customer | `com.amanmaheshwari.wheelio.customer` | 1.0.4 (9) |
| Captain | `com.amanmaheshwari.wheelio.captain` | 1.0.5 (10) |

Use the workspace, including Pods. Keep Push Notifications, Background fetch and
Remote notifications enabled. iOS minimum is 15.0. The tool checks signing-team
consistency, entitlements, Release launch, Auth callbacks, permissions, Maps,
payment-app query schemes, native dependencies and icons before building.

```sh
# With one unlocked, trusted physical iPhone connected:
bash apps/flutter/tool/run-ios.sh
# With several physical iPhones:
bash apps/flutter/tool/run-ios.sh --device IPHONE_ID
# Optional: compile without signing/installing:
bash apps/flutter/tool/run-ios.sh --no-codesign
```

This builds and installs both Release apps. Disconnect Xcode and open each from
the iPhone Home screen. Use no `--demo` flag for acceptance. If App Store/TestFlight
already has a higher build number, use `--build-number NUMBER` with a higher
positive integer. Do not change identifiers/team to work around signing access.

Apple APNs development and production keys were configured privately in Firebase
for both apps on 1 November. See `APPLE-PUSH-SETUP-2026-11-01.md`; older statements
that the key is missing are historical. Keep private keys outside Git. The client
now waits briefly for asynchronous APNs registration and retries on app resume;
this does not prove actual delivery. Native phone verification stays enabled;
Firebase may still require its secure fallback if silent verification is unavailable.

The supplied key is **Y5432Q73U8**, team **28JNT7H8KA**, both environments and
both app topics. The screenshot confirming its creation does not establish that
an installed build receives silent pushes. Do not create, revoke or request
another private key. If native login still opens Firebase's fallback, check the
actual signed Runner entitlement for `aps-environment` and the paid-team
application identifier, Push Notifications capability, Background fetch/Remote
notifications, and iPhone Background App Refresh. Record the exact source commit,
both installed versions, physical iPhone/iOS and redacted Firebase Auth/APNs error
codes. Report token presence only, never token values. Keep native verification
enabled; see [Firebase's iOS phone-auth prerequisites](https://firebase.google.com/docs/auth/ios/phone-auth).

## Follow this role order on native apps

1. **Captain:** use a consenting number distinct from the Customer. Upload real
   Aadhaar and selfie, save real payout details, then set the map centre and
   1–10 km serving radius. Save working periods and submit for human review.
   Training/DigiLocker are hidden. Unapproved Captains cannot work.
2. **Admin:** open **https://wheelio-apps.web.app/admin/** using an authorized
   Google reviewer, including `amanmaheshwari900@gmail.com`. A human checks the
   documents/payout details and approves or requests genuine corrections. Do not
   approve a fake application as a test. Manual society approval is not required
   for current Captain-area bookings.
3. **Captain:** confirm approval and saved area/hours, then go Online. The fixed
   map centre defines coverage; job GPS is a separate arrival/location check.
4. **Customer:** sign in with the other number, confirm a real parking location
   inside coverage, vehicle and notes. Only whole time windows that fit a covering
   Captain's continuous working period and remaining capacity should be available.
5. **Customer pays:** check wallet balance/top-up and Wallet versus Razorpay.
   The separate WashKrew merchant is **LIVE**. Aman personally authorizes any
   actual charge/PIN. Supported UPI, debit cards, netbanking and provider wallets
   remain available; direct credit cards, EMI and pay-later are excluded. Reopen
   the same order after a lost callback instead of immediately paying again.
6. **Captain accepts once:** eligible Online Captains in the covering area receive
   the offer together. The first valid atomic claim wins; an expired offer is not
   proof that another Captain accepted. Confirm the Customer sees that assignment.
7. **Captain washes:** arrive at the actual vehicle in its window, complete the
   fresh identity check, upload four genuine Before photos, start washing and
   upload four genuine After photos. Capture advances while real uploads finish;
   Next/Check photos must wait for successful server evidence. Review actual
   advisory findings, retake or explicitly acknowledge as appropriate. Never
   submit staged laptop/test pictures as a completed wash.
8. **Recovery:** close/reopen at Before photos, washing and partial/full After
   photos. Uploaded evidence must restore at the saved stage without repeating
   arrival/selfie. A successfully submitted job must not restart washing.
9. **Customer approves:** after actual submission, verify Washing changes to
   Check the wash, inspect the real images, then personally approve/rate or report
   a genuine problem. Captain earnings must appear once; a ledger entry is not
   proof of a bank payout.
10. **Wallet cancellation:** within five minutes of server confirmation, full
    cash-plus-wallet value returns as wallet credit, including near-term washes.
    After grace, at least two hours before the confirmed start returns 50%; inside
    two hours returns zero. Exactly five minutes is full, exactly two hours is 50%.
    Washing closes self-cancellation. Service failures return full wallet value;
    historical cash-refund records retain their original rules.
11. **Account deletion on consenting spare test accounts:** finish/cancel open
    jobs and resolve pending payments first. In each app's Profile/Me, tap Delete
    account, confirm Yes, continue, then read and confirm the irreversible final
    dialog. No new SMS or phone-change screen should appear. Keep my account must
    cancel without deleting. A final tap shows one pending action; failures stay
    retryable. With both roles on one number, deleting one must preserve the other
    app account and its data. Test the second role separately; do not delete the
    main funded/working account merely to complete this checklist. See
    [ACCOUNT-DELETION-2026-11-03.md](ACCOUNT-DELETION-2026-11-03.md).

Use two phones where possible: Aman's iPhone plus the checked Android phone can
exercise both roles together. With one iPhone, switch the native apps but record
the limitation for simultaneous GPS/foreground checks. Keep the private admin in
a browser. No public Customer/Captain web build is needed for this sequence.

## Physical checks and honest result record

Copy `IOS-ACCEPTANCE-RESULTS-TEMPLATE.md` and record source commit, both versions,
iPhone/iOS, macOS/Xcode/Flutter/CocoaPods and actual PASS/FAIL/BLOCKED/NOT RUN.
Test camera/Photos/microphone/location deny/cancel/re-enable, fresh and persisted
login, native Maps, UPI app switch and return, notification permission plus
foreground/background/tap behavior, network loss, and restart at each wash stage.
Do not disable real OTP verification, fake GPS, approve identities or authorize
charges on Aman's behalf. Keep phone numbers, OTPs, KYC, coordinates, payment
identifiers, tokens and private keys out of Git and shared reports.

Windows can verify Flutter logic and portable native configuration. It cannot
compile/sign these iPhone apps or establish actual camera, APNs, GPS and payment
app-switch behavior. Those Mac/device results remain the final acceptance gate.

**Updated deletion follow-up:** all **177 Flutter tests** pass (Customer 76,
Captain 38, shared Firebase 54, shared UI 9), with **202 backend emulator tests**
passing. Analysis is clean for the app/shared packages and the
standalone iOS tool. Native tooling regressions pass, including five configuration
failure cases. Ten plist files and ten Xcode XML files parse successfully; both
Mac shell wrappers pass Bash syntax checks. No Xcode or CocoaPods execution was
performed on Windows, and no Apple signing key or native pod lock was fabricated.

Implementation references: [Firebase's APNs readiness requirement](https://firebase.google.com/docs/cloud-messaging/flutter/get-started#request_notification_permission)
and [Geolocator's foreground-only iOS configuration](https://github.com/Baseflow/flutter-geolocator/blob/main/geolocator/README.md#ios).

## Prompt Aman can give Claude

> Read AGENTS.md, CLAUDE.md and docs/AMAN-IOS-HANDOFF-2026-11-02.md. Preserve my
> local work, pull the latest staging safely, and prepare/build/install both
> current Flutter Release apps on my connected iPhone with the existing paid
> Apple team and bundle IDs. Use the provided Mac helper. Keep the approved UI.
> Guide me one role/action at a time through Captain → Admin → Captain Online →
> Customer booking/payment → Captain wash/reopen → Customer review → earnings
> and wallet cancellation. I perform passwords, OTPs, genuine human approvals
> and payment authorization. Reproduce failures, fix only their cause and retest.
> Record actual device evidence in the result template; do not invent a pass or
> request merchant/private APNs keys to compile the clients. Focus on native apps.
> Also test the new two-confirmation account deletion without a deletion OTP in
> both apps, including cancel/retry and preserving the other app's account. If
> login opens Firebase fallback, inspect signed APNs entitlements and Background
> App Refresh and return redacted error codes; do not disable app verification.
