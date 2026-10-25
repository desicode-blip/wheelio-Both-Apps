# Flutter iPhone integration — 24 October 2026

The current source connects both Flutter iPhone apps to Firebase by default. The native integration was prepared on Windows; Xcode compilation, signing and physical iPhone acceptance remain for the owner's Mac. Flutter remains the active app stack; the SwiftUI apps remain references. No Android platform was generated.

The 25 October staging merge includes the WashKrew name, logo and palette. Shared code now lives in `packages/washkrew_firebase` and `packages/washkrew_ui`; iOS bundle IDs and Firebase registrations retain `wheelio` intentionally. The default Firebase build and all native capture/payment functionality below are retained.

## Build on the Mac

Use [MAC-HANDOFF.md](MAC-HANDOFF.md) for Mac setup, signing and the final device checklist. After getting the current `staging` source, prepare the Flutter workspaces first:

```sh
bash apps/flutter/tool/run-ios.sh --prepare
```

Then, with signing configured and the iPhone connected, from the repository root:

```sh
bash apps/flutter/tool/run-ios.sh
```

This builds and installs Customer and Captain on a connected, unlocked iPhone. The tools check Xcode/iOS SDK/CocoaPods, regenerate Flutter's local files (including copied Windows paths), enforce the Dart locks, refresh CocoaPods specs and verify every native plugin is installed. They use Flutter's bundled Dart, with no Node dependency. Multiple connected phones require `--device ID`; unknown arguments fail instead of silently changing the build. `--no-codesign` compiles without signing/installing, and `--build-number N` supports later releases. Commit the resulting `Podfile.lock` updates after a successful Mac build. The existing lockfiles came from the previous Mac build and do not yet include the new native plugins. Do not use `pod install --deployment` until they have been refreshed.

For hot reload, use `bash apps/flutter/tool/live.sh customer` or `captain`. For an explicitly labelled sample app only, pass `customer --demo` or `captain --demo`. Normal builds never use sample OTPs or lifecycle timers. Scripts validate the app name and use LF line endings.

## Firebase configuration

Both apps are registered in `wheelio-apps`, under the existing owner account:

- Customer: `com.amanmaheshwari.wheelio.customer`, Firebase app `1:763324255731:ios:e608aa639acba895ef9686`.
- Captain: `com.amanmaheshwari.wheelio.captain`, Firebase app `1:763324255731:ios:a3ecaa80486a8314ef9686`.

`packages/washkrew_firebase/lib/src/ios_options.dart` contains public Firebase identifiers. Native initialization selects the correct app by role and passes explicit options; it does not require adding a plist resource to the Xcode project. Downloaded public `GoogleService-Info.plist` files are retained alongside each Runner for reference. They contain no service account or Razorpay secret. `Info.plist` includes the encoded app-ID URL scheme for Firebase Auth reCAPTCHA, camera/photos/microphone/location descriptions, UPI URL queries and the remote-notification background mode. Firebase delegate swizzling remains enabled.

Phone login uses native `verifyPhoneNumber`, including resend, permission/provider failures, stale callback invalidation and one-use code confirmation. Web continues to use Firebase's browser confirmation flow. Account registration can retry after a verified OTP without consuming the code twice.

## Connected booking features

- Camera capture and photo library are separate choices. Cancelling a picker does not mark a photo complete. Permission errors provide Settings access. Customer photos and Captain KYC/before/after evidence use real files.
- Optional voice notes and videos use the microphone/camera, actual playback, 30-second/20-MB bounds and authenticated private Storage access. Only the customer and assigned captain can read a booking's media. Uploads lock after payment. No photo authenticity/AI certification is claimed.
- Typed addresses are checked against active served societies or an operator-approved address mapping. Unknown addresses are saved for review without taking payment. Operators can use `operations.cjs approve-address REQUEST_ID SOCIETY_ID`; customers then check the address again.
- Multiple windows are validated and stored server-side. One window is confirmed according to capacity; a searching booking can move to a later requested window after its current window ends. This is not a route optimizer. Captains cannot claim overlapping jobs, jobs outside their saved working hours, or expired offers.
- Free washes and credit are reserved atomically in per-user, per-payment-mode wallets. Full wallet checkout creates no Razorpay order. Cancellation, failed capacity and payment expiry restore reservations once. A late capture refunds actual cash without crediting the wallet twice. Captain earnings remain the configured full amount.
- Each booking snapshots its configured cancellation policy. Legacy orders retain cash-refund behavior. A configured wallet policy supports the staging screen's early free wash / later percentage credit; it is not enabled by silently changing commercial settings. The client displays the server policy. Entirely wallet-funded cancellations restore the original entitlement and cannot create new rewards.
- Future bookings stay scheduled; arrival and washing are blocked by server time before the confirmed window opens. Captain jobs show future bookings separately and retain cancelled jobs with a stop-work message. No undecided trip payment is invented.
- Native Razorpay checkout uses the server's amount/order/key and sends signatures to the existing server verifier. Lost callbacks are reconciled against the provider; no SDK success response alone confirms payment. UPI app switching is configured in both iOS plists.
- General support, phone-change and deletion requests create private operations tickets. They do not claim to have changed a phone number, deleted an account or arranged a callback. KYC approval, dispute decisions, legal/commercial settings, payouts and Razorpay Route linked-account onboarding remain reviewed operations.

## Notifications and Apple setup

Order transitions and offers create server-owned, private inbox entries. Both apps read their own inbox, persist read acknowledgements and can request iPhone notification permission. Tokens are stored only by authenticated server calls, removed on sign-out or disabling alerts, and refreshed when enabled. Push bodies contain no vehicle, phone, parking or location details. Notifications open the appropriate booking or available Captain offers. The inbox works without push.

Physical push acceptance is still pending. On the Mac, enable **Push Notifications** for both Runner targets with the correct Apple team/provisioning profiles, and upload the team's APNs authentication key in Firebase Project Settings → Cloud Messaging for the iOS apps. This requires the team's Apple credentials and cannot be verified from Windows. Verify both foreground and background delivery, notification taps, denied permission, token refresh and sign-out on a physical iPhone. No APNs key or Apple private signing material is committed here.

## Payment activation boundary

On 25 October merchant OTP verification completed, WashKrew's Firebase website was submitted for review, and the owner-approved separate live webhook was enabled. The dashboard now shows the website **Under review**, with an expected update in 24–48 hours. A matching existing live key pair was recovered from an owner-provided private document, verified by a read-only provider request and installed in Wheelio Secret Manager. The seven payment functions were redeployed. No key was regenerated and no Trustkeyper configuration was changed. Live and test providers both authenticate, but booking mode remains **test** until merchant approval, commercial review and real live-mode captain onboarding. See [LIVE-LAUNCH.md](LIVE-LAUNCH.md).

The test key pair is archived in `RAZORPAY_TEST_KEY_ID` and `RAZORPAY_TEST_KEY_SECRET`. Historical callbacks, reconciliation and refunds choose keys from the booking's saved payment mode. The current `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` pair now holds the verified existing live credentials. The test webhook retains its URL and signing secret. The separate `razorpayLiveWebhook` endpoint uses `RAZORPAY_LIVE_WEBHOOK_SECRET` and is registered in merchant live mode. Cross-mode payment/refund events are rejected. Secret values were transferred in memory; no credential document, extracted secret or private key was copied into source, local config or chat.

Test reservations retain their original capacity keys; live reservations have a separate namespace. Test wallets, offers and earnings remain separate from live funds, and historical test bookings/earnings carry their own labels even after the current catalog mode changes. A checkout that resolves to a cancelled booking opens the actual cancellation/refund screen instead of staying on "Payment not confirmed". The status check refreshes the stored order before choosing that route.

## Physical acceptance checklist

1. Install both Release apps; reopen without Xcode attached. Verify the test-payment label.
2. Real SMS OTP, resend/edit number, existing account, new account and sign-out/reopen.
3. Camera allow/deny/re-enable, library-only access, cancellation, all four Customer photos, Captain selfie/KYC and before/after replacement. Camera tests require hardware.
4. Real optional voice/video capture, cancel/delete/re-record, preview, private assigned-Captain playback, interrupted upload and retry.
5. Test Razorpay UPI/card success, cancellation, app switching, callback recovery and no duplicate charge. Verify free checkout, partial credit and cancellation restoration using authorized test balances; do not seed production captains or fixed OTPs.
6. Booking assignment races, work-hour filtering, future jobs, customer cancellation while Captain is viewing, live foreground GPS, four-photo start/finish gates, customer approval, rating, dispute and earnings.
7. Inbox persistence and the Apple push checks above. Transfers and dispute resolutions remain operations actions.

Automated results and deployment details are recorded in `FLUTTER.md`; physical tests are intentionally not marked passed here.
