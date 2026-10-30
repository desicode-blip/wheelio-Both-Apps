# Prompt for Aman's Claude on the Mac

Copy the text below into Claude in the existing WashKrew repository. Do not put
the Apple private key into GitHub or chat. Push source changes and a redacted
setup/results note instead.

---

Work on the latest `staging` branch of
`https://github.com/desicode-blip/wheelio-Both-Apps.git`. Preserve local work;
fetch and integrate without hard resets or force pushes. Read `AGENTS.md`,
`docs/CHANGES-2026-10-30-UI.md` and the current iOS build/test guide before changes.
If present in the pulled source, also read `docs/BACKEND-FOLLOWUP-2026-10-30.md`,
`docs/AMAN-APPLE-PUSH-KEY-REQUEST-2026-10-30.md` and
`docs/SLOT-STARTUP-2026-10-30.md`. The requirements below are self-contained even
if Ajay has not yet pushed those newer local reports.

Ajay wants minimum waiting for real booking slots without the optional roughly
US$9/month idle-server cost. Keep `interactiveWarmMinimum` and deployed minimum
instances at **0**. Do not turn on paid warming or add periodic keep-alive calls.
Normal Firebase usage still costs money. Keep Aman's current UI, layouts, assets,
typography, camera and Locate me controls unchanged. Do not revert or replace
his screens. Only change data/controller/backend behavior where needed.

1. Measure and improve slot loading. Customer `AppStore.availabilityFor` already
   caches in-flight/results for 45 seconds and `prefetchAvailability` requests
   three days when leaving C10 parking. Investigate starting that work earlier
   once a real saved/selected society is known. Avoid requests for every society,
   an unknown location or a signed-out user's private context. Deduplicate
   concurrent requests; invalidate correctly when account, society, date or
   payment context changes. Never cache errors as available capacity. Preserve
   refresh/resume behavior, exact Captain work periods/breaks, 4 AM-10 PM slots,
   current-user Captain exclusion and server validation at booking/payment/claim.
   The API currently accepts one day per call: implement/test both sides before
   introducing a batch-days contract. Do not show sample, expired or invented
   slots as bookable. Keep the existing screens and interactions.

2. Finish Apple push setup. Use paid Apple team **28JNT7H8KA**, Firebase project
   **wheelio-apps**, and the existing bundle IDs:
   `com.amanmaheshwari.wheelio.customer` and
   `com.amanmaheshwari.wheelio.captain`. Locate a suitable existing APNs
   authentication `.p8` key and its Key ID, or guide Aman (Apple Account
   Holder/Admin) to create one with the correct environment/topic permissions.
   Aman must complete Apple/Google authentication and key-creation confirmation
   himself. Do not revoke or regenerate credentials used elsewhere. Store the
   key securely **outside this repository**; do not print it, paste it into chat,
   log it, bundle it into either app or commit/upload it to GitHub.

3. In the existing project's
   [Firebase Cloud Messaging settings](https://console.firebase.google.com/project/wheelio-apps/settings/cloudmessaging),
   configure the matching APNs key/Key ID/team for both registered iOS apps.
   Respect the development/sandbox and production fields shown there. Preserve
   unrelated credentials. If Aman lacks Firebase access, record the blocker and
   arrange a private handoff to Ajay, not a Git commit containing the key. Follow
   [Firebase's Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
   and [Apple's key setup](https://developer.apple.com/help/account/keys/create-a-private-key/).

4. Build **both current Flutter apps** from their `ios/Runner.xcworkspace` files
   on the Mac, retaining the bundle IDs/paid team. Use release/profile builds for
   timing, not a debug-build timing claim. Record repeated cold-app and warm-app
   time-to-first-real-slots measurements, known saved society versus newly chosen
   society, Wi-Fi/mobile network and actual server responses. A cold app launch
   does not prove the Cloud Function was cold; label that distinction. Verify
   date/society changes, cache expiry, unavailable network, sign-out/account
   changes, no Captain capacity, exact breaks and stale-response handling. Add
   focused tests where needed. Do not claim instantaneous first-ever network
   availability with on-demand Functions.

5. On the real iPhone, verify notification permission/token registration and
   actual foreground/background/locked-screen delivery and notification taps
   for both apps. Use authorized events/accounts only. No fake production
   Captain approval, fixture booking, unsolicited push or unapproved live
   payment. Record PASS/FAIL/BLOCKED honestly, with no device tokens, private
   documents, phone numbers or other personal information in committed evidence.

6. Write `docs/AMAN-IOS-SLOTS-AND-PUSH-RESULTS.md` containing code/build versions,
   changes made, before/after timings and conditions, APNs configured/not
   configured per app/environment, physical results and remaining blockers.
   This **secret-free report** is the file Ajay needs in GitHub, along with any
   tested source changes. Check staged changes for private keys, `.p8`, `.p12`,
   credentials, tokens and personal information before committing. Commit and
   push source/report changes to `staging` without force. Return the commit hash
   and result summary. Never push the Apple private key.

---

The Windows-side backend follow-up does not establish physical iPhone timing,
APNs delivery or live charge/refund acceptance. Keep those gates separate.
