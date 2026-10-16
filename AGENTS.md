# Wheelio

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

These instructions apply to all coding agents, including Codex and Claude Code. `CLAUDE.md` holds the same project context in more detail.

## Connecting the backend

- Before connecting any backend service, read `docs/BACKEND-HOOKUP.md` and show it to the owner. Add a line there whenever a new screen fakes data, a timer or a test button.

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
