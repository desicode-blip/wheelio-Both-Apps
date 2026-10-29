# Customer / Captain browser acceptance — 29 October 2026

**Later follow-up:** [FULL-WORKFLOW-2026-10-29.md](FULL-WORKFLOW-2026-10-29.md)
completes the previously HTTP-only wash/photo/Customer approval/rating steps in
the browser, using a new local booking in its actual time window and original
offer TTL. This earlier report remains historical evidence, including its limits.

Source: staging `cc3f0b6` plus the error-recovery changes in this report's commit.
Design remains af036f0, with the owner's approved W05 upload-only exception.
No layouts, colours, components, assets, app IDs or native projects changed.
Training remains hidden and human Captain approval remains required.

## Environment and evidence boundaries

Actual Flutter Firebase controllers ran in separate Customer (`localhost:8085`)
and Captain (`localhost:8086`) browser sessions, with the private admin page.
Auth, Firestore, Storage and Functions used loopback `demo-wheelio` emulators.
Public/synthetic photo fixtures were used; no real KYC, identity approval,
production QA account or production booking was created. No live key was made
available to this runner; only the archived TEST merchant was available.
Production remains configured for the separate WashKrew LIVE merchant.

The first browser session on 28 October verified signup and document uploads.
After the pause stopped its services, the submitted disposable application and
previously verified 4 AM–10 PM hours were reconstructed locally. Review,
availability, booking and subsequent checks below used the browser again.
Local Functions workers sometimes exceeded their startup deadline. A sequential
debug runner was used after exporting/importing local state; this is not evidence
of parallel production execution. Concurrent assignment protection remains covered
by the existing backend tests.

## Observed browser results

| Check | Result / evidence |
| --- | --- |
| Customer and Captain phone authentication | PASS: two distinct disposable numbers requested and confirmed Auth-emulator SMS through the app. Registration retry recovered after local worker startup without reusing the OTP credential. |
| Captain document upload | PASS in the first browser session: Upload Aadhaar photo -> camera/gallery/cancel sheet; cancel left KYC incomplete; gallery uploaded real bytes privately; selfie and payout saved; application submitted for human review. No DigiLocker or training step. A web picker is not an iPhone camera pass. |
| Private reviewer enforcement | PASS: signed-in Google-emulator identity was denied with 403 until added to the local-only reviewer fixture. Production reviewer configuration was unchanged. |
| Private admin evidence | PASS: Aadhaar and selfie loaded through the private photo controls; payout and society controls displayed. |
| Stale review prevention | PASS: a work-hours edit after opening the application caused a 409; refresh and re-review were required. |
| Admin approval -> Captain | PASS: explicit confirmation saved the review/history and notification. The Captain's earlier request to go online resumed after approval; an unapproved Captain remained offline. |
| Availability before approval | PASS: Tomorrow displayed nine unavailable 4 AM–10 PM windows and disabled Next. Screenshot `01-unapproved-no-capacity.png`. |
| Availability after approval/Online | PASS: all nine windows became selectable. Original **Any time of the day** control remained present and selected all-day in the review summary. Screenshot `04-all-day-capacity.png`. |
| Customer booking wizard | PASS to checkout: vehicle, wet wash, valid plate, optional-photo skip confirmation, manual society, tower/floor/parking, note, all-day time and ₹149 review. Persisted parking was recovered after reopening the app. |
| Razorpay TEST checkout | PASS launch: server-created TEST order opened the real provider checkout, with UPI/debit/netbanking group. Closing it kept one unpaid booking; retry reused the same booking. Screenshot `05-razorpay-test-checkout.png`. |
| Actual provider capture / refund | BLOCKED: UPI exposed QR only; mock netbanking stalled without an accessible mock-bank window in the connected browser. Cancelled that sandbox attempt. No real charge or successful provider capture/refund is claimed. |
| Assignment | PASS after explicitly simulated **local-only** capture: Captain received the real Firestore offer, accepted through the app, and Customer displayed that assigned Captain. Exact parking appeared only after assignment. Screenshot `06-customer-assigned.png`. |
| Offer expiry | PASS: expired offer disabled Accept. For the longer manual workflow only, local TTL was extended to 600 seconds and the local expired offer renewed. Production TTL was not changed. |
| Captain arrival / fresh selfie UI | Arrival opened the original Quick check screen. The actual web camera-picker selected the public face fixture, but the request hit local worker startup timeouts. This is not a physical camera or completed browser identity pass. |
| Authenticated wash workflow | PASS via actual callable HTTP and authenticated private Storage on the same browser-booked/assigned order: fresh five-minute identity session, real local OpenCV face comparison, Customer denied access to the identity capture, four before + four after uploads, wash start, synthetic location and photosReady. |
| Photo review outage handling | PASS via HTTP: with no live AI model configured, review returned unavailable; finish was denied until the existing explicit acknowledgement was supplied. No fake AI or identity success was used. |
| Customer approval / rating / receipt | PASS via authenticated HTTP: Captain self-approval denied; Customer approved and rated five stars; earnings became approved; PDF receipt downloaded once and a second use returned 403. This was not a manual Customer approval-button pass. |
| Captain earnings UI | PASS: browser Money screen updated to ₹116 Approved / ₹0 Waiting and stated payouts are confirmed separately. Screenshot `07-captain-approved-earnings.png`. No transfer or bank payout was made. |

The simulated capture was applied only after the provider test was blocked. It
does not establish Razorpay acceptance. The disposable assigned booking's clock
was moved into the current session so arrival/wash could be tested immediately.
An initial test-fixture clock shift before claim correctly invalidated the old
offer; the original window was restored, the offer renewed, claim completed, and
only then the assigned fixture window was shifted. Client/server gates were not
relaxed to accommodate this fixture.

Later browser reconnection also prevented the automation from committing text in
the Customer phone field, despite its earlier successful signup/booking checks;
the later Customer approval/photo screens were therefore checked through HTTP,
not claimed as manually completed. The phone-form implementation was not changed
on that evidence alone. Recheck the ordinary phone/keyboard path during native
acceptance. The eight-upload and identity assertions initially completed before
an extra copied harness block caused a cleanup error; that local harness was
corrected and a separate clean verification/approval/receipt run exited 0.
Safe workflow results are in
`output/web-acceptance-2026-10-29/http-workflow-results.json`. No tokens, signed
URLs, merchant secrets or actual identity images are included in the report.

## Corrections from this check

1. Callable startup timeouts now show a readable retry instruction instead of
   `deadline-exceeded`; specific server validation messages remain intact.
2. The existing Customer payment-failure screen now keeps the actual error in its
   existing message area. It no longer invents a bank decline or asserts that no
   money was taken when an unrelated backend/checkout operation failed. Retry and
   Change method stay in their authored positions. Sample-gallery text remains
   unchanged, so the pinned design fixture is preserved.

## Final source checks

- **48 Flutter tests passed:** 18 Customer, 9 Captain and 21 shared Firebase.
  This includes actual checkout-error text, registration retry, hidden training,
  availability, upload cancellation/errors and preserving server offer-expiry text.
- All four Flutter analyses passed. Both production release web builds passed
  after the final timeout-message guard, including required plugin registrants.
  Emulator output was never copied to the production output or deployed.
- `dart run apps/flutter/tool/ios.dart check all` passed the two native source
  configurations. This is not Xcode compilation, signing or iPhone acceptance.
- The earlier 157-state design guard remains the reference evidence; it was not
  rerun as a new whole-app pixel audit for this error-message-only change.
  Shared design components, fonts/assets and screen structures were untouched.
- No Hosting/Functions publication or production payment-mode change was made by
  this check. Aman must rebuild the installed apps from the pushed source.

## iPhone / merchant acceptance

Aman should pull the latest staging commit, rebuild both Flutter iOS workspaces,
and follow `AMAN-CLAUDE-TEST-FLOW-2026-10-28.md` and its existing PDF. The order of
roles is unchanged: Captain signup/upload -> private admin review -> approved
Captain Online/hours -> Customer booking/payment -> Captain job/wash -> Customer
photos/approval -> Captain earnings.

Physical camera/library permissions, fresh selfie, microphone/media, real GPS,
APNs/background/app-switch behaviour, Xcode compilation/signing and an actual
WashKrew live payment/refund remain separate device/merchant acceptance. The web
picker and simulated local capture cannot replace these checks. Deferred business
integrations and Aman's approved legal/support inputs remain as documented.
