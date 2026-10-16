# Wheelio

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

## Current layout (15 October 2026)

- `apps/web/` — Next.js App Router website with TypeScript, deployable to Cloudflare Workers through OpenNext. API Route Handlers and Better Auth use Neon Postgres through Drizzle. `src/app/` owns pages, layouts, metadata, API routes and CSS; `src/lib/` owns auth and database setup. Colours and bundled Roboto fonts follow the iOS design system. `/app` (Customer) and `/captain` (Captain) are web ports of the iOS apps on sample data, built from `src/phone/` (design system in `src/phone/ds/`, one folder per app); on a laptop they render in a centred phone frame, on a phone they fill the screen. They are superseded by the Flutter apps as the launch target and stay only until the Flutter web build is deployed.
- `apps/flutter/` — **active app stack**: Flutter Customer (`customer/`) and Captain (`captain/`) apps sharing `packages/wheelio_ui` (design system, navigation, phone frame, device services). Release order: web first, then iOS, then Android, all from this code. Only the `web` platform exists so far; add `ios`/`android` with `flutter create --platforms` when those targets start. Ported screen by screen from `apps/ios/`; read `docs/FLUTTER.md` before changing them.
- `apps/ios/` — native SwiftUI Customer and Captain (washer) apps, the design and behaviour reference for the Flutter apps. Open `apps/ios/Wheelio.xcodeproj`; Customer and Captain are shared schemes. Each app has `App/`, `Data/`, `Screens/` and assets. `Shared/` is used by both targets.
- `apps/android/` — reserved and empty except `.gitkeep`. Do not generate an Android application until requested.
- `backend/supabase/` — preserved migrations, seed data and edge functions. The application schema is ported to Neon/Drizzle under `apps/web/drizzle/` and verified locally and applied to live Neon, and existing data/edge functions have not been transferred. `backend/NEON-DATABASE.md` records the active migration and identity rules. `backend/API-CONTRACT.md` describes the original service contract.
- `designs/` — screen design exports. `Main.dc.html` is the design read-me; `wheelio-screens.json` is the navigation map.
- `docs/` — status, integration checklist, build brief and screen index.
- `legacy/` — an older, unfinished Flutter customer app from before the iOS apps, preserved for reference. It contains `apps/customer`, `packages/wheelio_ui` and `tool/bootstrap_customer.sh`. It is not used by `apps/flutter/`.

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

- The active iOS design system is in `apps/ios/Shared/DesignSystem/`. Primary blue is `#3160FF`, heading text `#172231`, and canvas `#F6F9FD`.
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

## Git

- Commit every change you make before finishing a task, so no work is left uncommitted. Commit on the branch you are working on and do not push unless asked.
