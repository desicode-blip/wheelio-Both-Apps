# Current Firebase backend and operations - 3 November 2026

Project **wheelio-apps**, owner **ajay@trustkeyper.com**, region **asia-south1**.
Current app source is Flutter Customer/Captain; shared backend integration is in
`apps/flutter/packages/washkrew_firebase`. Native Firebase public configuration
is committed in each platform project; no server credential is needed to build.

## Source and configuration

- `backend/firebase/functions/src/`: current authenticated callables, webhook,
  scheduled reconciliation, booking/capacity/wallet policies and private services.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`: client ownership,
  private evidence, indexes and place-search TTL configuration.
- `operations.cjs`, `operator.cjs`: owner-only narrowly scoped configuration and
  human operations. Read the relevant command before running it. Do not run
  `configure-test`, sample approval or mode switches against production casually.
- `config/operations`: current catalog, availability/training/payment policy.
  Provider secrets/private service settings remain server-only.
- `operations.example.json` / `operations.test.json`: configuration templates for
  deliberate setup/local tests, not permission to overwrite deployed settings.

Normal builds use the separate WashKrew **LIVE** merchant, with supported UPI,
debit, netbanking and provider wallets and no direct credit cards/EMI/paylater.
Existing merchant/mode references and refund obligations stay on their records.
New cancellations use walletByTime; see
[the financial rules](WALLET-CANCELLATION-2026-10-31.md).
Only provider-verified capture can credit a wallet or dispatch paid work.

## Booking and work lifecycle

1. Firebase verifies the phone and the server registers the chosen app role.
2. Captain uploads private Aadhaar/selfie/payout information, chooses coverage
   centre/radius and work periods, and submits for human review. Training is hidden.
3. An authorized reviewer at **https://wheelio-apps.web.app/admin/** approves or
   requests corrections. No manual society assignment is needed for current area
   bookings. Approval does not bypass hours, coverage, capacity or Online.
4. Customer confirms a real home/parking location. The entire selected window
   must fit a covering eligible Captain's continuous working period. Availability
   and payment capacity use the same rule across homes within overlapping areas.
5. An authenticated deterministic checkout request prepares an order. Server
   verification plus captured provider payment (or atomic full-wallet spend)
   confirms it. Failed/pending local callbacks are not payment success.
6. Eligible Online Captains receive coarse offers together. An atomic first valid
   claim assigns one Captain and removes other offers. Timeout is not assignment.
7. Arrival, fresh identity and registered Before photos precede washing. Registered
   After photos and actual submission update Customer review state. Reopening
   restores server progress instead of requiring a new selfie for an ongoing wash.
8. Customer approves/rates or raises a real problem. Earnings are an accounting
   ledger, not proof of a bank payout. Disputes and transfers remain human work.

Private assigned-party GPS and evidence access never expose precise locations or
KYC in public availability/offer responses. Google place search is guest-safe,
rate-limited and uses the existing Maps secret. It cannot manufacture coverage.

## Verify locally

Use Node **24**, pnpm **11** and Java **21+**. Install dependencies without changing
locks unnecessarily:

```sh
npm --prefix backend/firebase ci
npm --prefix backend/firebase/functions ci
pnpm firebase:test
```

The root command runs isolated Auth/Firestore/Storage emulators on **demo-wheelio**.
Guarded local fixtures and mock provider/photo adapters cannot establish real
payments, identity approval or physical device success. Never seed QA Captains or
invent fixed OTPs in production. Current controlled fixture state must not leak
into normal app builds. See [hookup rules](BACKEND-HOOKUP.md).

## Deployment

Deploy only verified changes to the existing project. For a complete deliberate
Functions/rules rollout (narrow the `--only` list for smaller changes):

```sh
pnpm exec firebase deploy --only "functions,firestore,storage" --project wheelio-apps --account ajay@trustkeyper.com
node backend/firebase/operations.cjs configure-api-access
node backend/firebase/operations.cjs configure-account-deletion
```

Organization restricted sharing forbids public IAM bindings. Do not disable it.
`configure-api-access` configures only documented HTTP gateways while Firebase
application authorization/webhook signatures remain mandatory; schedulers and
private triggers retain IAM access controls. `configure-account-deletion` inspects
the actual deletion runtime and binds only `firebaseauth.users.delete`; running
that setup command does not delete a user. It also binds conditional private
Storage object deletion, without granting object creation or Storage admin; see
[the lifecycle correction](ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md). Verify actual deployed source/runtime,
authentication rejection and required private service access after publication.
Warm minima remain **0**; no recurring warm-instance cost was approved.

If publishing authentication expires, use the local CLI callback:

```sh
pnpm exec firebase login --reauth --account ajay@trustkeyper.com
```

The owner completes Google security checks in the browser, never in chat. Native
client builds on Aman's Mac do not require this publishing login.

Default Hosting retains landing, private admin and optional Flutter QA routes.
`pnpm build` prepares that output; `pnpm deploy` publishes default Hosting only.
The marketing website is separate in `apps/website`; use its own configuration
for an intentional website deployment. Never replace it with default Hosting.

## Current acceptance

The deletion release passed **196 backend tests** and **172 Flutter tests**.
`deleteOwnAccount` was deployed/verified on 3 November; see
[its exact evidence](ACCOUNT-DELETION-2026-11-03.md). Prior Android checks and
provider actions are recorded in current reports. No claim that all iPhone/device
or human business checks are complete follows from local tests. Use
[the current Mac handoff](AMAN-IOS-HANDOFF-2026-11-02.md) and
[the actual results template](IOS-ACCEPTANCE-RESULTS-TEMPLATE.md).
