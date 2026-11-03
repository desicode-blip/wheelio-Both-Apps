# Optional Google AI wash-photo permission

Owner-approved UI exception on 3 November 2026: a short confirmation using the
existing Cupertino alert component. Existing Customer/Captain screen layouts,
assets, palette, typography and actions remain in place.

## What people see

Title: **Allow Google AI photo check?**

“Send this booking’s 4 after-wash vehicle photos to Google Vertex AI (Gemini)
for dirt/photo-quality suggestions? Plates and surroundings may be visible.
Aadhaar, selfies and bank details are excluded.

Optional: without AI, the Customer still reviews the photos. AI does not approve
washes or decide disputes.”

Choices: **Continue without AI** and **Allow AI check**. Neither closing the
dialog nor a missing answer means permission. New bookings never inherit the
previous booking’s choice.

The Customer chooses once before starting checkout for a new booking, whether
using Razorpay, wallet or a free wash. If that Customer permitted the AI check,
the assigned Captain chooses before checking after-wash photos. If Customer
permission is absent/declined, the Captain does not see a pointless permission
dialog for an unavailable AI check: photos go through manual Customer review.

Only four registered **after-wash vehicle images** are used by this AI path.
Private Aadhaar/selfie identity comparisons and payout/human KYC approval remain
separate existing operations. This is not an OTP verification or a bot check.

## Server protection

- `createBooking` / combined `createCheckout` snapshot the authenticated Customer
  choice, policy `vehicle-after-photos-v1` and server timestamp on the booking.
  Missing legacy-client permission defaults to not given. Malformed booleans or
  policy versions are rejected. An idempotent checkout retry cannot upgrade a
  previously declined/missing booking choice.
- `checkWashPhotos` requires both the saved Customer choice and the assigned
  Captain’s explicit versioned request before reading image bytes, generating
  thumbnails or calling Vertex AI/Gemini. Feature flags cannot grant consent.
  Unassigned users remain denied. Exact current evidence is fingerprint-bound.
- A missing/declined choice records honest `manualReview`, without an AI call or
  a claim that the photos passed. All normal identity, evidence, job-stage and
  ownership checks still apply. Finish moves the wash to `photosReady`; Customer
  approval, disputes and earnings follow their existing rules.
- A read-only protocol probe prevents updated clients from submitting a request
  to an older backend that would ignore consent fields. That probe cannot start
  an inference. Lost manual-review responses recover read-only without another
  AI call. Do not remove this protection to hide a server-update message.
- Existing/historical bookings without Customer permission use manual review.
  No old record is automatically relabelled as consented, and no production
  bookings/users/documents were created or approved as test fixtures.

## Rollout and verification

Source versions: **Customer 1.0.4 (7)** / **Captain 1.0.5 (8)**. These supersede
the earlier 6/7 production bundles. Android production builds retain the same
upload key, full ABI support and shrink settings. Mac signing/export instructions
are unchanged in `STORE-RELEASE-2026-11-03.md`.

Deploy `functions:wheelio:updateWashProgress` first so manual review remains
finishable, then the consent gates:

```sh
firebase deploy --only functions:wheelio:updateWashProgress --project wheelio-apps --account ajay@trustkeyper.com
firebase deploy --only functions:wheelio:createBooking,functions:wheelio:createCheckout,functions:wheelio:checkWashPhotos --project wheelio-apps --account ajay@trustkeyper.com
node backend/firebase/operations.cjs configure-api-access
```

No merchant, prices, cancellation rules, training or paid warm-instance minimum
is changed. Preserve existing organization policy and authenticated callable
authorization. Actual deployment/build verification is recorded in the final
release evidence; an unperformed Mac archive is never marked passed.

Tests cover both explicit UI choices, normal checkout with permission/refusal,
new-booking reset, Captain first-tap/duplicate protection, both-party server
gating, no image reads without permission, malformed/legacy/replayed requests,
retaken evidence, read-only recovery/old-server safety, and manual finish through
Customer approval/earnings. Store policy/provider/retention approval and actual
store-review access remain separate owner gates.

## Observed checks on 3 November

- Backend emulator suite: **204 passed**, including explicit opt-out/no image
  reads, version validation, idempotent consent snapshot and manual completion.
- Flutter suites: Customer **77**, Captain **40**, shared UI **11**, shared Firebase
  **56** passed (**184 total**); analysis passed for all four packages.
- Four Functions are deployed and ACTIVE with minimum instances **0**. The
  downloaded deployed source matches all four tested consent/service modules;
  unauthenticated calls return **401**. API gateway configuration completed.
- No real payment, real-photo AI request, real-person approval or production
  account seed was made by these automated checks.
- Physical native acceptance and App Store export remain Mac/device work. The
  existing-style dialogs and allow/decline paths have Flutter widget evidence;
  do not relabel that as a new physical iPhone pass.
