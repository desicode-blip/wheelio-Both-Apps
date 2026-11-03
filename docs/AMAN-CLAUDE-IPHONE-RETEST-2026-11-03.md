# Prompt for Claude on Aman's Mac - 3 November 2026

Copy the prompt below into Claude with the existing repository open. The latest
staging includes Customer **1.0.4 (6)** and Captain **1.0.5 (7)**. These source
versions include the deletion fix; an older installed app is not a test of it.
For the owner-approved initial store release, use the newer
`AMAN-CLAUDE-STORE-PUBLISH-2026-11-03.md` prompt instead. This page remains the
device build/retest sequence.

---

Read AGENTS.md, CLAUDE.md, docs/AMAN-IOS-HANDOFF-2026-11-02.md and
docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md. Preserve my local work. Check Git status,
fetch origin, switch to staging and pull with --ff-only. If local changes or a
divergence prevent that, preserve and inspect them; no hard-reset or force-push.
Record the checked-out commit.

Prepare, build and install BOTH current Flutter Release apps on my connected
physical iPhone. Use Flutter 3.38.6, Xcode/CocoaPods and the existing helper:

```sh
flutter doctor -v
dart apps/flutter/tool/ios.dart check
dart apps/flutter/tool/ios_test.dart
bash apps/flutter/tool/run-ios.sh --prepare
bash apps/flutter/tool/run-ios.sh
```

Only build apps/flutter/customer and apps/flutter/captain. Use their respective
ios/Runner.xcworkspace files, paid team **28JNT7H8KA (Sumit Mandal)** and existing
com.amanmaheshwari.wheelio.customer / .captain bundle IDs. Keep the approved
designs exactly as they are. Fix functionality only; no alternative screens.
Use a higher --build-number if a prior installed/TestFlight build requires it.
Resolve declared native plugins with CocoaPods and preserve compatible locks.
No Firebase CLI login, Razorpay secret or APNs private key is needed to compile.

APNs key Y5432Q73U8 is already configured in Firebase for both apps/environments.
Check signed application-identifier/aps-environment, Push Notifications,
Background fetch/Remote notifications and iPhone Background App Refresh.
If phone login shows Firebase fallback, record versions/commit, iPhone/iOS and
redacted Auth/APNs error codes plus whether a token became available. Never
print token/private-key values or disable verification for real SMS.

Disconnect Xcode and open both Release apps from the iPhone Home screen.
Guide me one action at a time through this order:

1. Captain: phone login, real Aadhaar/selfie/payout upload, map centre and 1-10 km
   radius, work periods and application submission. Training/DigiLocker stay hidden.
   Confirm the application reaches the private admin.
2. Admin: https://wheelio-apps.web.app/admin/ - I use my authorized reviewer
   account and personally review/approve or request corrections. No automatic
   identity approval; no manual society approval for new Captain-area bookings.
3. Captain: confirm approval, coverage/hours persistence and go Online.
4. Customer: login with a different consenting number, confirm a home inside
   coverage, save vehicle/parking and check whole windows match Captain hours
   and remaining capacity. Book and inspect wallet versus Razorpay. This is LIVE
   money; I authorize any charge and enter payment PINs myself.
5. Captain: check prompt offer delivery and one-tap atomic acceptance; Customer
   must see the same assignment. Complete actual arrival/selfie, genuine Before
   photos, washing, genuine After photos and Check photos. Never stage fake wash
   evidence. Reopen during the job: uploaded progress must restore without another
   completed selfie/arrival step. Customer must reach wash review after submission.
6. Customer: review genuine evidence, approve/rate or report a genuine problem.
   Check Captain earnings once; a ledger is not proof of a bank transfer.
7. Check wallet balance, an explicitly authorized top-up credited once, wallet
   booking, insufficient-credit handling, cancellation quote and credit reuse.
   New cancellations give 100% wallet value within five minutes, then 50% at least
   two hours before start, otherwise zero; first-five-minute grace takes priority.
   Service failures give full wallet value; historical obligations keep their terms.
8. On consenting spare accounts, test deletion in BOTH apps: Delete account ->
   Yes, continue -> irreversible final confirmation. No deletion OTP/phone-change
   screen. Keep my account must cancel at either stage; repeated taps must not send
   duplicates and failures must stay retryable. With both roles on one number,
   deleting one must preserve the other. Resolve open jobs/pending payments/balance
   safeguards first; do not delete a main funded working account.
   Then sign up again with that same phone. Customer must be fresh and able to
   select a place/book; Captain must collect the name and new documents/area/hours
   and require new human approval. Old photos/settings must not return from cache.
9. Check denied/cancelled/re-enabled permissions, app restart, network recovery,
   camera/gallery/GPS, push delivery/tap and actual UPI app-switch return.

I perform passwords, OTPs, genuine approvals and payments. Use two devices for
simultaneous roles where possible; record one-phone limits otherwise. Private
admin stays in a browser; Customer/Captain web acceptance is not required.
Record actual PASS/FAIL/BLOCKED/NOT RUN with reproduction steps and safe evidence
in a dated copy of the results template. Reproduce failures, make narrow functional
fixes, and retest. Do not invent passes or redesign. Keep KYC, phone numbers, GPS,
payment identifiers and secrets out of Git/shared reports. Commit Mac-resolved
fixes/locks and give us exact commits/results; push only if asked.
