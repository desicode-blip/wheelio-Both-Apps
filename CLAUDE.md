# WashKrew

## Owner handoff update - 27 October 2026

Read `docs/CLAUDE-MAC-CONTINUATION-2026-10-27.md` (PDF in `output/pdf/`) and `docs/MAC-HANDOFF.md` first. These current owner decisions supersede conflicting historical paragraphs below:

- Preserve the staging design and use the active Flutter Customer/Captain apps. Compile/sign/test on Aman's Mac; do not use the SwiftUI sample project or generate Android.
- Aman is supplying **training design placeholders**, not videos for now. Use only his assets in the existing regions. Never count a placeholder as watched training, a passed quiz, verified KYC or working playback; do not silently bypass production gates.
- Razorpay told the owner WashKrew needs a **separate merchant account**. Aman is handling the application/documents/access. The old shared Trustkeyper live credentials are not an approved launch path. Keep test mode and preserve old payment/refund obligations. New merchant integration, historical merchant-safe routing and new-merchant acceptance are pending; do not duplicate onboarding or regenerate Trustkeyper keys.
- Software baseline `81c40ee` passed 89 backend/rules tests, 24 Flutter tests, 3 model tests, both web builds and app/shared/tool analyses. Xcode compilation, signed iPhone installation, APNs and physical acceptance remain unproved. Approved content, commercial/coverage decisions and live approvals are separate gates.

> **25 October 2026: active apps use Firebase.** Project `wheelio-apps` belongs to `ajay@trustkeyper.com`, with Trustkeyper billing. The Flutter Customer/Captain apps have real OTP, persisted bookings, camera/media, assignment, wash tracking/evidence, approval/refunds, wallets, earnings and private notifications. Native iPhone source uses Firebase by default; physical iPhone and Apple push acceptance remain for the owner's Mac. The merged source passed four Flutter analyses, 57 backend/rules/payment/notification tests, 8 Customer tests, 5 shared native-login/checkout tests and both release web builds. The existing live Razorpay pair is now installed securely in the generic Wheelio secrets, and the owner-approved separate live webhook is enabled. Archived test secrets still serve test bookings/refunds; booking mode remains **test**. WashKrew's website is under Razorpay review (24–48 hours shown); commercial review and actual approved live captains are also required before launch. No merchant key was regenerated and no Trustkeyper setting was changed. KYC/dispute decisions and bank payouts remain human operations. See `docs/LIVE-LAUNCH.md`, `docs/IOS-FIREBASE.md`, `docs/WEB-ACCEPTANCE.md` and `docs/FIREBASE-BOOKINGS.md`. Run the documented post-deploy HTTP gateway step without disabling the organization policy. Private credential documents and secret values never belong in Git. The Next.js/Neon/Cloudflare sections below are historical. Explicit demo builds stay labelled and isolated.

Doorstep, photo-verified exterior washes for cars and bikes in Hyderabad gated societies.

**Name: WashKrew** (renamed from Wheelio on 25 October 2026; company WASHKREW, website washkrew.com). Use `Brand.name` / `Brand.captainApp` in Flutter, never a literal. Logo masters (SVG) and mock-ups are in `brand/`; the Flutter `WLogo` widget (`packages/washkrew_ui/lib/src/brand.dart`) is the only way to show the logo. Flutter package and code names were renamed too (`washkrew_ui`, `washkrew_firebase`, `washkrew_customer`, `washkrew_captain`, `WashKrewRuntime`). A few technical identifiers still say wheelio on purpose: bundle IDs `com.amanmaheshwari.wheelio.*`, Firebase project `wheelio-apps`, `WHEELIO_DEMO`, the SwiftUI project file `Wheelio.xcodeproj`, and the repo and folder names. Renaming those needs new App Store and Firebase setup.

## Current layout (15 October 2026)

- `apps/web/` — Next.js App Router website with TypeScript, deployable to Cloudflare Workers through OpenNext. API Route Handlers and Better Auth use Neon Postgres through Drizzle. `src/app/` owns pages, layouts, metadata, API routes and CSS; `src/lib/` owns auth and database setup. Colours and bundled Roboto fonts follow the iOS design system. `/app` (Customer) and `/captain` (Captain) are web ports of the iOS apps on sample data, built from `src/phone/` (design system in `src/phone/ds/`, one folder per app); on a laptop they render in a centred phone frame, on a phone they fill the screen. They are superseded by the Flutter apps as the launch target and stay only until the Flutter web build is deployed.
- `apps/flutter/` — **active app stack**: Flutter Customer (`customer/`) and Captain (`captain/`) apps sharing `packages/washkrew_ui` (design system, navigation, phone frame, device services). Release order: web first, then iOS, then Android, all from this code. `web` and `ios` platforms exist (iOS added 23 Oct 2026: bundle IDs match the SwiftUI apps, team 8CCQQM7TP3, iOS 15+). Normal iPhone builds use Firebase; explicit demo builds stay labelled and isolated. Install on a connected iPhone with `apps/flutter/tool/run-ios.sh` (needs Flutter and CocoaPods on the Mac); see `docs/IOS-FIREBASE.md`. Add `android` with `flutter create --platforms` when that target starts. Ported screen by screen from `apps/ios/`; read `docs/FLUTTER.md` before changing them.
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

- Owner design lock: preserve current staging screen composition, components, typography, palette and assets. Wire actual data/handlers into the existing Customer and Captain screens. Do not introduce generic Firebase replacement screens, guessed layouts or the deliberately removed payment banner. Backend mode isolation is still required. Current implementation and outstanding gates: `docs/FUNCTIONALITY-2026-10-26.md`.

- The active iOS design system is in `apps/ios/Shared/DesignSystem/`. Since 25 Oct 2026 the Flutter colours follow the WashKrew logo: primary blue `#0049FF`, heading charcoal `#22282D` (tokens in `apps/flutter/packages/washkrew_ui/lib/src/tokens.dart`; the SwiftUI reference still has the old `#3160FF` / `#172231`), and canvas `#F6F9FD`.
- One primary action per app screen. Green is reserved for pay, approve or accept; red is for errors and destructive actions.
- One small decision per screen in the booking flow.
- Payment screens explain that money is held and released after approval.
- Colour is never the only signal; use an icon and a word. Touch targets are at least 48 px (64 for washer controls).
- Undecided business values stay as configuration and placeholders, never invented prices or promises.
- The apps keep their phone layout on every screen size: on laptops the phone screen is centred with grey on both sides, never re-laid out for wide screens. On the web, every swipe has a visible control instead (see `docs/FLUTTER.md`).
- The landing page is prelaunch. Do not imply app downloads or live booking are available before those services exist.

## Current implementation

Normal Flutter Customer/Captain builds use the deployed Firebase controllers; server payments remain test mode. Only explicit demo builds and the SwiftUI reference use sample data and fixed demo codes; those must never reach production controllers. The in-app demo Screens gallery is a design reference, not integration acceptance. The Next.js/Neon/Better Auth commands and `/api/health` belong to the historical web stack. See the current owner handoff above before resuming any older migration instructions.

## Connecting the backend

- Before connecting any backend service, read `docs/BACKEND-HOOKUP.md` and show it to Aman. Add a line there whenever a new screen fakes data, a timer or a test button.

## Keeping the apps consistent

- Development happens in Flutter (`apps/flutter/`). Every app change must land in Flutter in the same task. If a change is made in the SwiftUI reference (`apps/ios/`), port it to Flutter before committing, so the two never drift. Update `docs/FLUTTER.md` (status and decisions) and `docs/BACKEND-HOOKUP.md` (anything faked) with it.

## Git

- Commit every change you make before finishing a task, so no work is left uncommitted. Commit on the branch you are working on and do not push unless asked.
