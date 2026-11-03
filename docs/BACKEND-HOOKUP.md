# Current backend hookup rules - 3 November 2026

Read this before connecting another service. WashKrew uses the existing Firebase
project **wheelio-apps**, current Cloud Functions/Firestore/Storage, Google Maps,
the separate WashKrew Razorpay merchant, Firebase messaging and the private photo
service. Retired Supabase/Neon source was removed from the checkout; no actual
cloud database was migrated or deleted. Do not create another backend or bypass
current authorization to make sample screens appear to work.

## Current real integrations

Optional wash-photo AI now requires versioned Customer permission on the booking
and the assigned Captain's explicit per-check choice. Neither missing permission
nor a feature flag grants consent. No-permission paths do not read image bytes,
thumbnail or invoke Gemini; they record current-evidence `manualReview`, and the
normal Customer review/approval path remains usable. Clients probe the protocol
read-only before calling an AI action, protecting against an older backend.
See [the consent record](AI-PHOTO-CONSENT-2026-11-03.md). No new service or fake
approval was introduced; existing photo/identity/payment roles stay separate.

Deletion/login recovery now includes least-privilege conditional private-object
deletion, leased/retryable cleanup, scheduler recovery of existing server-marked
requests and fresh-auth re-registration. Public coarse discovery stays available
to guest/deleted-token sessions without allowing private writes. Role names and
state remain separate. Controlled SDK stream/cache/photo fixtures are in
`account_session_fixture.dart` and lifecycle tests only, never production accounts.
See [the lifecycle report](ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md).

- Authenticated phone ownership and server-enforced role access. Current-role
  deletion uses the existing `deleteOwnAccount` callable without an extra SMS.
  The server checks ownership, open jobs, pending payments and funded balance;
  cleanup is resumable/idempotent and the client requires completion evidence.
- Private document uploads and human Captain review at `/admin/`. Reviewer
  allowlist is server-enforced. No automatic identity/training approval.
- Saved map/radius Captain coverage, working periods, whole-window capacity and
  immediate coarse paid offers. First valid transactional claim wins. Precise
  booking details and photos stay private to authorized parties.
- Separate WashKrew LIVE Razorpay order verification/webhooks, wallet top-ups and
  atomic wallet spending/credit. No client can issue credit or trust its own paid
  flag. Direct credit cards, EMI and paylater remain excluded; linked-credit UPI
  remains allowed. Historical merchant/mode and cash-refund obligations persist.
- Server-snapshotted wallet cancellation rules, exact integer paise and current
  authenticated quotes. Service failures and human-upheld reports return full
  wallet value. Do not double-restore used credit on top of the awarded total.
- Private fresh selfie and Before/After photo checks. Advisory quality/face
  comparison does not replace human KYC or Customer approval. Captured evidence
  must upload/register before workflow transitions. Lost responses reconcile real
  server state instead of generating success or repeating inference blindly.
- Native camera/location/media and Firebase messaging. APNs registration waits
  briefly for readiness, is account-scoped and retries on app resume. Actual
  signed-device delivery remains a physical check, not a source-test claim.

## Samples, fixtures and paused controls

`WHEELIO_DEMO`/`?demo=true` explicitly select labelled in-memory reference stores.
Those retain sample people, OTPs, photo slots, offer timers and design galleries;
they must never send sample success into real controllers. Gallery controls,
`planClockTest`, timer shifts and sample notifications are design-only behavior.
No new production fake/timer/test button is introduced by the current cleanup or
deletion fix. Controlled tokens, delayed uploads, interrupted Storage cleanup,
old auth-time values, mock payments/photos and account switches occur only in
unit tests or guarded local `demo-wheelio` emulator fixtures. Owner-authorized
Firebase test-number configuration is documented separately; never seed invented
QA identities or fixed codes in production as an app shortcut.

Training/video/quiz/refresher code stays for an explicit future owner decision,
but the live UI and server flags keep it hidden/not required. DigiLocker,
WhatsApp Business, masked calling and voice OTP are deferred. Approved support,
legal and commercial content must come from Aman; do not invent it or mark a
placeholder complete. Payout transfers and dispute decisions are human operations.

## Operations and acceptance

Use [Firebase operations](FIREBASE-BOOKINGS.md),
[private photo service](../backend/photo-check/README.md),
[current status](STATUS.md), [current iPhone handoff](AMAN-IOS-HANDOFF-2026-11-02.md)
and [deletion evidence](ACCOUNT-DELETION-2026-11-03.md).
Keep organization policy and IAM-only private service access. Functions require
application Firebase authentication or the applicable verified webhook signature.
Minimum warm instances remain zero; no recurring warm-instance cost is approved.

No secret keys, auth tokens, private APNs/upload signing keys, KYC or private
credential PDFs belong in Git, client defines or shared acceptance reports.
