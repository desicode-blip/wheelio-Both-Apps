# WashKrew

## Owner handoff update - 27 October 2026

- **Latest 28 October payment instruction:** the owner now authorizes real
  payments and bans only credit-card checkout; UPI stays allowed, including a
  linked credit card. Read `docs/LIVE-PAYMENTS-2026-10-28.md`. This supersedes the
  older prohibition on a requested live cutover. Firebase owner authentication,
  Functions/Hosting deployment and gateway setup are complete. New bookings now
  use live/WashKrew with `no-credit-card-checkout` and the saved default
  `config_TtDpJ7HJM4hHb2`. Historical bookings keep their merchant/mode. No actual
  live charge/refund acceptance is claimed. There are zero approved Captains;
  photo services remain test-gated pending real device/operational acceptance.
  Do not silently ban credit-funded UPI or bypass training/approval/device gates.

- **28 October follow-up:** read `docs/ADMIN-MERCHANT-2026-10-28.md`. Separate
  WashKrew live secrets/webhook and merchant-safe historical routing are now
  implemented/deployed; payments stay test and new-merchant live acceptance is
  pending. `/admin/` provides private human Captain review for the four approved
  Google reviewers. This supersedes pending-integration/CLI-only statements
  below, without approving any real Captain or bypassing training/device gates.

- Read `docs/CLAUDE-MAC-CONTINUATION-2026-10-27.md` and its PDF in `output/pdf/` before continuing on Aman's Mac. It records current remaining work and supersedes historical setup notes where they conflict.
- Aman will supply temporary training design placeholders instead of videos for now. Use his assets in the existing training regions without redesigning screens. A placeholder must never award server watch progress, quiz success, training/KYC approval or a fake playback result. Approved real training remains pending.
- The owner reports Razorpay requires a **separate WashKrew merchant account**. Aman is handling that onboarding/documents/access. Do not launch WashKrew using Trustkeyper's old shared live pair, duplicate Aman's application or switch payments to live. Old credentials/webhooks are historical and existing test records still need safe reconciliation. New merchant integration and merchant-aware historical payment/refund routing remain to be completed after access is supplied.
- Preserve staging design, bundle IDs and Firebase project. Compile/sign and perform the physical Customer-Captain acceptance on the Mac; Windows tests do not prove native compilation or device success.

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies.

**Name: WashKrew** (renamed from Wheelio on 25 October 2026; company WASHKREW, website washkrew.com). Use `Brand.name` / `Brand.captainApp` in Flutter, never a literal. Logo masters (SVG) and mock-ups are in `brand/`; the Flutter `WLogo` widget (`packages/washkrew_ui/lib/src/brand.dart`) is the only way to show the logo. Flutter package and code names were renamed too (`washkrew_ui`, `washkrew_firebase`, `washkrew_customer`, `washkrew_captain`, `WashKrewRuntime`). A few technical identifiers still say wheelio on purpose: bundle IDs `com.amanmaheshwari.wheelio.*`, Firebase project `wheelio-apps`, `WHEELIO_DEMO`, the SwiftUI project file `Wheelio.xcodeproj`, and the repo and folder names. Renaming those needs new App Store and Firebase setup.

## Firebase web release (21 October 2026)

- The owner selected Firebase for the backend and Hosting, under `ajay@trustkeyper.com`. The active project is `wheelio-apps`; `.firebaserc` selects it.
- `apps/website/` is the washkrew.com website (static, own Firebase Hosting site; see its README). `apps/hosting/` is the prelaunch landing page on the default site. Flutter Customer `/app/` and Captain `/captain/` use the shared Firebase controllers in `apps/flutter/packages/washkrew_firebase/` and the existing WashKrew screen components.
- `?demo=true` explicitly opens the older designed sample-data app with a persistent demo label. Never allow demo OTPs or sample lifecycle timers to write real data.
- Implemented and deployed: phone OTP, profiles, persisted bookings, server prices/capacity, Razorpay verification/refunds, Captain applications and operator approval, atomic assignment, private wash photos, status tracking, optional foreground location, customer approval and earnings. Payments remain explicitly **test mode**. Merchant OTP and live credential setup completed on 25 October; website approval and live operational acceptance remain pending (see `docs/LIVE-LAUNCH.md`). Real Customer SMS delivery, OTP verification and account completion were accepted on 21 October; test-payment booking, assignment, tracking, photo approval, earnings, disputes and refund acceptance is recorded in `docs/WEB-ACCEPTANCE.md` (21–22 October). Both actual test refunds are processed; the netbanking refund recovered in full after adding virtual test balance. Refund retries/backoff, existing-refund recovery and safe Customer status checks are deployed. The separate test webhook preserves Trustkeyper's webhook and ignores unrelated merchant payments. Payout transfers and dispute/KYC decisions are human operations.
- Build: `node apps/flutter/tool/build-firebase.mjs` with `firebase.local.json` (copy `firebase.example.json`) and `FLUTTER_BIN` if Flutter is not on PATH. Deploy: `npx -y firebase-tools@latest deploy --only "functions,firestore,storage,hosting" --project wheelio-apps --account ajay@trustkeyper.com --force`, then `node backend/firebase/operations.cjs configure-api-access`. Domain-restricted sharing requires this gateway step; do not disable the organization policy. See `docs/FIREBASE-BOOKINGS.md` for bucket CORS, IAM and live cutover.
- Run security rules/service tests: `npm ci --prefix backend/firebase`, `npm ci --prefix backend/firebase/functions`, then `npx -y firebase-tools@latest emulators:exec --project demo-wheelio --only "firestore,auth,storage" "npm --prefix backend/firebase test"`. Java 21+ is needed. All 57 backend/rules/payment/notification tests, 8 Customer tests and 5 shared native-login/checkout tests passed on 25 October; never seed QA captains or fixed OTPs into production.
- The existing live Razorpay pair is now installed in Wheelio's `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`; archived `RAZORPAY_TEST_KEY_ID` / `RAZORPAY_TEST_KEY_SECRET` still serve test orders and refunds. The separate live webhook is registered and enabled. Booking mode remains **test** while Razorpay reviews the submitted WashKrew website (24–48 hours shown), commercial settings await review, and no actual live captains are approved. Do not regenerate shared merchant keys or relabel test bookings as live. Native iPhone source uses Firebase by default; physical camera/UPI/GPS/APNs acceptance remains for the owner's Mac. Private credential documents and secret values never belong in Git.
- The Next.js/Neon/Cloudflare setup below is retained as historical work, not the Firebase release path. No existing Neon data has been migrated.

These instructions apply to all coding agents, including Codex and Claude Code. `CLAUDE.md` holds the same project context in more detail.

## Connecting the backend

- Before connecting any backend service, read `docs/BACKEND-HOOKUP.md` and show it to the owner. Add a line there whenever a new screen fakes data, a timer or a test button.

## Keeping the apps consistent

- Development happens in Flutter (`apps/flutter/`). Every app change must land in Flutter in the same task. If a change is made in the SwiftUI reference (`apps/ios/`), port it to Flutter before committing, so the two never drift. Update `docs/FLUTTER.md` (status and decisions) and `docs/BACKEND-HOOKUP.md` (anything faked) with it.

## Git

- Commit every change you make before finishing a task, so no work is left uncommitted. Commit on the branch you are working on and do not push unless asked.

## Layout

- `apps/web/` — Next.js App Router website (TypeScript), deployable to Cloudflare Workers through OpenNext. API routes and Better Auth use Neon Postgres through Drizzle. `src/app/` owns pages, layouts, API routes and CSS; `src/lib/` owns auth and database setup. `/app` (Customer) and `/captain` (Captain) are earlier React ports of the iOS apps, now superseded by the Flutter apps.
- `apps/flutter/` — the active app stack: Flutter Customer and Captain apps sharing `packages/washkrew_ui`. Web first, then iOS, then Android, all from this code. See `docs/FLUTTER.md`.
- `apps/ios/` — native SwiftUI Customer and Captain (washer) apps, the reference the Flutter apps were ported from. Open `apps/ios/Wheelio.xcodeproj`; use the Customer or Captain scheme. `Shared/` is used by both targets.
- `apps/android/` — reserved and empty. Do not generate an Android app until requested.
- `backend/` — preserved Supabase migrations, seed data and edge functions; `backend/NEON-DATABASE.md` records the active Neon migration rules.
- `designs/` — screen design exports. `docs/` — status, checklist and screen index.
- `legacy/` — an older, unfinished Flutter customer app, kept for reference only. It is not used by `apps/flutter/`.

## Commands

Use Node.js 24 and pnpm 11, from the repository root:

```sh
pnpm install
pnpm dev
pnpm typecheck
pnpm build
pnpm preview
```

`pnpm deploy` deploys the web app to Cloudflare Workers. Do not run `pnpm db:migrate` against a database until the schema has been reviewed. Flutter apps: `flutter analyze` and `flutter build web --release --pwa-strategy=none` in `apps/flutter/customer` or `apps/flutter/captain` (Flutter is at `~/development/flutter/bin`). SwiftUI apps are built in Xcode.

## Design rules

- Owner design lock: preserve the current `staging` Customer/Captain layouts, components, palette, typography and assets. Connect handlers and actual data in those screens. Never substitute generic Firebase screens or guessed designs. Staging deliberately removed the payment banner; do not restore it without an approved design change. Test/live isolation remains enforced in the backend. See `docs/FUNCTIONALITY-2026-10-26.md` for current functionality and pending gates.

- The iOS design system lives in `apps/ios/Shared/DesignSystem/`. Since 25 Oct 2026 the Flutter colours follow the WashKrew logo: primary blue `#0049FF`, heading charcoal `#22282D` (tokens in `apps/flutter/packages/washkrew_ui/lib/src/tokens.dart`; the SwiftUI reference still has the old `#3160FF` / `#172231`), canvas `#F6F9FD`.
- One primary action per app screen. Green is for pay, approve or accept; red is for errors and destructive actions.
- Colour is never the only signal; pair it with an icon and a word. Touch targets are at least 48 px (64 px for washer controls).
- The apps keep their phone layout on every screen size (centred phone, grey sides on laptops). On the web, swipes become visible controls.
- Payment screens explain that money is held and released after approval.
- Undecided business values stay as configuration or placeholders. Never invent prices or promises.
- The landing page is prelaunch. Do not imply app downloads or live booking are available.

## Current state

Normal Flutter URLs use Firebase. New bookings use the separate WashKrew live merchant and the saved debit-card/UPI/netbanking checkout configuration; historical bookings keep their original merchant/mode. Read `docs/LIVE-PAYMENTS-2026-10-28.md` for the verified 28 October cutover and remaining gates. Zero Captains are approved, private photo services remain test-gated pending physical/operational acceptance, and no live transaction acceptance is claimed. The staging design removed payment banners; do not restore them. The SwiftUI reference and `?demo=true` remain isolated sample experiences. Customer SMS/account completion and older test-payment acceptance are recorded in `docs/WEB-ACCEPTANCE.md`. Approved content, commercial/coverage review, real human Captain approval and physical iPhone/GPS/APNs acceptance still gate operational launch. Legacy Next.js/Neon/Cloudflare notes are historical.
