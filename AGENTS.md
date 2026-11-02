# WashKrew - instructions for all coding agents

## Current source and design lock - 28 October 2026

- The owner chose commit **af036f070aa624310b97b8277bfb6aabf9d8c4cc**
  (**af036f0**) as the final Customer/Captain design. Preserve its layouts,
  components, typography, assets and palette. Connect actual handlers/data in
  those screens; never create guessed replacements or generic Firebase screens.
  Read `docs/DESIGN-AUDIT-2026-10-28.md`. Do not restore the removed payment banner.
- Owner-approved W05 exception (28 October): DigiLocker is removed; use phone
  document upload followed by private human admin review. Read
  `docs/KYC-UPLOAD-2026-10-28.md`. Other screens stay pinned to af036f0.
- The only apps are `apps/flutter/customer` and `apps/flutter/captain`, sharing
  `packages/washkrew_ui` and `packages/washkrew_firebase`. The owner explicitly
  requested removal of the retired SwiftUI, Next.js/React and legacy Flutter
  implementations. They remain recoverable in Git; do not rebuild or restore
  them. Keep current Firebase backend, admin, website, landing and design exports.
- Develop every app change in Flutter. Owner authorized generating and installing
  both Android apps on the connected phone on 31 October 2026. Keep their existing
  Flutter UI. USB acceptance APKs use this laptop's debug certificate; they are
  not Play Store releases. Never commit a private signing key. Read
  `docs/ANDROID-DEVICE-CHECK-2026-10-31.md` for the current evidence and limitations.
  Keep the Firebase project, bundle IDs and Apple team. Windows checks do not
  establish Xcode compilation, signing or physical iPhone success.
- Read `docs/AMAN-IPHONE-ACCEPTANCE-2026-10-28.md` and its PDF in `output/pdf/`
  before continuing on Aman's Mac. Use the two Flutter `ios/Runner.xcworkspace`
  files. Record actual PASS/FAIL/BLOCKED evidence for both roles.
  The latest compact build/test sequence is
  `docs/AMAN-IOS-BUILD-AND-TEST-2026-10-30.md` and its PDF in `output/pdf/`;
  use `docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md` for the native result record.

## Latest owner decisions

- Phone OTP uses Firebase's native verification API on Android/iOS and the web
  verification flow only in a browser. Do not add a custom bot-check screen to
  native apps or disable app verification for real SMS. Android SHA-1/SHA-256 and
  iOS silent APNs setup reduce challenges; Firebase may still require its secure
  reCAPTCHA fallback, especially for sideloaded Android builds. The Apple APNs
  key must be supplied privately and configured before claiming silent iPhone
  verification. Web anti-abuse verification stays enabled.

- Training videos, quiz and refresher entry points are **hidden and not required**
  for now (`training.enabled:false`, `training.required:false`). The three existing
  Aadhaar/selfie/payout steps lead to human review. Admin approval permits a
  Captain to work, subject to real eligibility, work hours, coverage and Online.
  Unapproved Captains cannot work. No placeholder grants training/quiz/KYC success.
  Keep the feature code for a later explicit owner decision to restore it.
- New bookings use the **separate WashKrew LIVE Razorpay merchant**, policy
  `no-credit-card-checkout`. Owner clarification (30 October): expose all supported
  UPI apps, debit cards, netbanking and provider wallets; EMI/paylater remain hidden.
  `checkoutPresentation: allNonCredit` uses explicit runtime groups without pinning
  the older saved layout. Keep `config_TtDpJ7HJM4hHb2` for historical records.
  Credit-linked UPI stays allowed. Do not regenerate old shared keys. Historical
  payment/refund records keep their original merchant and mode; never relabel them.
- Owner-confirmed cancellation policy (31 October): new bookings snapshot
  `walletByTime`. Within five minutes of the first server booking confirmation,
  return 100% of paid cash-plus-wallet value as wallet credit, including bookings
  less than two hours away. After five minutes, return 50% credit at least two
  hours before the server-confirmed wash window starts; inside two hours return
  no credit. Exactly five minutes is full credit; exactly two hours is 50%.
  Washing still closes Customer self-cancellation. Service failures/no-show and
  human-upheld wash problems return full wallet value without a fee. New normal
  cancellations do not request bank refunds. Preserve historical saved cash-
  refund obligations and source refunds for prohibited payment funding. Use
  integer paise, a current authenticated server quote and atomic credit/booking/
  capacity/Captain updates; never restore used credit on top of the awarded total.
  Existing authored controls show all three outcomes and reuse credit. Read
  `docs/WALLET-CANCELLATION-2026-10-31.md`; it supersedes the financial rules in
  the older report and iPhone PDF. No new wallet-history screen is authorized.
- Payment cutover does not establish live charge/refund or physical acceptance.
  Read `docs/LIVE-PAYMENTS-2026-10-28.md` and `docs/COMPLETION-2026-10-28.md`.
  Private photo services support test/live, with fresh five-minute selfie sessions;
  photo quality/face similarity never substitutes for human identity/KYC decisions.
- `/admin/` is private human Captain review for `info@trustkeyper.com`,
  `amanmaheshwari900@gmail.com`, `ajay@trustkeyper.com`,
  `ajaybhatnagar1712@gmail.com`. Reviewer access stays server-enforced. Do not approve
  real people as a test. Payout transfers and dispute decisions are human operations.
- Booking windows are 4 AM-10 PM. Deleting an account removes only the current app's
  account. DigiLocker, WhatsApp Business, masked calls and voice OTP are deferred.
  Aman will supply approved legal/support/commercial inputs. Never invent them.

## Brand and design

Doorstep photo-verified exterior washes in Hyderabad societies. Company WASHKREW,
website washkrew.com. Use `Brand.name` / `Brand.captainApp`, never a literal app name.
Use the shared `WLogo` widget for logos; masters are in `brand/`. Design tokens and
Roboto fonts live in `apps/flutter/packages/washkrew_ui`: primary #0049FF, heading
#22282D, canvas #F6F9FD. Preserve the phone layout on all widths (grey sides on a
laptop), with visible web equivalents for swipes. One primary action per screen;
green means pay/approve/accept, red means errors/destructive actions. Pair colour
with icon/text; touch targets at least 48 px (Captain controls 64 px). Payment
screens explain holding/releasing money after approval. Undecided prices/promises
stay configuration. Do not advertise downloads or service before they exist.

Technical identifiers deliberately retained: Firebase project `wheelio-apps`, bundle
IDs `com.amanmaheshwari.wheelio.customer` / `.captain`, Apple team `28JNT7H8KA` (paid "Sumit Mandal" team since 29 Oct 2026; previously free personal team `8CCQQM7TP3`),
`WHEELIO_DEMO`, repo/folder names. Renaming needs explicit setup and authorization.

## Backend and build

- Firebase owner `ajay@trustkeyper.com`; `.firebaserc` selects `wheelio-apps`.
  Default Hosting serves `/app/`, `/captain/`, `/admin/` and `apps/hosting` landing.
  `apps/website` is washkrew.com on its separate Hosting site; preserve it.
- Before connecting a new service read `docs/BACKEND-HOOKUP.md` and show it to the
  owner. Add every new fake/timer/test button there. Update `docs/FLUTTER.md` with
  app changes. Normal builds use Firebase; explicit `?demo=true` / `WHEELIO_DEMO`
  builds use labelled sample state. Never send demo OTPs/timers to real controllers.
- Use Flutter 3.38.6, Node 24, pnpm 11. Root `pnpm dev` / `pnpm dev:captain` launch
  the two Flutter web apps; `pnpm typecheck`, `pnpm test`, `pnpm build`,
  `pnpm preview` use the current stack. `FLUTTER_BIN` overrides the Flutter path.
  `firebase.local.json` contains public app config, never merchant secrets.
- Deploy from a verified build with the documented Firebase commands and then
  `node backend/firebase/operations.cjs configure-api-access` for Functions. Keep
  organization policy; never disable domain-restricted sharing. Full instructions:
  `docs/FIREBASE-BOOKINGS.md`. `pnpm deploy` is default Firebase Hosting only.
- Backend tests: install npm dependencies in `backend/firebase` and its `functions`
  folder, then `pnpm firebase:test` (Auth/Firestore/Storage emulators, demo project,
  Java 21+). Never seed QA Captains or fixed OTPs in production.
- Historical Supabase/Neon notes are archives, not current frontend instructions.
  Do not migrate/delete databases as part of frontend cleanup. Private credential
  PDFs, secrets, auth tokens, KYC and downloaded merchant keys never belong in Git.

## Git

Commit every change before finishing. Use the current branch and preserve local
work. Do not push unless asked. Never hard-reset or force-push to erase work.

## Owner decision — 1 November 2026
Captain-defined map centre and radius 1–10 km cover every home/society inside it; no manual society approvals for new bookings. Explicit UI exception: map/radius setup after documents/payout and same editor from Captain Home. Human admin identity/payout approval stays mandatory. Fixed centre is independent of job GPS. See docs/CAPTAIN-COVERAGE-2026-11-01.md. All other designs remain locked.

Play Console: WashKrew Customer and WashKrew Captain are two separate apps with
their existing `.customer` and `.captain` package IDs. Never change the unrelated
TrustKeyper or TrustKeyper Staging apps, releases, signing or tester setup. Use a
dedicated WashKrew internal tester list. See docs/PLAY-INTERNAL-2026-11-01.md.

Owner decision — 2 November 2026: for Captain-area bookings, the **entire**
Customer time window must fit within one continuous saved Captain work period.
Partial overlap and a period spanning a break do not qualify. Availability,
payment capacity, dispatch and claim must enforce the same rule. Preserve the
historical society-booking interpretation and finishability of assigned jobs.

Owner decision — 2 November 2026: live Customer Pay opens Razorpay directly;
remove the duplicate app payment-method sheet from the real checkout path.
Demo/reference C17 remains available. Keep C18's authored layout, with text that
describes actual upload/opening/confirmation stages. No other redesign is approved.
