# Flutter iPhone integration — 24 October 2026

The current source connects both Flutter iPhone apps to Firebase by default. It was prepared on Windows; Xcode compilation, signing and physical iPhone acceptance remain for the owner's Mac. The SwiftUI reference apps are unchanged. No Android platform was generated.

## Build on the Mac

After pulling `staging`, from the repository root:

```sh
bash apps/flutter/tool/run-ios.sh
```

This builds and installs Customer and Captain on a connected, unlocked iPhone. Flutter runs CocoaPods installation for the new plugins; commit the resulting `Podfile.lock` updates after a successful Mac build. The existing lockfiles came from the previous Mac build and do not yet include the new native plugins. Do not use `pod install --deployment` until they have been refreshed.

For hot reload, use `bash apps/flutter/tool/live.sh customer` or `captain`. For an explicitly labelled sample app only, pass `customer --demo` or `captain --demo`. Normal builds never use sample OTPs or lifecycle timers. Scripts validate the app name and use LF line endings.

## Firebase configuration

Both apps are registered in `wheelio-apps`, under the existing owner account:

- Customer: `com.amanmaheshwari.wheelio.customer`, Firebase app `1:763324255731:ios:e608aa639acba895ef9686`.
- Captain: `com.amanmaheshwari.wheelio.captain`, Firebase app `1:763324255731:ios:a3ecaa80486a8314ef9686`.

`packages/wheelio_firebase/lib/src/ios_options.dart` contains public Firebase identifiers. Native initialization selects the correct app by role and passes explicit options; it does not require adding a plist resource to the Xcode project. Downloaded public `GoogleService-Info.plist` files are retained alongside each Runner for reference. They contain no service account or Razorpay secret. `Info.plist` includes the encoded app-ID URL scheme for Firebase Auth reCAPTCHA, camera/photos/microphone/location descriptions, UPI URL queries and the remote-notification background mode. Firebase delegate swizzling remains enabled.

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

Payment integration remains in test mode. The signed-in merchant dashboard showed an existing live key with a masked secret, and only Trustkeyper's website approved. Adding Wheelio requires Razorpay's mobile OTP to the merchant's registered phone. The phone was initially unavailable; a fresh verification OTP has now been requested after the owner obtained it. Verification is still pending. No key was regenerated, no live payment was made and no Trustkeyper webhook or Route configuration was changed. Resume that verification when the phone is available. Before live cutover, confirm the merchant business model permits Wheelio, obtain the existing live secret securely, add a separate signed live webhook, and preserve test-key handling for historical test refunds. Test credentials are not live credentials.

## Physical acceptance checklist

1. Install both Release apps; reopen without Xcode attached. Verify the test-payment label.
2. Real SMS OTP, resend/edit number, existing account, new account and sign-out/reopen.
3. Camera allow/deny/re-enable, library-only access, cancellation, all four Customer photos, Captain selfie/KYC and before/after replacement. Camera tests require hardware.
4. Real optional voice/video capture, cancel/delete/re-record, preview, private assigned-Captain playback, interrupted upload and retry.
5. Test Razorpay UPI/card success, cancellation, app switching, callback recovery and no duplicate charge. Verify free checkout, partial credit and cancellation restoration using authorized test balances; do not seed production captains or fixed OTPs.
6. Booking assignment races, work-hour filtering, future jobs, customer cancellation while Captain is viewing, live foreground GPS, four-photo start/finish gates, customer approval, rating, dispute and earnings.
7. Inbox persistence and the Apple push checks above. Transfers and dispute resolutions remain operations actions.

Automated results and deployment details are recorded in `FLUTTER.md`; physical tests are intentionally not marked passed here.
