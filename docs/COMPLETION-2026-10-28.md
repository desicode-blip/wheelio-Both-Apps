# WashKrew completion follow-up — 28 October 2026

This is the latest software and configuration status. It supersedes earlier
test-only payment/photo notes and the historical Mac handoff PDF where they
conflict. Customer/Captain staging layouts, assets, tokens, bundle IDs and the
`wheelio-apps` project are preserved. Android remains deferred.

## Completed and published

- Separate WashKrew live payments, saved default gateway configuration
  `config_TtDpJ7HJM4hHb2`, and server policy `no-credit-card-checkout` are active.
  Debit cards, UPI and netbanking are allowed. The owner's clarification permits
  credit cards linked inside UPI. Direct credit-card checkout is excluded.
  Historical payment/refund routing remains on each booking's original merchant
  and mode. See [the payment report](LIVE-PAYMENTS-2026-10-28.md).
- The existing private photo service now supports **test and live jobs** through
  server-only `privateConfig/photoChecks.paymentModes: ['test', 'live']`. The
  legacy `paymentMode: test` is retained for compatibility. An explicit mode list
  takes precedence; invalid/duplicate/unknown modes fail closed. No payment or
  historical booking was relabelled.
- An enabled photo service cannot be bypassed by presenting a booking in an
  unsupported mode. Live identity, evidence quality, wash-start checks and
  advisory after-photo review now use the same mode policy. Photo warnings do
  not approve a wash or release money.
- Selfie verification now requires the current server-issued capture session
  within its **five-minute capture window**, including the transaction that
  claims the verification attempt. The separate 24-hour review/cleanup retention
  is not permission to submit a stale automated capture.
- Captain photo-check request failures now use the existing error/toast path,
  instead of returning silently from the Check photos button. No screen was
  redesigned.
- Five changed Functions and the rebuilt Captain web app are deployed. The
  normal authenticated HTTP gateway setup was reapplied; private IAM service
  access and Firebase authentication/webhook signature requirements remain.
- `node backend/photo-check/activate.cjs live` verifies actual deployed private
  model/IAM/Gemini inference and the configured Cloud Run service URL, then
  atomically enables live processing while retaining historical test processing.
  Runtime verification is distinct from physical iPhone acceptance.

## Verification

- **120 backend/rules/payment tests passed**, including a new isolated complete
  live-policy checkout/capture → assignment → identity → eight evidence images →
  photo review → Customer approval/rating → live earnings regression. It also
  checks historical test identity after live activation, invalid mode rejection
  and stale capture rejection. Payment capture and image comparison in this
  regression are test adapters; they are not real-money/device acceptance.
- **4 Captain tests passed**, Captain analysis passed, and its release web build
  passed. The portable iOS tooling checks passed for both app configurations,
  argument/device handling and native dependency declarations. These do not run
  Xcode, resolve CocoaPods on a Mac, sign or install an app.
- Real deployed service checks passed using the actual Functions runtime account:
  private IAM invocation, matching/different public-fixture faces, image quality/
  thumbnail processing and actual structured Gemini image review. No real
  applicant's identity, account, booking or payment was created by these checks.
- Published Customer and Captain bundles match the local release output. App
  and admin routes respond successfully. All five changed callables reject
  anonymous requests; admin/payment authentication, private KYC images and invalid
  live-webhook signature rejection were checked again.
- Browser startup/navigation checks exercised the actual published phone layouts,
  Customer server catalog/profile/policy-unavailable handling, and Captain
  language/onboarding/guest-to-signup gate. No OTP or live payment was submitted.

## What still requires the owner or Aman

| Item | Actual status and next action |
| --- | --- |
| Training requirement/content | Configuration audit found no published approved videos and training was not currently required. The owner was asked whether to enforce real videos/quiz or a documented human-confirmed in-person process. This task does not invent that policy, mark training complete or count placeholders. Publish approved content/process after that decision. |
| Support and policies | Support phone/email/hours, operating legal entity and approved terms/privacy URL are absent from app configuration. Aman must supply the approved values; no dummy number, policy or legal approval was invented. Use `operator.cjs publish-content` after review. |
| Commercial/coverage confirmation | Existing prices, payouts and three active societies were preserved. Confirm live commercial terms and actual coverage rather than treating inherited catalog values as a new business approval. |
| Real Captain approval | There are **zero approved Captains**. An approved human reviewer must inspect real private identity/payout details, training and requested societies at https://wheelio-apps.web.app/admin/. Approval leaves a Captain offline; they choose to go online. No QA Captain or automatic approval was added. |
| Mac/iPhone and APNs | Compile/sign both Flutter workspaces on the owning Mac, resolve actual native dependency failures, configure the Apple team/APNs material and perform physical camera/media/SMS/maps/UPI/push acceptance. Windows checks cannot establish those results. |
| Live transaction acceptance | The owner must perform a real debit/UPI booking and original-method refund after operational readiness. No live charge/refund/payout was executed by this follow-up. |

DigiLocker, WhatsApp Business, voice-call OTP and masked calling remain deferred
because their provider accounts are unavailable, as previously directed by the
owner. Bank transfers and sensitive eligibility/dispute decisions remain human
operations. These external inputs and device checks mean an operational launch
is not yet accepted, even though live payment and photo configuration are active.

## Mac continuation

Use [MAC-HANDOFF.md](MAC-HANDOFF.md) for preparation/signing and
`bash apps/flutter/tool/run-ios.sh --prepare`, followed by both real Flutter apps.
Keep bundle IDs and staging designs. The public app configuration is included in
source; private Firebase CLI credentials, Razorpay keys and Apple signing keys
are not needed in Flutter or a source transfer.

The hosted server is **live**. Do not switch the global catalog back to test,
relabel historical orders or approve a fake Captain merely for a device test.
Use isolated local QA for simulated payment/identity flows; arrange an actual
consenting reviewed Captain and an owner-performed live payment for acceptance.
Record the source commit, device/OS/tool versions, observed results and any named
failure without including OTPs, keys or private identity images in Git/reports.
