# Wheelio

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

## Firebase web release (20 October 2026)

- The owner selected Firebase for the backend and Hosting, under `ajay@trustkeyper.com`. The active project is `wheelio-apps`; `.firebaserc` selects it.
- `apps/hosting/` is the active landing page. Flutter Customer `/app/` and Captain `/captain/` launch the shared Firebase prelaunch portal in `apps/flutter/packages/wheelio_firebase/`.
- `?demo=true` explicitly opens the older designed sample-data app with a persistent demo label. Never allow demo OTPs or sample lifecycle timers to write real data.
- Live features: email/password accounts, profiles, private wash requests with cancellation, and private Captain applications. Requests are not confirmed bookings. No real payments, matching, KYC decisions, wash tracking, uploads or payouts yet.
- Build: `node apps/flutter/tool/build-firebase.mjs` with `firebase.local.json` (copy `firebase.example.json`) and `FLUTTER_BIN` if Flutter is not on PATH. Deploy: `firebase deploy --only hosting,firestore,auth --project wheelio-apps --account ajay@trustkeyper.com`.
- Run security rules tests: `npm ci --prefix backend/firebase`, then `firebase emulators:exec --project demo-wheelio --only firestore,auth "npm --prefix backend/firebase test"`. On PowerShell quote the comma-separated `--only` argument. Java 21+ is needed for current emulators.
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

The Flutter and iOS apps run on sample data. Demo login code: 123456 (000000 is expired). Web auth and database need Neon and Better Auth environment values. `/api/health` returns 503 when the database is missing or unavailable.
