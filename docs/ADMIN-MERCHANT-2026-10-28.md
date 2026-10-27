# Captain approval and separate WashKrew payments — 28 October 2026

This update supersedes the merchant-integration and CLI-only Captain-review
status in earlier handoffs. Customer/Captain staging designs, Firebase project
`wheelio-apps`, bundle IDs and test payment mode are preserved. Android remains
deferred. No real Captain, live charge, live refund or bank payout was approved
or executed by this task.

## Published private operations page

https://wheelio-apps.web.app/admin/ is deployed with Google sign-in. The four
owner-approved reviewer emails are stored in the server-only
`privateConfig/captainReviewers` document, not the frontend. Phone OTP login
remains enabled for both apps. Admin uses a separate Firebase app/session so it
does not replace the Customer/Captain phone session.

Every list/detail/photo/decision request checks verified Google identity and the
current email allowlist. Decisions require Google authentication within 30
minutes. Unauthorized calls and private image downloads return 401/403. No
public signed KYC image URLs are generated. Storage still locks applicant uploads
while an application is under review. Images are read at their recorded object
generation, and all responses are private/no-store.

### How a Captain gets approved

1. The Captain completes the existing onboarding, supplies identity/selfie and
   payout details, requests service societies, and submits their application.
   Configured required training/quiz completion remains a server gate. Aman's
   design placeholders cannot satisfy it.
2. A reviewer signs in to the admin page, opens **Awaiting review**, and inspects
   private photos, payout information, requested societies and training status.
   Humans must verify identity, eligibility and payout details; a photo-quality
   result or entered UPI ID is not that verification.
3. For corrections, the reviewer selects Aadhaar/selfie/payout items, explains
   what is needed, and confirms. The Captain sees the actual note in their
   private inbox and returns to the existing onboarding screens. Corrected
   applications must be resubmitted and reviewed again.
4. For approval, the reviewer confirms identity/payout review, selects active
   societies requested by that Captain, writes a note, and confirms the decision.
   Missing uploads/accounts, stale/concurrent decisions, self-review, another
   payment mode and required unfinished training are rejected by the server.
5. Approval records reviewer, note, societies and history, and notifies the
   Captain. It leaves them **offline**. Going online remains the Captain's action;
   work restrictions, working periods, society/area, mode, freshness and atomic
   assignment still determine availability.

The existing Captain app now handles the account-review notification and its
specific correction items. Old `submittedAt` no longer keeps a corrected
application stuck in the waiting popup. No Customer/Captain layout, palette,
typography, logo, component or test-payment banner was changed.

The owner confirmed **Review applications** is visible in another Chrome profile.
A server-side Auth lookup independently verified a recent verified Google login
for an approved reviewer. This is owner-observed production acceptance; the
connected Sumit profile was not used to inspect real KYC or approve a real person.

## Separate merchant connection

The new WashKrew Razorpay merchant dashboard showed `https://washkrew.com/`
approved. The owner's downloaded live API pair authenticated successfully with
a read-only provider request and was saved directly to separate Secret Manager
secrets:

- `WASHKREW_RAZORPAY_LIVE_KEY_ID`
- `WASHKREW_RAZORPAY_LIVE_KEY_SECRET`
- `WASHKREW_RAZORPAY_LIVE_WEBHOOK_SECRET`

No downloaded credentials or secret values were added to Git or chat. The new
enabled webhook, ID `Tt2icf9oS4qTj5`, points to
`https://asia-south1-wheelio-apps.cloudfunctions.net/washkrewRazorpayLiveWebhook`
and subscribes to `payment.captured`, `order.paid`, and `refund.processed`.
A signed no-op reached this endpoint successfully; an invalid signature was
rejected. This is endpoint/configuration verification, not a live payment event
or charge/refund acceptance.

Bookings, payment-order mappings and refund records retain `paymentMerchant`
alongside payment mode. Missing historical merchant values mean the old
Trustkeyper provider. Checkout verification, lost-callback recovery, capture and
refund retries use the saved merchant rather than today's configuration.
Cross-merchant callbacks are rejected. New live bookings/checkout cannot use the
old shared live merchant; historical reconciliation/refunds can still use it.
Neither old credentials nor old webhooks were replaced.

**The deployed configuration remains test mode with the archived old merchant's
test pair.** A separate WashKrew test pair was not supplied. Selecting
`paymentMerchant: washkrew` in test mode fails closed until that provider is
configured. The downloaded live pair is prepared for a later explicit cutover;
this update does not enable it for Customer charges.

## Checks and limits

- Full backend/rules/payment/notification suite: **107 passed**. After adding the
  missing-profile approval guard, the focused Captain review suite passed all
  **7** checks, including the added regression. The earlier full suite included
  the other six review checks. Merchant-specific historical refund routing and
  rejection of the retired shared merchant for new live bookings passed.
- Captain analysis and **4 Captain tests** passed. Both production Flutter web
  release builds passed, and the admin build is integrated into the normal
  Firebase builder. Earlier Customer/shared checks are recorded in
  `AVAILABILITY-2026-10-27.md`; they were not newly counted as a run here.
- Default Firebase Hosting and Functions are published; the separate marketing
  Hosting site was not overwritten. Existing organization policy remains intact;
  the documented HTTP gateway step was applied with application authorization
  and webhook signatures still enforced.
- Deployed Customer/Captain/admin routes return HTTP 200. Unauthenticated admin
  APIs/private photos and an unsigned new webhook return 401. Public catalog
  still reports `paymentMode: test`.
- Manual local browser checks: Customer and Captain phone OTP/profile login;
  submitted application/private evidence; specific corrections/history;
  correction inbox routing; resubmission using a clearly disposable local
  uploaded fixture; test approval/history; approval inbox routing; offline to
  Online; Customer capacity refreshing to all nine 4 AM–10 PM windows; existing
  all-day choice; vehicle, society, parking and final ₹149 review; server-created
  actual Razorpay TEST order and opening provider checkout.
- Chrome's extension disallowed the local selfie file upload. The fixture was
  uploaded/resubmitted through the emulator helper, not claimed as a successful
  browser camera/upload test. Razorpay's embedded TEST document remained paused
  by Browser Use with an empty iframe. The current browser attempt is **not** a
  successful payment/refund acceptance. Historical real test checkout/refunds on
  21–22 October remain recorded in `WEB-ACCEPTANCE.md`.
- The separate authenticated local HTTP integration also **passed**: booking,
  atomic assignment, arrival, real local reference-face comparison, protected
  identity capture, eight decoded evidence uploads, wash status, stored synthetic
  foreground coordinates, explicit AI-outage acknowledgement, Customer
  approval/rating, approved earnings and a single-use PDF receipt. This harness
  deliberately simulates payment capture, seeds a disposable approved Captain
  and moves its local booking into the current time window. It is not a real
  checkout, physical GPS/camera, training/KYC acceptance or live-merchant test.

## Remaining before live operation

1. Complete native compilation/signing and two-role physical iPhone acceptance:
   camera allow/deny/re-enable, media, real SMS, foreground location/ETA, payment
   app switching, wash evidence, customer review/refund and APNs delivery. Windows
   source/build checks do not establish these results.
2. Finish explicit new-merchant acceptance, including actual deployed app-origin
   approval as required by Razorpay, new-merchant test access if test checkout is
   required, and a separately authorized live checkout/refund after operational
   settings and approved real Captains are ready. Do not switch mode as part of a
   code pull or Mac build.
3. Obtain Aman's approved legal/support/policy content and training material or
   approved placeholders. Placeholders grant no server training/quiz/KYC result.
4. Confirm commercial terms, actual service coverage and human eligibility/payout
   review. Automatic bank transfers, KYC and dispute decisions remain human
   operations. DigiLocker, WhatsApp Business and masked-call accounts remain
   explicitly deferred by the owner.

See `apps/admin/README.md` for reviewer operations and owner configuration, and
`docs/MAC-HANDOFF.md` for Mac/device instructions. Keep using latest staging and
preserve Aman's design. This task commits locally; it does not push to GitHub.
