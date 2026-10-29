# Admin, Customer and Captain acceptance — 29 October 2026

This follow-up completes the browser wash/approval steps that were HTTP-only in
[WEB-ACCEPTANCE-2026-10-29.md](WEB-ACCEPTANCE-2026-10-29.md). Source tested:
staging `696c5b4` plus the live-message corrections in this report's commit.
The role sequence and af036f0 design remain unchanged, including the approved
W05 document-upload exception. Training remains hidden; human approval is required.

## What was manually checked

The actual Flutter Firebase controllers ran on separate local Customer and Captain
origins with Auth, Firestore, Storage and Functions emulators in **demo-wheelio**.
The private admin page used its real review controls and server authorization.
All people, phone numbers, addresses and documents were disposable QA fixtures.
No real applicant was approved or production booking/account created.

| Step | Observed result |
| --- | --- |
| Customer account | PASS: phone-code request/verification and name entry through the app. The later automation input issue was resolved by focusing the Flutter field, observing its rebuilt accessibility node, then setting its value; no phone-form code was changed. |
| Captain account and application | PASS before the pause: separate phone login, upload-only Aadhaar action, camera/gallery/cancel sheet, cancel without KYC progress, private image upload, selfie, payout, submission and work-hours editor. No DigiLocker or training route. |
| Before approval | PASS: Captain was under review/offline and Customer had no selectable capacity. `01-unapproved-no-slots.png`, `02-captain-under-review.png`. |
| Admin receives the request | PASS: submitted application appeared under Awaiting review. Opened private evidence, reviewed payout, selected requested service society and used the explicit approval confirmation. `03-admin-request-received.png`, `04-admin-approved.png`. |
| Approval permits work | PASS: server saved one audited `approve` review; Captain approval arrived in the app and the Captain could go Online. Existing 4 AM–10 PM working hours and society eligibility exposed Customer capacity. `05-approved-captain-online.png`, `06-approved-available-slots.png`. |
| Customer time selection | PASS: Tomorrow exposed all nine 4 AM–10 PM windows and the original all-day option. The final wash used **Today, 10 AM–12 PM**, while that actual window was open. No clock shift or offer-deadline extension was used for this run. |
| Booking inputs | PASS: hatchback/wet wash, valid plate, four optional Customer photos, society, tower/floor/parking and text note reached the booking and assigned Captain. |
| Provider checkout | PASS launch only: a server-created Razorpay TEST checkout opened, with UPI/debit/netbanking and no direct credit-card option. Closing checkout retained the unpaid booking. `07-test-checkout.png`. **Capture was then explicitly simulated locally**; no real provider payment occurred. |
| Assignment and acceptance | PASS: real Firestore offer accepted within its original 60 seconds; Customer's Check again resolved the same booking and showed the assigned Captain. Exact parking and Customer photos were available after assignment. `08-customer-assigned.png`, `09-captain-owner-photo.png`. |
| Arrival and identity | PASS: Captain arrival opened Quick check; the web picker supplied a public face fixture in a fresh identity session. The real local OpenCV quality/face comparison passed and unlocked before-photos. This is not a native iPhone camera or a human identity decision. `10-identity-passed-before-locked.png`. |
| Photo failure and retake | PASS: a deliberately dark photo was rejected; Take again accepted a valid fixture. Next stayed disabled until all four before-photos were saved. `11-dark-photo-rejected.png`, `12-four-before-photos.png`. |
| Wash and live tracking | PASS: starting the wash changed the Customer screen to Cleaning with the same booking's start time and four before-photos. Captain Water/Wipe/Dry controls led to after-photos. `13-customer-washing.png`. This checks realtime job state, not a real GPS journey. |
| After-photos and unavailable AI | PASS: four actual uploads enabled Check photos. With no external AI model configured, the existing explicit warning appeared; Captain chose “It’s clean, send anyway.” The server recorded acknowledgement and sent photos for **Customer review**, without automatic approval. `14-four-after-photos.png`, `15-photo-review-unavailable-warning.png`. |
| Customer review | PASS: Customer received photosReady, opened all four before/after angles and used the gallery's Approve action. Captain first showed Waiting for owner. `16-customer-review-ready.png`, `17-customer-before-after-gallery.png`, `18-captain-waiting-for-owner.png`. |
| Approval and rating | PASS: approval opened the existing rating screen; five stars with Spotless/On time were submitted and persisted. Customer history showed Done and “you rated 5.” `19-customer-approved-rating.png`, `22-customer-rated-booking-history.png`. |
| Captain completed job and earnings | PASS: Jobs showed the same plate Done. Money showed **₹116 Approved / ₹0 Waiting**. Read-back confirmed an approved, **unpaid** earning, not a transfer. `20-captain-approved-earning.png`, `21-captain-completed-job.png`. |
| Receipt control | The Customer clicked Download receipt. Server read-back confirmed a one-time document request was consumed. The connected browser did not return a download artifact/event, so final browser file delivery is **unverified**. Receipt PDF generation/access/one-time expiry passed backend tests; do not label this a completed native download test. |

Screenshots and safe final state: [output/full-flow-2026-10-29](../output/full-flow-2026-10-29/).
The final local order is `74629b3cd333ba1dbbe1458c22d131d5`: approved, TEST,
four Customer photos, four before/four after, verified fresh identity session,
five-star rating, and an approved ₹116 earning with no paidAt.

## Fixture boundaries and interruption recovery

The pause stopped the initial local services after browser onboarding. The same
pending application, public fixture uploads and previously UI-verified work hours
were reconstructed through the local service; **approval was not seeded**.
Actual admin approval and all booking-through-rating actions above then used UI.
This was not one uninterrupted fresh-signup-to-completion browser session.

The in-app browser could not complete an Auth-emulator Google popup. An ignored,
guarded **QA build only** used Firebase's official redirect SDK on matching
`127.0.0.1` origins. The local Google-emulator reviewer was `reviewer@example.test`.
The original review controls, version checks, service and reviewer enforcement
were retained. No custom token, direct database approval or production reviewer
change was used. Production admin popup authentication was not retested by this
adapter; the owner previously confirmed actual reviewer access. The adapter is
absent from source and production builds.

Public/synthetic photo fixtures were used, including a public astronaut face for
local comparison. They never establish real KYC. A black fixture tests rejection;
the real local quality/face models perform the checks. AI-review outage is
intentional. Live/maps credentials were disabled in the runner; only archived
TEST checkout credentials were available. Ignored emulator checkpoints preserved
the local session. No QA fixture, override, token or KYC file belongs in Git.

## Corrections found during the walkthrough

- Real booking confirmation no longer says a WhatsApp message was sent. Its
  existing action explains that messaging is not connected instead of opening a
  sample conversation. Deferred WhatsApp integration was not invented.
- The existing confirmation banner shows an already-assigned Captain rather than
  continuing to say “finding a captain.”
- Real Customer review/rating/approved notifications identify approval of the
  Customer payment; they do not claim that the whole ₹149 became a ₹149 bank
  transfer to a Captain whose configured earning is ₹116.
- Real Captain completion copy says payouts are confirmed separately, matching
  the existing Money screen. It does not promise an automatic midnight transfer.

These are actual-state text/handler corrections inside existing regions. Sample
gallery wording and authored layout/components/assets/fonts/palette remain pinned.
Screenshots 18/19 precede the text correction and intentionally document the issue.
No payment routing, rates, KYC policy, native project or provider setting changed.

## Automated verification

- **121 backend/rules tests passed**, zero failures/skips: full Auth/Firestore/
  Storage emulator suite. Includes unauthorized/self/stale review rejection,
  approval/Online eligibility, real work-period capacity, atomic claim conflicts,
  test/live isolation, payment signatures and duplicate callbacks, unsupported
  funding, original-merchant refund/reconciliation, private evidence and identity,
  required photo/AI-outage acknowledgement, approval/rating, receipts and deletion.
- **52 Flutter tests passed**: 21 Customer, 10 Captain, 21 shared Firebase.
  New coverage prevents a real confirmation from opening sample WhatsApp, checks
  actual assignment/payment/payout wording, and retains disconnected design copy.
- All four Flutter analyses passed with no issues. Both final production release
  web builds passed, including required plugin registrants/admin packaging. The
  QA emulator output was never copied to the production build or published.
- Portable iOS source and tooling checks passed for both apps: arguments, device
  selection, dependency completeness and retained native configuration. This is
  not Xcode compilation, signing or physical acceptance.
- The full **157-state pixel audit passed**: 156 pixel-exact to af036f0, W05
  pixel-exact to the owner's approved upload-only snapshot, zero capture errors,
  zero unreviewed differences. Results:
  [FULL-WORKFLOW-DESIGN-RESULTS-2026-10-29.json](FULL-WORKFLOW-DESIGN-RESULTS-2026-10-29.json).
  This covers the same authored English fixture states/viewport, not every real
  data/language/device combination.

No production publication or payment-mode change was made by this acceptance run.
Local QA services were stopped and the temporary ignored test credential override
was removed after testing.

## Remaining device and merchant acceptance

Use [AMAN-CLAUDE-TEST-FLOW-2026-10-28.md](AMAN-CLAUDE-TEST-FLOW-2026-10-28.md)
and the existing acceptance PDF when rebuilding both current Flutter workspaces.
The role order is Captain signup/upload -> authorized private admin approval ->
Captain Online/coverage/hours -> Customer booking/payment -> Captain arrival/
selfie/before/wash/after -> Customer approval/rating -> Captain earnings.

Still required: actual Xcode compilation/signing and physical iPhone camera/Photos,
permissions, GPS/background/APNs/app switching, UPI handoff and receipt delivery;
an authorized actual **WashKrew live charge and original-merchant refund**; and
human operational payout/support/dispute handling. The local capture proves none
of those merchant actions. Production remains on the separate WashKrew LIVE
merchant with direct credit-card checkout excluded. Aman's approved legal/support
inputs and explicitly deferred integrations remain pending as previously agreed.
