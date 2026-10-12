# Wheelio

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

## Current layout (11 October 2026)

- `apps/web/` — Next.js App Router website with TypeScript, deployable to Cloudflare Workers through OpenNext. API Route Handlers and Better Auth use Neon Postgres through Drizzle. `src/app/` owns pages, layouts, metadata, API routes and CSS; `src/lib/` owns auth and database setup. Colours and bundled Roboto fonts follow the iOS design system.
- `apps/ios/` — active native SwiftUI Customer and Captain (washer) apps. Open `apps/ios/Wheelio.xcodeproj`; Customer and Captain are shared schemes. Each app has `App/`, `Data/`, `Screens/` and assets. `Shared/` is used by both targets.
- `apps/android/` — reserved and empty except `.gitkeep`. Do not generate an Android application until requested.
- `backend/supabase/` — preserved migrations, seed data and edge functions. The application schema is ported to Neon/Drizzle under `apps/web/drizzle/` and verified locally and applied to live Neon, and existing data/edge functions have not been transferred. `backend/NEON-DATABASE.md` records the active migration and identity rules. `backend/API-CONTRACT.md` describes the original service contract.
- `designs/` — screen design exports. `Main.dc.html` is the design read-me; `wheelio-screens.json` is the navigation map.
- `docs/` — status, integration checklist, build brief and screen index.
- `legacy/` — earlier Flutter code, preserved for reference. It contains `apps/customer`, `packages/wheelio_ui` and `tool/bootstrap_customer.sh`. It is not the active app stack.

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

Native apps are built and run in Xcode using the Customer or Captain scheme. Simulator build commands are in README.md. The root pnpm workspace contains only `apps/web`; native projects do not need package.json files.

## Design rules

- The active iOS design system is in `apps/ios/Shared/DesignSystem/`. Primary blue is `#3160FF`, heading text `#172231`, and canvas `#F6F9FD`.
- One primary action per app screen. Green is reserved for pay, approve or accept; red is for errors and destructive actions.
- One small decision per screen in the booking flow.
- Payment screens explain that money is held and released after approval.
- Colour is never the only signal; use an icon and a word. Touch targets are at least 48 px (64 for washer controls).
- Undecided business values stay as configuration and placeholders, never invented prices or promises.
- The landing page is prelaunch. Do not imply app downloads or live booking are available before those services exist.

## Current implementation

Both iOS apps run on sample data. Demo login code: 123456 (000000 is expired). The in-app Screens gallery exposes designed screens and edge states. Web auth/database adapters require Neon and Better Auth environment values. Full schema migration and local tests are available through `pnpm db:migrate`, `pnpm db:check` and `pnpm db:test`; see `backend/NEON-DATABASE.md`. `/api/health` returns 503 for missing/unavailable database configuration.
