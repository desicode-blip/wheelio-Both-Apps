# Current AI wash-photo toggle and direct send

Latest owner decision, 3 November 2026. This replaces the earlier same-day
consent popups. Customer **1.0.4 (8)** / Captain **1.0.5 (9)** preserve the
authored app screens, adding only the explicitly requested toggle/card/actions.

## Customer

Checkout opens normally without an AI dialog. New bookings start **OFF**, even
if an older app sends its former checkout consent fields. After a captured
Razorpay/wallet/free-wash payment, the existing success screen shows **AI wash
photo check**. The same control stays accessible in booked/searching/on-the-way/
washing tracking until the Captain sends the photos.

The text beside the switch explains that turning it ON permits this booking’s
four after-wash vehicle images to be sent to Google Vertex AI/Gemini, that plates
and surroundings may be visible, and that Aadhaar/selfies/bank details are excluded.
It is an explicit optional opt-in, without a separate popup or preselected ON.
The app waits for a server-confirmed change; an error does not grant permission.
Orders/preference revisions stream to both roles and survive reopening.

## Captain

- Customer OFF: **Send photos**, which uploads/validates existing evidence and
  submits it directly to Customer review. No Gemini call or AI-status polling.
- Customer ON: **Check with AI** and **Send without AI**. The second action uses
  the same direct submission, regardless of the Customer’s enabled option.
- Existing AI warnings/outages retain a send-as-is path. They do not force a
  paid recheck. Four actual registered photos, assignment, identity and job-stage
  checks still apply. The Customer makes the normal approval/dispute decision;
  earnings remain awaiting approval until that decision.

The shared alert function and its tests were removed. Other layouts, assets,
fonts and colors are preserved; the switch uses the existing WToggleRow/WCard,
and Captain actions use existing buttons at Captain size.

## Backend and concurrency

`setBookingPhotoAi` is an authenticated Customer-only controller. It verifies
booking ownership, captured payment and a pre-submission stage. OFF always wins
over an older state; stale/replayed ON requests are rejected using the current
revision. Repeated identical choices are idempotent. Terminal/unpaid/unrelated
bookings cannot be edited. Removed-role protection applies to this controller.

Protocol `vehicle-after-photos-toggle-v2` binds an AI attempt to the current
Customer preference revision, assigned Captain and exact four-photo fingerprint.
Permission is checked before image reads, thumbnail work and immediately before
model dispatch. Changing the toggle clears the old lease/results. An OFF change
before dispatch prevents it; an OFF after dispatch discards the result. A request
already sent cannot be recalled and may still be charged; the UI explains this
when applicable. An OFF/ON cycle cannot make an old result valid again.

Direct send completes in the normal finish transaction with honest manualReview
and no AI inference. It is not fabricated wash approval. Current registered
evidence is checked again before finishing. Older clients remain safe: their
former popup choice cannot enable the new toggle, and they can finish manually.
New AI clients probe protocol read-only before sending through an older backend.

Identical checked photos reuse their current result. A maximum of five AI
attempts per booking per 30 minutes survives preference changes/retakes; toggling
cannot reset that budget. Send without AI remains available at that limit.

## Billing

The configured model was read back as **gemini-3.5-flash**, enabled. AI runs add
token-based model charges plus server/thumbnail processing. OFF/direct-send paths
do not invoke Gemini. Normal booking, image storage and evidence-validation costs
still exist. No warm-instance minimum or new fixed monthly service was enabled.

Google’s standard global list prices checked on 3 November 2026 are **US$1.50
per million input tokens** (including images) and **US$9 per million output tokens**
(response/reasoning). An actual per-wash cost depends on its token usage and
rechecks; this is not a fixed fee or an estimate of the merchant’s invoice.
Current source: [Google Cloud model pricing](https://cloud.google.com/model-garden/pricing).
Provider usage counts/model are logged after successful responses without photos,
plates, addresses, UID or booking ID. Use actual usage and billing SKUs/taxes for
cost reports; do not infer a rupee price from an image count alone.

## Deployment and acceptance

Deploy updateWashProgress first, then createBooking/createCheckout/checkWashPhotos/
setBookingPhotoAi using `functions:wheelio:FUNCTION_NAME` filters. Run the existing
`node backend/firebase/operations.cjs configure-api-access` afterward. Preserve
organization policy, role authentication and minInstances 0. No merchant,
cancellation, KYC, training or payout rule changes are part of this feature.

Tests cover post-payment visibility, server-confirmed ON/OFF/error states, no
checkout popup, Captain AI/direct actions and cold job resume; backend tests cover
ownership/payment/stage gates, stale ON requests, OFF-before/after-dispatch,
OFF/ON during inference, cache/rate limits and direct completion through Customer
approval/earnings. See the current release receipt for actual deployment/build
results. Physical iPhone/Xcode output remains a Mac check.

## Verified software/deployment evidence

The final emulator suite passed **208** tests. Flutter suites passed **184**
(Customer 79, Captain 40, shared UI 9, shared Firebase 56), and all four package
analyses passed. The old popup tests were removed; normal direct-checkout tests
are restored. Both Captain buttons and the post-payment toggle are covered.

Five deployed Functions are ACTIVE with minInstances **0**, and unauthenticated
requests return **401**. Downloaded deployed source matches all six tested
toggle/photo/service/authorization modules. Firebase CLI's new-function invoker
setup reported an organization-policy error; the existing documented HTTP gateway
configuration resolved access while preserving organization policy and app
authentication. No real-user account, payment, wash evidence or Gemini inference
was created as an automated test. New Android artifact checks are recorded in
the current release receipt; no physical iPhone pass is implied.
