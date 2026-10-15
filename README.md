# Wheelio

Pay-per-wash, photo-verified exterior wash for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

## Project structure

All three platforms live in `apps/`; backend services, designs and documentation are shared at the root.

```text
Wheelio/
├── apps/
│   ├── web/                    # Next.js website (App Router + TypeScript)
│   │   ├── src/app/            # Landing page, layout, styles and metadata
│   │   ├── src/components/     # Reusable website components
│   │   └── public/             # Future static assets
│   ├── flutter/                # Active Customer and Captain apps (web first, then iOS, Android)
│   │   ├── customer/           # Customer app
│   │   ├── captain/            # Captain (washer) app
│   │   ├── packages/wheelio_ui/ # Shared design system, navigation and phone frame
│   │   └── tool/serve.mjs      # Local preview server for web builds
│   ├── ios/                    # Native SwiftUI apps (reference for the Flutter port)
│   │   ├── Wheelio.xcodeproj/  # Customer and Captain shared schemes
│   │   ├── Customer/           # App, Data, Screens and Assets
│   │   ├── Captain/            # App, Data, Screens and Assets
│   │   └── Shared/             # Design system, fonts and formatting
│   └── android/                # Reserved; only .gitkeep for now
├── backend/                    # Shared Supabase schema and edge functions
├── designs/                    # Screen design exports and navigation map
├── docs/                       # Status, integration notes and build brief
├── legacy/                     # Preserved earlier Flutter implementation
│   ├── apps/customer/
│   ├── packages/wheelio_ui/
│   └── tool/bootstrap_customer.sh
├── package.json                # Root web development commands
├── pnpm-workspace.yaml         # JavaScript workspace (apps/web)
└── pnpm-lock.yaml              # Reproducible web dependencies
```

The Flutter apps and the native iOS apps use their own tools; they are not JavaScript workspace packages. `legacy/` holds an older, unfinished Flutter customer app from before the iOS apps; the active Flutter code in `apps/flutter/` does not use it. `Wheelio-designs/` is an additional design export retained from the original folder.

## Website and web backend

The Next.js app in `apps/web/` deploys to Cloudflare Workers using OpenNext. Its API Route Handlers and Better Auth endpoint run in the same Worker. The database layer uses Neon Postgres with Drizzle ORM and Better Auth's Drizzle adapter. Use Node.js 24 and pnpm 11 (`.nvmrc` and `packageManager` record the versions).

Copy `apps/web/.env.example` to `apps/web/.env.local` and fill in the Neon `DATABASE_URL`, a `BETTER_AUTH_SECRET` (at least 32 characters), and `BETTER_AUTH_URL`. The local env file is ignored by Git. From the root:

```sh
pnpm install
pnpm dev
```

`pnpm dev` runs Next.js locally; `pnpm preview` builds and serves the app using the Cloudflare Workers runtime. `pnpm deploy` builds and deploys the Worker named `wheelio-web` after Wrangler is connected to the intended Cloudflare account. Set the same values as Worker secrets/environment variables in the Cloudflare dashboard for deployment. More details are in [apps/web/README.md](apps/web/README.md).

The full Neon schema migration has been applied and verified. To apply future migrations or inspect the database:

```sh
pnpm db:migrate
pnpm db:check
```

The 27-table schema, customer action functions, access policies and configuration passed migrations and behavior tests in a disposable PostgreSQL/PostGIS database. The live Neon migration and web API authentication checks passed on 12 October 2026. See [backend/NEON-DATABASE.md](backend/NEON-DATABASE.md) for details and remaining integrations. Original Supabase files are preserved; existing data and edge functions have not been transferred.

These commands also run from the root:

```sh
pnpm typecheck
pnpm build
pnpm start
```

The website remains a prelaunch landing page introducing the wash service, explaining the three-step flow, and showing a coming-soon notice. It uses the existing Wheelio colours and bundled Roboto fonts. Booking and app download links are not live, and the page does not collect visitor data.

The web app also carries earlier React demo ports of both iOS apps, now superseded by the Flutter apps, running on the same sample data: the Customer app at `/app` and the Captain app at `/captain` (not linked from the landing page, and marked noindex). On a laptop each app sits in a phone frame in the middle of the page; on a phone it fills the screen. Every screen, state and demo switch from the iOS Screens gallery is available through the "Screens" tab on the left edge. Demo login code: 123456. The code lives in `apps/web/src/phone/`.

## Flutter apps (Customer and Captain)

Both apps are now built in Flutter from one codebase in `apps/flutter/`. The web app is the first launch target, followed by iOS and then Android. They are screen-by-screen ports of the SwiftUI apps, running on the same sample data with the same Screens gallery. On a laptop, the phone screen sits in the middle of the window with grey on both sides; on a phone, it fills the screen. Swipes become visible buttons on the web. The decisions, structure and commands are in [docs/FLUTTER.md](docs/FLUTTER.md).

```sh
cd apps/flutter/captain
flutter build web --release --pwa-strategy=none
node ../tool/serve.mjs build/web 8082
```

## iOS apps / Xcode (reference)

Open `apps/ios/Wheelio.xcodeproj` in Xcode. Choose the **Customer** or **Captain** scheme, select an iPhone simulator or your connected iPhone, and press Run. Captain is the washer app. Both schemes are shared and tracked so they are available in a fresh checkout.

Both apps currently use sample data. In each app, the **Screens** tab opens the designed screens; **Step through all screens** in the Captain app walks W01–W50. The source groups remain relative to the project, so moving the whole iOS folder preserves source and asset references, bundle identifiers and signing settings.

For a simulator build without device signing:

```sh
xcodebuild -project apps/ios/Wheelio.xcodeproj -scheme Customer -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath apps/ios/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apps/ios/Wheelio.xcodeproj -scheme Captain -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath apps/ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Android

`apps/android/` is reserved for future Android work. No Android project, framework or dependencies have been added. `.gitkeep` lets Git retain the otherwise empty directory.

## Shared resources

| Path | Contents |
|---|---|
| `backend/supabase/` | Database migrations, security rules, sample data, Razorpay webhook and AI photo check |
| `backend/API-CONTRACT.md` | Server actions needed by the apps |
| `backend/whatsapp-templates.md` | Entry-pass bot messages for Meta approval |
| `designs/` | 124 exported screens plus the design read-me |
| `docs/FLUTTER.md` | Flutter app structure, the phone-frame and web-swipe decisions, and commands |
| `docs/STATUS.md` | Current platform structure and historical build progress |
| `docs/CONNECT-LATER.md` | Service integration checklist and historical Flutter notes |
| `docs/BUILD-BRIEF.md` | Build plan, accounts and open business decisions |
| `docs/screen-index.csv` | Screen flows and navigation links |
| `CLAUDE.md` | Current project conventions for coding sessions |

## Online sources

- Design (live): https://claude.ai/artifact/QrsfqjaXnQ9fpY7spb1XAN
- Google Drive "Wheelio" folder: https://drive.google.com/drive/folders/1iIwNXlTps-X5rACETmyfAqnT9boJ3kpU
