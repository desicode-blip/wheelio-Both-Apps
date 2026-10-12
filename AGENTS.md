# Wheelio

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

These instructions apply to all coding agents, including Codex and Claude Code. `CLAUDE.md` holds the same project context in more detail.

## Git

- Commit every change you make before finishing a task, so no work is left uncommitted. Commit on the branch you are working on and do not push unless asked.

## Layout

- `apps/web/` — Next.js App Router website (TypeScript), deployable to Cloudflare Workers through OpenNext. API routes and Better Auth use Neon Postgres through Drizzle. `src/app/` owns pages, layouts, API routes and CSS; `src/lib/` owns auth and database setup. `/app` (Customer) and `/captain` (Captain) are web ports of the iOS apps on sample data, built from `src/phone/`.
- `apps/ios/` — active native SwiftUI Customer and Captain (washer) apps. Open `apps/ios/Wheelio.xcodeproj`; use the Customer or Captain scheme. `Shared/` is used by both targets.
- `apps/android/` — reserved and empty. Do not generate an Android app until requested.
- `backend/` — preserved Supabase migrations, seed data and edge functions; `backend/NEON-DATABASE.md` records the active Neon migration rules.
- `designs/` — screen design exports. `docs/` — status, checklist and screen index.
- `legacy/` — earlier Flutter code, kept for reference only. It is not the active stack.

## Commands

Use Node.js 24 and pnpm 11, from the repository root:

```sh
pnpm install
pnpm dev
pnpm typecheck
pnpm build
pnpm preview
```

`pnpm deploy` deploys the web app to Cloudflare Workers. Do not run `pnpm db:migrate` against a database until the schema has been reviewed. Native apps are built in Xcode.

## Design rules

- The iOS design system lives in `apps/ios/Shared/DesignSystem/`. Primary blue is `#3160FF`, heading text `#172231`, canvas `#F6F9FD`.
- One primary action per app screen. Green is for pay, approve or accept; red is for errors and destructive actions.
- Colour is never the only signal; pair it with an icon and a word. Touch targets are at least 48 px (64 px for washer controls).
- Payment screens explain that money is held and released after approval.
- Undecided business values stay as configuration or placeholders. Never invent prices or promises.
- The landing page is prelaunch. Do not imply app downloads or live booking are available.

## Current state

Both iOS apps run on sample data. Demo login code: 123456 (000000 is expired). Web auth and database need Neon and Better Auth environment values. `/api/health` returns 503 when the database is missing or unavailable.
