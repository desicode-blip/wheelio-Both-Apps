# WashKrew build status

## 20 Oct 2026: Firebase web foundation

- Cloned GitHub branch `dev` into `D:\WashKrew`. The owner selected Firebase project `wheelio-apps` under `ajay@trustkeyper.com`.
- Added a responsive landing page and shared Flutter Firebase portal for Customer/Captain, with real email auth, profiles, wash requests/cancellation/history and Captain applications.
- Kept all existing design screens behind an explicit `?demo=true` URL and a persistent demo label. Live mode has no sample records or fake payments/jobs.
- Added Firebase Hosting packaging, Firestore rules/index, emulator configuration, app dependency locks, rules tests and a live smoke-test script. Twelve rules tests pass, and both Flutter release web builds compile.
- This is a prelaunch request/application release. Paid bookings, photo uploads, KYC, matching, tracking, push and payouts remain unfinished. iOS/Android native builds have not been generated or verified.
- Published to https://wheelio-apps.web.app/ with Customer at `/app/` and Captain at `/captain/`. Auth, Firestore rules/index and Hosting deployments succeeded. Live backend and browser flow checks passed; disposable QA accounts/data were removed. Analysis is clean in both apps and the shared Firebase package.
- See [FIREBASE.md](FIREBASE.md) for setup, scope, deployment, tests and next steps. Previous Neon/Cloudflare notes below are historical.

## 16 Oct 2026: iOS changes ported to Flutter; repository handed to engineering

- Development repository: https://github.com/desicode-blip/wheelio-Both-Apps, branch `dev`. **Development language: Flutter** (`apps/flutter/`).
- Ported the latest SwiftUI changes to Flutter so both match: Today's plan countdowns and plan alerts, 60-second job offers with the "Opportunity missed" state and Go offline, OTP resend timer and edit number, hidden first-time Home (design flag), the redesigned message-for-captain screen, the optional walk-around video tag and the 3-slide Customer welcome.
- New rule in `CLAUDE.md` / `AGENTS.md`: every app change lands in Flutter in the same task; SwiftUI is the reference and must not drift.
- Docs updated: [FLUTTER.md](FLUTTER.md), [BACKEND-HOOKUP.md](BACKEND-HOOKUP.md) (now maps each item to the Flutter file) and [hidden-designs.md](hidden-designs.md).

## 15 Oct 2026: Customer and Captain apps converted to Flutter

- Both apps are now Flutter apps in `apps/flutter/` (`customer/`, `captain/`, and the shared `packages/washkrew_ui`). Web is the first target, then iOS, then Android, all from the same code.
- They were ported screen by screen from the SwiftUI apps: every screen and state, the interactions, the sample data, the Screens gallery, and English/Hindi/Telugu copy in Captain.
- Decision: no large-screen redesign. On laptops, the phone screen is centred and the sides are grey; on phones, it fills the screen. On the web, swipes become visible controls (See next job, ‹ › arrows, ⋯ menus, × to dismiss). See [FLUTTER.md](FLUTTER.md).
- Verified: `flutter analyze` reports no issues and `flutter build web` succeeds for both apps. Captain and Customer were checked in the browser at laptop and phone sizes: the job alert stack, day plan, wash flow, booking and payment sheet. A layout fix keeps job-alert actions visible on short laptop screens.
- Not done: no deployment, no backend connection (sample data only), and no iOS/Android platform folders yet. The React ports at `/app` and `/captain` are superseded.

## 12 Oct 2026: live database migrated and web backend verified

- Ported the original application schema to Neon/Drizzle alongside Better Auth: 27 tables, four versioned migrations, PostGIS, constraints/indexes, policies, customer actions and initial configuration.
- Corrected free-credit reservation/return, low-rating update flags, live-society filtering and account deletion that previously violated vehicle/order foreign keys.
- Added migration hash/order verification, a read-only database integrity command, disposable-database integration tests, and database readiness checks in `/api/health`.
- Verified migration application and repeat runs on PostgreSQL 17/PostGIS; authentication, booking/credit/refund, ownership/RLS, payout/dispute and account-deletion tests passed. TypeScript and the production web build passed.
- Generated the missing local Better Auth secret, then applied all four migrations to the configured Neon database after credentials were supplied. Re-running migrations and the read-only integrity check passed. HTTP readiness returned 200, and registration/login/session/logout passed against live Neon; the test account was removed. No pre-existing Supabase data was transferred. Both iOS apps and external services remain unconnected. See [the migration guide](../backend/NEON-DATABASE.md).

## 11 Oct 2026: platform folders and website

- Active platform roots are `apps/web/`, `apps/ios/` and `apps/android/`.
- The website is a Next.js App Router landing page with TypeScript, existing WashKrew brand colours, local fonts and responsive layouts. Booking and app downloads are future work.
- `/app` and `/captain` are web ports of the iOS Customer and Captain apps (same screens, interactions, sample data and Screens gallery), shown in a phone frame on laptops and full screen on phones.
- Existing SwiftUI Customer and Captain apps moved together to `apps/ios/`. Shared schemes make both targets available in a fresh checkout. They still use sample data.
- Android is reserved with only `.gitkeep`; no Android implementation has been selected or generated.
- Earlier Flutter sources and their bootstrap script are preserved under `legacy/`. The entries below describe that earlier implementation and are historical, not the current development instructions.
- Root pnpm commands run the web app. See `README.md` for web setup and Xcode commands.

### Verified after restructuring

- Website TypeScript check and production build pass. The landing page returns HTTP 200; browser checks cover its links and layouts at 1280 px and 375 px with no horizontal overflow or browser warnings/errors.
- Customer and Captain both build for the iOS simulator from the new project path. Xcode is open on `apps/ios/Wheelio.xcodeproj` with both shared schemes recognized.
- Existing warnings about main-actor access to `profilePhoto` remain in Customer `SupportScreens.swift` and Captain `WAccountScreens.swift`; they do not fail the builds.
- All 79 tracked files relocated from the old iOS/Flutter folders were accounted for. App source, assets and the Xcode project contents are unchanged.

## 10 Oct 2026: customer app code written (no outside accounts used)

### Done

- **Design system** (`legacy/packages/wheelio_ui`): every token from the design read-me (colours, type scale, spacing, radius, control sizes) and the shared components, including buttons, header and progress, footer bar, bottom nav, fields, chips, OTP boxes, tabs, tiles, badges, banners, full-screen states, photo slots, list rows, status steps, sheets, dialogs and snackbars.
- **Customer app** (`legacy/apps/customer`): all 72 customer screens and states from the designs (C01–C55, CA1–CA4):
  - Booking flow: vehicle → plate → photos → place → floor → notes → time → login → pay → booked.
  - Live order: searching → on the way → washing → check photos → approve → rate.
  - Edge states: cancel before and after accept, no washer, washer late, gate pass missing, can't find vehicle, auto-approve, report problem, dispute upheld or rejected, damage, refund tracking.
  - Home, bookings, booking detail, repeat booking, vehicles, profile, delete account and help.
  - System states: offline, error, session expired, loading, and 200% text.
- **Runs without a server.** A sample backend acts like the real one: sample customer Ananya and washer Raju, live status changes every few seconds, failures on demand. The in-app **Screens** tab on the left edge opens any screen directly and has switches for every edge case. Demo login code: 123456.
- **Ready for Supabase.** The database schema has row-level security and server functions for create order, cancel, approve, rate, report problem, delete account, society search and available slots. The sample data and the API contract are written. The payment webhook and AI photo check (Claude vision) are written.
- **Unit tests** cover plate and phone rules, time labels, OTP, the full order lifecycle and cancel refunds.

### Not verified yet

Flutter isn't installed on this Mac, so the code hasn't been compiled or run. It was reviewed by hand and a few issues were fixed. Expect a short round of compile fixes on the first `flutter analyze`. Running `legacy/tool/bootstrap_customer.sh` after installing Flutter does this, and then the app can be checked screen by screen in the iPhone simulator.

### Waiting on you

See `CONNECT-LATER.md`. The steps that unblock the most are:

1. Install Flutter (say "install Flutter").
2. Create a Supabase project in the Mumbai region.
3. Start the Apple Developer (D-U-N-S) and DLT SMS registrations, because both take 1–2 weeks.

### Next for Claude once unblocked

1. Compile, fix, and run in the simulator. Check every screen against the designs.
2. Write `SupabaseBackend` and the real device features (camera, location, push).
3. Add Razorpay checkout and the `create-payment` function.
4. Run the Android customer build (CA1–CA4 are already handled in the same code).
5. Build the washer app (W01–W50) using the same design system.
