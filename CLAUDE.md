# WashKrew

> **21–22 October 2026: active web release uses Firebase.** Project `wheelio-apps` belongs to `ajay@trustkeyper.com`, with Trustkeyper billing. Flutter Customer and Captain controllers use phone OTP, server-priced bookings, Razorpay verification/refunds, protected uploads, real offers/assignment and wash tracking. Payment credentials and commercial settings remain explicitly **test mode**. Real Customer SMS delivery, OTP verification and account completion are confirmed; test-payment booking, assignment, wash review/earnings, disputes and refunds are accepted in `docs/WEB-ACCEPTANCE.md`. Hosting and refund recovery Functions were deployed on 22 October; 39 backend/rules/payment-adapter tests and 4 Customer tests passed. Both actual test refunds are processed. The latest netbanking refund recovered in full after a virtual test balance payment; safe retry/backoff, existing-refund recovery and Customer refund checks are deployed. WashKrew's separate test webhook preserves Trustkeyper's endpoint and ignores unrelated merchant payments. Physical GPS acceptance and live merchant cutover remain pending. Aman is completing merchant onboarding; the owner will provide live credentials afterward. KYC decisions, disputes and bank payouts require operators. See `docs/FIREBASE-BOOKINGS.md` and the Firebase section in `AGENTS.md` for deployment, including the required post-deploy HTTP gateway step. The Next.js/Neon/Cloudflare sections below are historical. Sample apps require `?demo=true` and remain isolated.

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies.

**Name: WashKrew** (renamed from WashKrew on 25 October 2026; company WASHKREW, website washkrew.com). Use `Brand.name` / `Brand.captainApp` in Flutter, never a literal. Logo masters (SVG) and mock-ups are in `brand/`; the Flutter `WLogo` widget (`packages/washkrew_ui/lib/src/brand.dart`) is the only way to show the logo. Technical identifiers still say wheelio (package names, bundle IDs `com.amanmaheshwari.wheelio.*`, Firebase project `wheelio-apps`, `WHEELIO_DEMO`, repo and folder names) and are left alone on purpose: renaming them needs new App Store and Firebase setup.

## Current layout (15 October 2026)

- `apps/web/` — Next.js App Router website with TypeScript, deployable to Cloudflare Workers through OpenNext. API Route Handlers and Better Auth use Neon Postgres through Drizzle. `src/app/` owns pages, layouts, metadata, API routes and CSS; `src/lib/` owns auth and database setup. Colours and bundled Roboto fonts follow the iOS design system. `/app` (Customer) and `/captain` (Captain) are web ports of the iOS apps on sample data, built from `src/phone/` (design system in `src/phone/ds/`, one folder per app); on a laptop they render in a centred phone frame, on a phone they fill the screen. They are superseded by the Flutter apps as the launch target and stay only until the Flutter web build is deployed.
- `apps/flutter/` — **active app stack**: Flutter Customer (`customer/`) and Captain (`captain/`) apps sharing `packages/washkrew_ui` (design system, navigation, phone frame, device services). Release order: web first, then iOS, then Android, all from this code. `web` and `ios` platforms exist (iOS added 23 Oct 2026: bundle IDs match the SwiftUI apps, team 8CCQQM7TP3, iOS 15+). iPhone builds run on sample data via `--dart-define=WHEELIO_DEMO=true`; install both on a connected iPhone with `apps/flutter/tool/run-ios.sh [customer|captain]` (needs Flutter and CocoaPods on the Mac). Add `android` with `flutter create --platforms` when that target starts. Ported screen by screen from `apps/ios/`; read `docs/FLUTTER.md` before changing them.
- `apps/ios/` — native SwiftUI Customer and Captain (washer) apps, the design and behaviour reference for the Flutter apps. Open `apps/ios/Wheelio.xcodeproj`; Customer and Captain are shared schemes. Each app has `App/`, `Data/`, `Screens/` and assets. `Shared/` is used by both targets.
- `apps/android/` — reserved and empty except `.gitkeep`. Do not generate an Android application until requested.
- `backend/supabase/` — preserved migrations, seed data and edge functions. The application schema is ported to Neon/Drizzle under `apps/web/drizzle/` and verified locally and applied to live Neon, and existing data/edge functions have not been transferred. `backend/NEON-DATABASE.md` records the active migration and identity rules. `backend/API-CONTRACT.md` describes the original service contract.
- `designs/` — screen design exports. `Main.dc.html` is the design read-me; `wheelio-screens.json` is the navigation map.
- `docs/` — status, integration checklist, build brief and screen index.
- `legacy/` — an older, unfinished Flutter customer app from before the iOS apps, preserved for reference. It contains `apps/customer`, `packages/washkrew_ui` and `tool/bootstrap_customer.sh`. It is not used by `apps/flutter/`.

## Commands

Use Node.js 24 and pnpm 11. Run these from the repository root:

```sh
pnpm install
pnpm dev
pnpm typecheck
pnpm build
pnpm preview
```

`pnpm deploy` deploys the web app to Cloudflare Workers. `pnpm db:generate` and `pnpm db:migrate` are ready for use after Neon credentials are configured; do not apply them to a database until the schema is reviewed.

Flutter 3.38 is at `~/development/flutter/bin`. In `apps/flutter/customer` or `apps/flutter/captain`: `flutter analyze`, `flutter run -d chrome`, and `flutter build web --release --pwa-strategy=none`. Preview a build with `node apps/flutter/tool/serve.mjs <app>/build/web <port>` (also `flutter-customer` / `flutter-captain` in `.claude/launch.json`).

The SwiftUI apps are built and run in Xcode using the Customer or Captain scheme. Simulator build commands are in README.md. The root pnpm workspace contains only `apps/web`; Flutter and native projects do not need package.json files.

## Design rules

- The active iOS design system is in `apps/ios/Shared/DesignSystem/`. Since 25 Oct 2026 the Flutter colours follow the WashKrew logo: primary blue `#0049FF`, heading charcoal `#22282D` (tokens in `apps/flutter/packages/washkrew_ui/lib/src/tokens.dart`; the SwiftUI reference still has the old `#3160FF` / `#172231`), and canvas `#F6F9FD`.
- One primary action per app screen. Green is reserved for pay, approve or accept; red is for errors and destructive actions.
- One small decision per screen in the booking flow.
- Payment screens explain that money is held and released after approval.
- Colour is never the only signal; use an icon and a word. Touch targets are at least 48 px (64 for washer controls).
- Undecided business values stay as configuration and placeholders, never invented prices or promises.
- The apps keep their phone layout on every screen size: on laptops the phone screen is centred with grey on both sides, never re-laid out for wide screens. On the web, every swipe has a visible control instead (see `docs/FLUTTER.md`).
- The landing page is prelaunch. Do not imply app downloads or live booking are available before those services exist.

## Current implementation

The Flutter and iOS apps run on sample data. Demo login code: 123456 (000000 is expired). The in-app Screens gallery exposes designed screens and edge states. Web auth/database adapters require Neon and Better Auth environment values. Full schema migration and local tests are available through `pnpm db:migrate`, `pnpm db:check` and `pnpm db:test`; see `backend/NEON-DATABASE.md`. `/api/health` returns 503 for missing/unavailable database configuration.

## Connecting the backend

- Before connecting any backend service, read `docs/BACKEND-HOOKUP.md` and show it to Aman. Add a line there whenever a new screen fakes data, a timer or a test button.

## Keeping the apps consistent

- Development happens in Flutter (`apps/flutter/`). Every app change must land in Flutter in the same task. If a change is made in the SwiftUI reference (`apps/ios/`), port it to Flutter before committing, so the two never drift. Update `docs/FLUTTER.md` (status and decisions) and `docs/BACKEND-HOOKUP.md` (anything faked) with it.

## Git

- Commit every change you make before finishing a task, so no work is left uncommitted. Commit on the branch you are working on and do not push unless asked.
