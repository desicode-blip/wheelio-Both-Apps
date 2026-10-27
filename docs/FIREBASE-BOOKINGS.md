# Firebase booking release — 21 October 2026

## Current follow-up — 27 October

Use [READINESS-2026-10-27.md](READINESS-2026-10-27.md) for current Maps/Routes, training/quiz/speech, private photo checks and content/provider gates; historical descriptions below predate those additions and staging's removal of the payment banner. Payment mode still comes from the server and remains **test**. Client Maps keys are restricted public configuration; Routes uses `GOOGLE_MAPS_SERVER_KEY`. The [private photo service](../backend/photo-check/README.md) uses IAM-only runtime access and separate server configuration.

After deployment, keep the domain-policy-compatible API gateway step and configure the deletion function's narrow Auth permission:

```sh
node backend/firebase/operations.cjs configure-api-access
node backend/firebase/operations.cjs configure-account-deletion
```

The deletion action inspects the deployed function's actual runtime identity and binds a custom role containing only `firebaseauth.users.delete`. It does not delete an account. Both steps were applied in this release. No organization sharing restriction was disabled.

The web implementation uses the existing Flutter phone layouts and shared WashKrew design system. Customer booking screens retain their vehicle, wash, parking, slot, phone, review and checkout steps. Live booking details and Captain controllers use Firestore snapshots instead of the demo stores. `?demo=true` remains isolated and visibly labelled.

## Account and payment setup

- Project: `wheelio-apps`, Mumbai, owner `ajay@trustkeyper.com`.
- Billing is linked to the active billing account used by `trustkeyper`, as the owner requested.
- Firebase Phone Authentication is enabled, with SMS delivery restricted to India. No fixed production OTP or production test-number bypass is configured.
- Default Storage bucket: `wheelio-apps.firebasestorage.app`, Mumbai.
- Trustkeyper's stored Razorpay credentials were **test** credentials. Their values were copied directly in memory into WashKrew Secret Manager secrets `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`. No secret belongs in Flutter, defines JSON, Git, browser logs or chat.
- A read-only Razorpay API check authenticated these test credentials successfully. On 22 October, the connected Sumit Chrome profile opened the existing Paravent merchant; its existing test key matched WashKrew's configuration. WashKrew's separate test webhook was registered while preserving Trustkeyper's endpoint. The owner will supply live credentials after Aman's onboarding; no live credential was generated or substituted.
- The app displays a persistent test-payment label unless the server config says `paymentMode: live`. Checkout also compares the configured mode with the actual Razorpay key prefix. Test and live captain pools are separate.
- `operations.test.json` carries the prices already in the repository: ₹69/₹149/₹179/₹219; Captain amounts ₹54/₹116/₹140/₹140. These are editable **test** settings, not newly approved live commercial terms. No cancellation fee has been introduced. The societies come from the existing Customer catalog. Live commercial settings still need owner review before changing mode.

## Booking lifecycle

1. Customer verifies a real Firebase phone account and saves a name. Current prices and society choices come from `config/operations`.
2. Public coarse availability reports only time windows with approved captain capacity. The server rechecks capacity when preparing a booking and when receiving capture. Customer-supplied amounts are ignored. One outstanding unpaid booking per customer and a deterministic request ID prevent accidental duplicate checkout.
3. A Cloud Function creates a Razorpay order, returns only the public checkout key, and verifies the signed result plus the payment fetched from Razorpay. Only `captured` payments dispatch jobs. Pending, failed or cancelled checkout never becomes a confirmed booking locally.
4. Eligible approved, online captains receive coarse offers with a server expiry. Offers hide the vehicle plate, exact parking and owner note. A transaction assigns one captain and withdraws the remaining offers. It prevents self-claims and overlapping assigned jobs. Online heartbeat expiry prevents dispatch to abandoned browser sessions.
5. The assigned captain sees the actual booking, records arrival, uploads four before photos, starts washing, uploads four after photos, and submits the wash. The server enforces every transition and verifies uploaded objects. There is no simulated AI result or face check.
6. Optional captain location sharing updates the assigned booking every 15 seconds while its page remains open. Customers see the last update time and can open those coordinates in Google Maps. Location is private to the two booking parties. There is no invented ETA, drawn live map or background location claim.
7. Customer reviews the protected before/after photos, approves the work and rates once. Captain earnings move from `awaitingApproval` to `approved`. Reporting a problem creates a support ticket and holds earnings for an actual operator decision.
8. Customer cancellation before washing queues a provider refund where money was captured. Duplicate capture/cancel/refund processing is idempotent. Late capture after cancellation or expiry is refunded. The scheduler reconciles missing checkout callbacks, refund statuses and expired unstarted jobs. No local timer marks a wash paid or approved.

Refund recovery preserves the full configured amount and the original idempotency key. Before retrying a missing refund ID, the worker searches provider refunds for the same receipt/note. A leased transaction and processed-state guard prevent a stale worker or delayed webhook from reversing completion. Provider rejections persist bounded HTTP/code diagnostics and retry from five minutes up to one hour; failed/mismatched results require operations review. Customer sees queued, sent, delayed, review or processed copy and can check an existing refund through the owner-authorized `checkPayment` callable. That read-only status action cannot create a refund or bypass POST backoff. Provider error descriptions/payloads are never exposed.

Razorpay captures money into the merchant payment flow. Customer approval approves the Captain earnings ledger; it does not magically create an escrow account or send a bank payout. There are no fabricated bank transfers, refund deadlines, automatic KYC decisions, midnight approvals or dispute outcomes.

## Captain operations

Captains verify their phone and submit identity, selfie, bank proof, payout UPI and requested societies. Documents stay private and lock after submission. New captains remain unapproved. No production captains are seeded to make capacity appear available.

Use Firebase Console with the owner IAM account to review the submitted documents. Then explicitly approve the actual captain for requested societies:

```sh
node backend/firebase/operations.cjs approve-captain FIREBASE_UID soc_avatar
```

This local tool uses the owner's existing Firebase CLI login in memory. It has no public admin endpoint and cannot be called with a customer ID token. Review decisions, payout execution and dispute resolutions remain human operations. Application submission alone does not authorize jobs.

To apply the repository's test catalog:

```sh
node backend/firebase/operations.cjs configure-test
```

## Deployment

```sh
npm ci --prefix backend/firebase/functions
node apps/flutter/tool/build-firebase.mjs
node backend/firebase/operations.cjs configure-storage
npx -y firebase-tools@latest deploy --only "functions,firestore,storage,hosting" --project wheelio-apps --account ajay@trustkeyper.com --force
node backend/firebase/operations.cjs configure-api-access
```

Set `FLUTTER_BIN` if needed. The build explicitly resolves dependencies for both app projects because the shared path package owns Firebase plugins. All callables are in `asia-south1`. Secrets bind only to functions that need the provider. `--force` accepts the retry policy on the idempotent refund trigger. On slow development machines set `FUNCTIONS_DISCOVERY_TIMEOUT=60` for source discovery.

The Storage setup merges browser GET/HEAD access for the two Hosting origins into the bucket CORS metadata, preserving existing policies with a metageneration precondition. Private photos use authenticated SDK downloads rather than public download-token URLs, following [Firebase's browser download guidance](https://firebase.google.com/docs/storage/web/download-files#cors_configuration). Storage rules still authorize each photo read.

The default Functions build/runtime identity has Firestore user and log writer roles on this project, object viewer on the Functions source bucket and WashKrew photo bucket, and Artifact Registry writer on the regional `gcf-artifacts` repository. Existing service-agent bindings were preserved; no broad Editor role was added to that identity. Functions use 256 MiB, fractional `gcf_gen1` CPU, concurrency 1, zero minimum instances and a maximum of five instances each. This avoids the new project's regional CPU limit hit during the initial 22-function rollout. See [Firebase resource settings](https://firebase.google.com/docs/functions/manage-functions#override-CPU).

Trustkeyper's domain-restricted sharing policy blocks `allUsers` IAM bindings. After every Functions deployment, `configure-api-access` sets Cloud Run's `invokerIamDisabled` on the explicitly listed app callables and signed test/live Razorpay webhooks only, using [Google's recommended public gateway configuration](https://cloud.google.com/run/docs/authenticating/public#disable). It does not change the organization policy or grant outsiders project IAM roles. The scheduler and Firestore event handlers remain restricted. Firebase ID tokens, verified phone identity, booking-party authorization and HMAC checks are enforced inside the app endpoints. Coarse availability is intentionally public.

The following separate WashKrew webhook is registered in the merchant's **test mode**, preserving Trustkeyper's existing endpoint. Keep it in test mode during live cutover:

`https://asia-south1-wheelio-apps.cloudfunctions.net/razorpayWebhook`

Events: `payment.captured`, `order.paid`, `refund.processed`. Use WashKrew's existing `RAZORPAY_WEBHOOK_SECRET` value. The endpoint verifies the HMAC over the original request bytes and independently fetches payments/refunds. Because the merchant is shared, unrelated provider orders are acknowledged without creating WashKrew records; owned payments still require the exact server amount/currency/order. Refund reconciliation also works when webhook delivery is delayed. Follow [Razorpay's checkout integration](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/integration-steps/) and [idempotent refund contract](https://github.com/razorpay/markdown-docs/blob/master/api/refunds/normal-refunds-idempotent.md).

### Payment-mode preparation — 24 October 2026

`node backend/firebase/operations.cjs prepare-payment-modes` authenticated the original test pair without creating a payment, then preserved it in `RAZORPAY_TEST_KEY_ID` and `RAZORPAY_TEST_KEY_SECRET`. It refuses to overwrite a different archived pair. On 25 October, the existing live pair recovered from an owner-provided document was matched to the selected merchant, authenticated read-only and installed as new versions of `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`. The seven payment functions were redeployed with those versions. Historical test callbacks, refunds and status checks continue using the archived test pair; the operations config remains `paymentMode: test`. Secrets moved directly in memory into Secret Manager, never source, Flutter or local JSON. The preparation command must run before replacing the original generic test pair on a new environment; do not rerun it against generic live credentials.

Live mode has its own endpoint, `https://asia-south1-wheelio-apps.cloudfunctions.net/razorpayLiveWebhook`, and signing secret `RAZORPAY_LIVE_WEBHOOK_SECRET`. With the owner's explicit confirmation, it was registered on 25 October as live webhook `Ts0o1UGO3CUsRm`, enabled for `payment.captured`, `order.paid` and `refund.processed`. Registering the notification endpoint does not switch checkout to live mode. Trustkeyper's webhook and shared API key were not changed or regenerated. Both endpoints reject cross-mode WashKrew events; unrelated merchant orders are ignored. `check-webhook` and `check-live-webhook` send signed no-op setup events plus invalid signatures, without creating bookings or payments.

Capacity uses each booking's mode, preserving historical test slot keys and a separate live namespace. Offers and earnings persist their mode. Historical test bookings and earnings retain their own test labels after the catalog switches; missing mode on legacy earnings is treated as test. Test wallets and test captains cannot supply live balances or live jobs. A status check refreshes the Customer order before routing; a late capture that cancels/refunds opens those details instead of a payment-pending loop.

The existing live credentials and live webhook are now connected. Production cutover still requires merchant website approval for WashKrew, reviewed commercial settings, actual approved live-mode captains, and real phone/checkout acceptance. The submitted Firebase website is under review (24–48 hours shown by Razorpay). Do not relabel a test payment as live or move test bookings to live mode. Native iPhone source setup is documented in [IOS-FIREBASE.md](IOS-FIREBASE.md); physical acceptance is pending the owner's Mac. No Android app was generated. See [LIVE-LAUNCH.md](LIVE-LAUNCH.md).

## Verification

Released on 21 October 2026: Hosting `/app/` and `/captain/`, all 22 active Functions, Firestore/Storage rules and indexes, bucket CORS and the required HTTP gateway settings. The reconciliation scheduler is enabled and its observed run succeeded. The test catalog is in `config/operations`; no production captains or bookings were fabricated.

All 27 Firestore/Auth/Storage and service emulator tests passed on Firebase CLI 15.34.0 with Java 26. Customer, Captain and shared Firebase analyses passed; both clean release web builds passed. Deployed checks rejected anonymous calls to all 17 protected app operations (401), returned public availability successfully (200 with six unavailable windows), accepted a correctly signed no-op webhook (200) and rejected an invalid signature (401). These checks made no charges or bookings.

The hosted browser test caught a stale Flutter web plugin registry: Functions calls fell into the native Pigeon codec and failed with `Int64 accessor not supported by dart2js` before making a request. The release builder now clears generated caches, resolves dependencies and checks that Functions, Storage and location web plugins are registered before packaging either app. A fresh hosted booking draft then called `getAvailability` successfully (200) and displayed the actual empty captain pool. Availability errors now have a retry action above the slot grid, and changing dates clears a previous error. Captain fields use visible hints when no separate placeholder is supplied.

On 21 October the owner confirmed receiving real SMS OTPs and supplied a hosted Customer screenshot showing the post-verification "What should we call you?" screen. At the owner's request, the existing name entry was submitted in their Sumit Chrome profile. The app returned to the booking screen, and the Profile page showed the saved name and Sign out action, confirming account completion. No phone number or OTP is recorded here.

On 22 October, test-payment web acceptance and refund recovery were completed; see [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md) for actual checkout/refund results, local replay boundaries, private photo review, approval/rating, earnings, dispute holds and recovery checks. All 39 backend/rules/payment-adapter tests and 4 Customer tests passed. Both actual card and netbanking test refunds processed. The generic HTTP 400 rejection stopped after a separate ₹100 virtual test payment added merchant balance; the original full ₹149 refund and idempotency key were preserved. Hosting and the changed payment/refund Functions deployed with gateway/auth/signature checks passing. Physical GPS permission/accuracy remains a device acceptance check. Aman is completing merchant onboarding; the owner will obtain live credentials afterward. Payments stay visibly in test mode. Actual captains must submit documents and receive an operator review before capacity opens; live credentials, reviewed commercial settings and approved live-mode captains are required for live cutover. Native platform work remains deferred.

```sh
npm ci --prefix backend/firebase
npm ci --prefix backend/firebase/functions
npx -y firebase-tools@latest emulators:exec --project demo-wheelio --only "firestore,auth,storage" "npm --prefix backend/firebase test"
```

Use Java 21+. `rules.test.mjs` covers the earlier private request portal. `access.test.mjs` attacks booking/earnings/KYC privilege changes, cross-customer reads, offer privacy, tracking access, wrong photo stages, oversized/non-image uploads and KYC document locking. `service.test.mjs` uses a dependency-injected provider against the Firestore emulator: server pricing, phone identity, invalid HMAC/callbacks, capture amounts, concurrent claims, offer expiry, online/mode isolation, overlapping slots, required evidence, customer-only approval, one rating, capacity release, duplicate refunds, late captures and reconciliation. No provider charges occur in automated tests.

The source rules audit is recorded in `rules-audit.json`. Storage rules limit each object to 8 MB and a fixed path namespace; only booking parties can download wash photos. Transactions and server-owned collections protect business transitions. Browser MIME metadata does not prove image content or photo authenticity; this release does not claim automated fraud detection.

Unconnected auxiliary demo features remain available only in the explicit demo: recorded voice/video notes, FCM delivery, in-app map tiles, automated training/AI checks, masked calls, promotional credits, phone changes, account deletion and automated bank payouts. Live navigation does not claim those actions succeeded. Text entry notes, photo uploads, foreground snapshots and explicit location sharing work independently of them.
