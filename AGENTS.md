# Wheelio

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

## Firebase web release (21 October 2026)

- The owner selected Firebase for the backend and Hosting, under `ajay@trustkeyper.com`. The active project is `wheelio-apps`; `.firebaserc` selects it.
- `apps/hosting/` is the prelaunch landing page. Flutter Customer `/app/` and Captain `/captain/` use the shared Firebase controllers in `apps/flutter/packages/wheelio_firebase/` and the existing Wheelio screen components.
- `?demo=true` explicitly opens the older designed sample-data app with a persistent demo label. Never allow demo OTPs or sample lifecycle timers to write real data.
- Implemented and deployed: phone OTP, profiles, persisted bookings, server prices/capacity, Razorpay verification/refunds, Captain applications and operator approval, atomic assignment, private wash photos, status tracking, optional foreground location, customer approval and earnings. Payments remain explicitly **test mode**. Aman is completing merchant onboarding; the owner will provide live credentials afterward. The owner confirmed SMS delivery and showed the post-OTP name screen on 21 October; profile completion and complete paid-flow browser acceptance remain release checks. Payout transfers and dispute/KYC decisions are human operations.
- Build: `node apps/flutter/tool/build-firebase.mjs` with `firebase.local.json` (copy `firebase.example.json`) and `FLUTTER_BIN` if Flutter is not on PATH. Deploy: `npx -y firebase-tools@latest deploy --only "functions,firestore,storage,hosting" --project wheelio-apps --account ajay@trustkeyper.com --force`, then `node backend/firebase/operations.cjs configure-api-access`. Domain-restricted sharing requires this gateway step; do not disable the organization policy. See `docs/FIREBASE-BOOKINGS.md` for bucket CORS, IAM and live cutover.
- Run security rules/service tests: `npm ci --prefix backend/firebase`, `npm ci --prefix backend/firebase/functions`, then `npx -y firebase-tools@latest emulators:exec --project demo-wheelio --only "firestore,auth,storage" "npm --prefix backend/firebase test"`. Java 21+ is needed. All 27 tests passed; never seed QA captains or fixed OTPs into production.
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
- `apps/flutter/` — the active app stack: Flutter Customer and Captain apps sharing `packages/wheelio_ui`. Web first, then iOS, then Android, all from this code. See `docs/FLUTTER.md`.
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

- The iOS design system lives in `apps/ios/Shared/DesignSystem/`. Primary blue is `#3160FF`, heading text `#172231`, canvas `#F6F9FD`.
- One primary action per app screen. Green is for pay, approve or accept; red is for errors and destructive actions.
- Colour is never the only signal; pair it with an icon and a word. Touch targets are at least 48 px (64 px for washer controls).
- The apps keep their phone layout on every screen size (centred phone, grey sides on laptops). On the web, swipes become visible controls.
- Payment screens explain that money is held and released after approval.
- Undecided business values stay as configuration or placeholders. Never invent prices or promises.
- The landing page is prelaunch. Do not imply app downloads or live booking are available.

## Current state

Normal Flutter URLs use Firebase with explicit test-payment labels. The SwiftUI reference and `?demo=true` remain sample-data experiences; fixed demo codes must never reach real controllers. SMS delivery and the OTP verification step are owner-confirmed; completed account and paid-flow acceptance plus merchant cutover are still required before live operations. Legacy Next.js auth/database configuration and `/api/health` belong to the historical Neon stack, not the Firebase release.
