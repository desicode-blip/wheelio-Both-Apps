# WashKrew - instructions for all coding agents

## Current source and design lock - 28 October 2026

- The owner chose commit **af036f070aa624310b97b8277bfb6aabf9d8c4cc**
  (**af036f0**) as the final Customer/Captain design. Preserve its layouts,
  components, typography, assets and palette. Connect actual handlers/data in
  those screens; never create guessed replacements or generic Firebase screens.
  Read `docs/DESIGN-AUDIT-2026-10-28.md`. Do not restore the removed payment banner.
- The only apps are `apps/flutter/customer` and `apps/flutter/captain`, sharing
  `packages/washkrew_ui` and `packages/washkrew_firebase`. The owner explicitly
  requested removal of the retired SwiftUI, Next.js/React and legacy Flutter
  implementations. They remain recoverable in Git; do not rebuild or restore
  them. Keep current Firebase backend, admin, website, landing and design exports.
- Develop every app change in Flutter. Do not generate Android until requested.
  Keep the Firebase project, bundle IDs and Apple team. Windows checks do not
  establish Xcode compilation, signing or physical iPhone success.
- Read `docs/AMAN-IPHONE-ACCEPTANCE-2026-10-28.md` and its PDF in `output/pdf/`
  before continuing on Aman's Mac. Use the two Flutter `ios/Runner.xcworkspace`
  files. Record actual PASS/FAIL/BLOCKED evidence for both roles.

## Latest owner decisions

- Training videos, quiz and refresher entry points are **hidden and not required**
  for now (`training.enabled:false`, `training.required:false`). The three existing
  Aadhaar/selfie/payout steps lead to human review. Admin approval permits a
  Captain to work, subject to real eligibility, work hours, coverage and Online.
  Unapproved Captains cannot work. No placeholder grants training/quiz/KYC success.
  Keep the feature code for a later explicit owner decision to restore it.
- New bookings use the **separate WashKrew LIVE Razorpay merchant**, policy
  `no-credit-card-checkout`, saved config `config_TtDpJ7HJM4hHb2`. UPI (including
  linked credit cards), debit cards and netbanking are allowed; direct credit-card
  checkout/EMI/paylater are excluded. Do not regenerate old shared keys. Historical
  payment/refund records keep their original merchant and mode; never relabel them.
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
IDs `com.amanmaheshwari.wheelio.customer` / `.captain`, Apple team `8CCQQM7TP3`,
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
