# Live-payment request follow-up — 28 October 2026

[LIVE-PAYMENTS-2026-10-28.md](LIVE-PAYMENTS-2026-10-28.md) records the owner's
new live-payment instruction and clarified ban on the credit-card checkout
option only; UPI stays allowed. Shared native/web checkout now filters debit
cards, uses a server-pinned gateway configuration and handles unsupported
captured payments through cancellation/full refund. Existing row/state components
are retained. Tests/analyzers passed, both release web apps are published and the
final Customer wording was rebuilt successfully. Owner authentication, Functions
deployment and HTTP gateway setup succeeded. New bookings now use live/WashKrew
with `no-credit-card-checkout` and saved default `config_TtDpJ7HJM4hHb2`.
Historical bookings keep their original merchant/mode. No actual live charge or
refund was performed. There are zero approved Captains, and photo services remain
test-gated pending physical/operational acceptance; native Mac/device checks and
approved content remain required. This status supersedes older test-mode notes.

# Private Captain review and merchant follow-up — 28 October 2026

[ADMIN-MERCHANT-2026-10-28.md](ADMIN-MERCHANT-2026-10-28.md) records the separate
admin page, approved Google reviewers, actual correction/approval notifications
and waiting-state recovery in Flutter, and the separate WashKrew live credentials
and webhook with historical merchant-safe payment/refund routing. Both release
web builds and Captain analysis/tests passed and are published. Customer/Captain
staging composition/styles/assets are unchanged. Server payments remain test;
new-merchant live acceptance, approved content and physical iPhone checks remain.

# Booking and Captain preference follow-up — 27 October 2026

See [AVAILABILITY-2026-10-27.md](AVAILABILITY-2026-10-27.md) for the integration of
Aman's `af036f0` UI changes: exact 4 AM–10 PM work periods, matching test booking
windows, C12 capacity refresh, persisted all-day/multiple selections, truthful
server approval, missing-upload errors and SMS-verified current-app-only deletion.
The staging components and assets are preserved. Both updated native apps need a
Mac rebuild/device pass; server payments remain test. No iOS project or Pod lock
was changed in this follow-up.

# Software readiness update — 27 October 2026

**Current continuation:** use [CLAUDE-MAC-CONTINUATION-2026-10-27.md](CLAUDE-MAC-CONTINUATION-2026-10-27.md) and its PDF in `output/pdf/`. Aman plans training design placeholders in the existing regions; they are not real video/training completion and are not added by this docs-only task. Aman is handling a separate WashKrew Razorpay account; migration/integration and new-merchant acceptance are pending. Preserve design and test mode while compiling/testing on the Mac.

The follow-up connects the existing map/video/microphone/photo controls to real Maps/Routes, server training and quiz progress, device speech and private photo checks. Existing screen composition and styling remain the staging design. The exact implementation, content publication steps and remaining provider/Mac boundaries are in [READINESS-2026-10-27.md](READINESS-2026-10-27.md). Payments remain test mode. Aman will supply approved training, support and policy content.

The native dependencies added are Google Maps (both app locks) and speech recognition (Captain). Existing AppDelegate source installs the Maps runtime-key channel, and Captain's Info.plist includes the speech-use description. No Xcode project, signing, Podfile or Mac-resolved Podfile.lock was rewritten on Windows. The Mac preparation command must install the added pods before compiling.

Final verification: 89 backend/rules tests, 24 Flutter tests, 3 actual model tests, both release web builds and all app/shared/tool analyses passed. Local browser accounts restored; the real map rendered and its dragged pin persisted. Live captions no longer promise unconnected messaging or a midnight payout. See [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md) for provider/fixture boundaries. No physical iPhone build is claimed.

# Current integration update — 26 October 2026

The functionality pass preserves staging `c1ad2b2` screen composition and native project changes. Existing controls now connect phone/profile/settings persistence, recorded playback, vehicle help, problem evidence, server deadlines, private downloads and operator decision/payout records. See [FUNCTIONALITY-2026-10-26.md](FUNCTIONALITY-2026-10-26.md) for checks and precise remaining gates. No generic Firebase screen or removed payment banner was restored; merchant mode remains test. Training and external accounts remain pending at the owner's request.

Mac handoff preparation now uses `tool/ios.dart` through the existing Bash commands, with no Node requirement. It validates both native app configurations, checks Xcode/iOS SDK/CocoaPods, regenerates local Flutter files, restores locked Dart packages, refreshes and checks native pods, supports preparation/unsigned compilation and refuses ambiguous physical-device selection or unknown flags. See [MAC-HANDOFF.md](MAC-HANDOFF.md). Native emulator startup now validates the demo project before Firebase initialization and uses that demo configuration rather than the registered production iOS options. No Xcode project/signing file was edited on Windows; Mac-resolved pod locks and Apple signing/APNs still need the native build.

Handoff verification on Windows, 25 October: Customer, Captain and shared Firebase analyses passed; all 8 Customer tests and 10 shared Firebase tests passed; both clean release web builds passed. Standalone iOS tooling checks covered both app configurations, explicit demo selection, ambiguous/missing/simulator device rejection and incomplete native pod detection; Dart analysis and Bash syntax checks passed. An attempted iPhone build on Windows correctly stops before running native commands. Xcode compilation and device acceptance are not claimed by these results.

The staging integration combines the WashKrew rename/logo/palette with the native Firebase, camera/media, notification and payment-mode work below. Shared package paths and native tests use `washkrew_firebase` / `washkrew_ui`; runtime and service class names follow the rename. The iOS bundle IDs, Firebase project, stored payment modes and explicit `WHEELIO_DEMO` flag are preserved. Default iPhone builds still use Firebase, and explicit demo builds retain their label on phones as well as web. No additional deployment or live-payment activation is part of this Git merge.

Merge verification on 25 October: all four Flutter analyses passed, all 57 backend/rules/payment/notification emulator tests passed, all 8 Customer tests and 5 shared native-login/checkout tests passed, and both release web builds passed. Xcode/device acceptance remains pending on the Mac.

The native integration started from `staging` at `9e49461`; the 25 October merge incorporates the branding work through `31fa906`. Flutter iPhone builds now select real Firebase by default, with native OTP, Razorpay checkout, real camera/library capture, private recorded notes/video, server-backed address checks, multiple booking windows, mode-separated wallets, cancellation restoration, Captain work-hour preferences and future-job handling. Private support tickets and notification inbox/FCM integration were added. Explicit demo builds remain labelled and isolated.

Firebase iOS apps were registered for the existing Customer/Captain bundle IDs. Native options and Auth return schemes are committed. No raw Xcode project changes or Android platform generation were performed. The owner will build and test on their Mac; Windows cannot confirm Xcode signing, physical camera, UPI app switching, GPS or APNs delivery. Read [IOS-FIREBASE.md](IOS-FIREBASE.md) for build commands, acceptance steps and precise remaining setup.

On 25 October merchant OTP verification completed and the WashKrew website moved to **Under review** in Razorpay (24–48 hours shown). The owner-approved live webhook is enabled for the three payment/refund events. The existing live key pair was recovered securely from an owner-provided document, matched to this merchant and authenticated without creating a payment. The payment functions were redeployed with the live pair; archived test credentials still handle test bookings/refunds, and the server booking mode remains **test**. Trustkeyper's credentials, primary website, brand, webhooks and Route setup were preserved. The WashKrew-branded Customer/Captain web build was published to Firebase Hosting. See [LIVE-LAUNCH.md](LIVE-LAUNCH.md) for the remaining launch gates. Cancellation terms stay server-configured; no new commercial policy, trip fee or payout was invented.

Deployment checks confirmed seven active payment functions using the new live secret versions, authenticated live/test providers, both webhook signature checks, and 25 protected operations rejecting anonymous access. The original test webhook remains present. The two notification handlers were also deployed with WashKrew wording. Both hosted app startups and the Customer catalog load without console warnings/errors and retain the test-payment label.

The payment-mode follow-up archives verified test credentials in Secret Manager, routes historical payment/refund checks by each booking's mode, and provides a separate signed live-webhook endpoint without enabling real charges. Test capacity keeps its historical keys and cannot consume live slots. Orders/offers/earnings retain explicit test labels; legacy earnings default to test. Cancelled checkout outcomes now open the server cancellation/refund details, including after Check again.

# Flutter apps (Customer and Captain)

> Summary of everything that changed on 23–24 Oct 2026 for engineers: `docs/CHANGES-2026-10-24.md`.

## 25 October 2026: real-data apps use the designed screens

Aman's decision: the Firebase (real-data) builds must look exactly like the design reference (staging `31fa906`). Customer: every route uses the designed screen again; `FirebaseOrderScreen`, `FirebaseAccountHelp` and the plain live profile were removed, and `_OpenOrder` (main.dart) opens a booking by id. Real photos appear in the designed photo boxes through `DesignPhoto` (washkrew_firebase) and `WPhotoSlot(image:)`. Ajay's real-data wording variants were replaced by the designed wording. Anything the backend cannot do yet stays on screen as designed and is listed for Ajay as P0 in `docs/P0-BACKEND-FOR-DESIGN.md`; tapping it shows a toast instead of faking success (`AppStore.blockLive`). Captain follows the same rule: `FirebaseCaptainScreen` was removed and `CaptainStore(live:)` (data/store.dart, "Live data" section) fills the designed Captain screens from Firebase — SMS sign-up/login, KYC uploads and application, Online/Offline with a 60 s heartbeat, server offers in the designed job alert (claim/reject), arrival, before/after evidence photos, start/finish, today's and later jobs, earnings, "When I work" and the inbox (`CaptainStore.blockLive` for designed actions without a backend).

## 25 October 2026: no payment-mode banner

Aman's decision: the apps never show a payment-mode banner ("TEST PAYMENTS · No real money is charged" or any live/test equivalent), at any time, because it broke the top spacing (it added its own safe-area band and pushed every screen down). `PaymentEnvironmentLabel` was removed from `washkrew_firebase` and from both apps' `builder`. The server's `paymentMode` still decides test or live payments; only the on-screen label is gone. Do not add it back.

## 27 October 2026: UI-only changes (Aman)

Aman's UI changes on staging `752e222`, with no backend changes. The running list for Ajay, with what each item needs connected, is [CHANGES-2026-10-27-UI.md](CHANGES-2026-10-27-UI.md).

- Captain Me tab: **Delete account** under Log out opens the C53 dialog, now shared as `showDeleteAccountDialog` in `washkrew_ui` (captain-size buttons, Hindi/Telugu text). The sample app deletes and logs out; real data shows "This isn’t available yet" until Ajay connects it. The Customer profile already had C53 and is unchanged.
- Captain W05 Aadhaar: "Upload Aadhaar photo" (no "instead") opens a camera/gallery sheet, then shows "Checking your photo" on the real image (at least ~2 s), then "Photo is clear" (Continue) or W05b with the real photo and reason. Clear or not comes from the on-phone `checkPhotoQuality`; real data still uploads with `liveUploadKyc`.
- Testing: the orange "TEST ONLY · Skip onboarding" pill became a small "Skip this step (testing)" text link on every onboarding stage. It skips one stage at a time, in the sample and real-data apps (real data: kept on the phone in `testSkipped`, not sent to the server). Turn `onboardingSkip` off before launch.
- Captain Rules "I agree" (real data): with test-skipped stages it doesn't submit (toast, then W13); without both KYC photos it says "Upload your Aadhaar and selfie first." and returns to the steps. W13 has the test skip link to W14. The server's missing-photo 404 crash ("INTERNAL") is for Ajay.
- Decision (Aman, 27 Oct): no review-call round. W13 "Get ready" (`UnderReviewScreen`, `N.underReview`) is removed. Rules "I agree" → W14 "You're in" → Home. Approved: online automatically (`goOnlineAfterApproval`). Not approved: "Your profile is under review" pop-up (`showReviewNotice`) with a 30-minute countdown from `submittedAt`, then a "Call our team" button. Preview: gallery W14r.
- Testing: "Skip 30 min (testing)" on that pop-up approves on the phone only (`testApproved`) and goes online locally; no server online call or heartbeat while only test-approved. Off with `onboardingSkip`.
- First-time work profile (Aman, 27 Oct): Rules "I agree" → `WorkAreaScreen(setup: true)` (`N.workSetup`): "Which jobs should ring?" then "When do you work?", one per screen → W14 → Home, where `_ProfileShrink` shrinks the answers into the "Jobs from" chip (then glow, then the review pop-up). Later edits use the chip / Where I work. Gallery W12w.
- Update (Aman, 27 Oct): the two questions slide left→right (like the progress fill; reverse on back). "When do you work?" is `WorkSlotsEditor`: start–end range sliders (6 AM–9 PM, 30 min) with "Add more time" for breaks, in both onboarding and Where I work. `workSlots` replaces `WorkTime`; saved to the server as every 6–10/10–14/14–18 window the slots touch. W14 "You're in" is removed: Done → `playWorkProfileLanding` (full-screen summary shrinks into the chip) → Home.
- Working-time card: 4 AM – 10 PM. `_SkyArc` above the slider: sun/moon glyphs ride a day arc at the start and end, coloured segment, sky tint by time of day, haptic tick per step.

## 25 October 2026: renamed to WashKrew, new logo

- **Palette aligned to the logo.** `WColor.primary` #3160FF → #0049FF (solid end of the logo gradient), `primaryStrong` → #003BD1, `heading` #172231 → #22282D (logo charcoal), `body` → #363D44, `secondary` → #5F6870, `placeholder` → #80878E, `muted` → #9CA2A8, `inverse` and scrim/shadow base → #22282D. Surfaces, borders, success, error and wait colours unchanged. Contrast improves: primary 6.2:1 on white and 5.4:1 on `primaryTint`, so blue text on pale blue now passes AA. PWA `theme_color` → #0049FF.
- Product and company renamed from Wheelio to **WashKrew** (website washkrew.com, tagline "Vehicle cleaning, on demand"). `Brand.name`, `Brand.captainApp`, `Brand.tagline`, `Brand.website` in `washkrew_ui/lib/src/tokens.dart` carry it; every user-facing literal now uses them (portal, live screens, Razorpay checkout name, error messages, loading text).
- New `WLogo` widget (`washkrew_ui/lib/src/brand.dart`): `lockup` (hero, with tagline), `wordmark` (no tagline), `mark` (door only), each with an `onDark` version. PNGs at 1x/2x/3x in `washkrew_ui/lib/brand/`, rendered from the SVG masters in `/brand`.
- Replaced the old blue-square ring mark: Customer `BrandMark` (home header, business-chat avatar), Customer splash (now white with the hero logo, matching the iPhone launch screen), Captain language screen, Captain live header (was the text "wheelio."), prelaunch portal logo.
- App icons: Customer = door mark on white; Captain = white door mark on charcoal #22282D. iPhone launch image = hero logo, 240 pt wide. Web: favicon.png + new favicon.svg, PWA icons, titles, manifest names; captain description no longer says "washers".
- iOS display names: "WashKrew" and "WashKrew Captain" (the home screen may shorten the second).
- Not renamed on purpose: package names (`washkrew_ui`, `washkrew_firebase`, `washkrew_customer`, `washkrew_captain`), Dart class names (`WashKrewRuntime`...), `WHEELIO_DEMO`, bundle IDs `com.amanmaheshwari.wheelio.*`, Firebase project `wheelio-apps`, repo and folder names. Changing those needs new App Store Connect and Firebase registrations.
- The SwiftUI reference (`apps/ios/`), `apps/web` and `apps/hosting` still show WashKrew; they are not the launch target.

## Verification and publication — 24 October 2026

- All **57** backend, security-rule, payment-adapter and notification tests passed in the local Firebase emulators. **8** Customer tests and **5** shared native login/checkout tests passed. The additions cover cutover with historical test captures/refunds, independent capacity, wrong-mode events, shared-merchant isolation and cancelled-checkout navigation.
- `flutter analyze` passed with no issues for Customer, Captain, `wheelio_firebase` and `wheelio_ui`. Both release web builds passed. Both iOS plist files and shell-script syntax were checked; these checks do not compile an iPhone binary.
- Firebase rules/indexes and backend code were published, including the scheduled booking-expiry update. Initial CLI IAM setup for the eight new callables hit the existing organization restriction. The documented `configure-api-access` operation completed without changing that policy; all eight endpoints then returned authenticated-service `401 UNAUTHENTICATED` responses to anonymous requests. Test Razorpay authentication and signed/invalid webhook checks passed, with no payment created.
- Firebase Hosting was published for Customer and Captain. Customer startup and server catalog rendered in the browser without console errors. Native hardware and Apple push acceptance remain pending on the owner's Mac.
- The payment-mode follow-up was also published to Functions and Hosting. All 25 protected callables rejected anonymous calls with `401 UNAUTHENTICATED`; public availability returned `200`. Both test and separate live webhook endpoints accepted signed no-op setup events (`200`) and rejected invalid signatures (`401`). The API gateway configuration completed with the organization policy unchanged. Razorpay authenticated in test mode; no payment or booking was created by these deployment checks. Both hosted app startups rendered with no console warnings/errors. Live merchant registration and OTP verification remain pending.

## 24 October 2026: Captain app follows the new customer features

- **Owner cancels:** the job stays in Today's plan, struck through, with "Cancelled by owner" (or "Cancelled · trip paid" if the captain had set off, who then gets the trip fee). The next job becomes current. Notification is short; no explanation of customer credits. (`CaptainStore.ownerCancels`, `_cancelledCard`)
- **Several windows / any time:** cards show the owner's windows ("10–12, 16–18"). Any-time jobs are placed by the app in the window closest to the captain's other jobs in the same building (else the first free window ahead) and carry a green **Flexible** tag. (`fitFlexible`, `_FlexTag`)
- **When I work:** Where I work now has 6–10 AM / 10 AM–2 PM / 2–6 PM chips. They only decide which jobs ring (flexible jobs always can); the captain still accepts or rejects each. (`workTimes`, `wantsJob`)
- **Later-day jobs:** not on Home's plan; listed under **Coming up** in the Jobs tab, and move to the plan when their day starts. (`todayJobs`, `laterJobs`, `Job.day`)
- **Address typed by the owner:** **New address** tag with the pincode, plus **Get directions** (Google Maps) on Go to vehicle. No checking step.
- **Plates:** shown tidied everywhere (`Fmt.plate`: "ts09ea4521" → "TS 09 EA 4521"); the customer app saves plates the same way.
- Free washes and credit don't show in the Captain app: pay is always the normal job pay.


- Captain welcome (W00) now uses the same carousel as the Customer welcome: `PageView` with swipe, dots that follow the scroll (`CarouselDots`, moved into `washkrew_ui`), fixed Back / Next / Skip.

- Cancelling (sample app): "Cancel booking" on the Home "Upcoming" card, the Bookings list and the order screen, until the wash starts. No cash refund. Within 15 minutes of booking: 1 free wash. After that: 50% of the booking's value as credit (`Customer.credit`, rupees). Cards show only "Cancel booking"; the sheet states the outcome in one line before confirming ("You get 1 free wash" / "You get ₹75 credit · 50% of ₹149"). After cancelling: toast, notification, a "Booking cancelled" screen, a Home banner for the credit, and the order moves to Past.
- Credit at checkout: shown only when the customer has credit, as a green card ("₹75 credit · ₹75 off. You pay ₹74.") with a switch, on by default; the total and the amount held use the reduced price. Not combined with a free wash.
- Free wash at checkout: shown only when the customer has one, as a green card ("You have 1 free wash · Used for this booking. You pay ₹0.") with a switch, on by default. With it on, the button reads "Book with free wash" and skips the payment sheet.
- Upcoming bookings for a later slot show "Booked" (not "Searching"/"Check photos"), and their screen shows the booking, only the customer's own photos, and the cancel link. The demo lifecycle no longer runs ahead to captain/wash/photos before the slot.

- Time slot (C12): people can pick several windows, or tap **Any time of the day** to pick every open window at once (tap again to clear). Joined windows read as one ("10 AM – 2 PM"); the review shows e.g. "Today, Any time (10 AM – 6 PM)". Sample-data app only for now; the live app keeps one window (see BACKEND-HOOKUP.md).

- "Enter address by hand" on the address search (C09c) now opens C09d **Type your address**: society or building name (pre-filled from the search text), area, pincode (6 digits, number keypad) and city (Hyderabad by default). Next is enabled once all four are filled. It continues to Floor and slot (C10), which then also asks for the tower and starts with no floor picked. Gallery entry C09d.
- Text fields' footers (Next) now ride above the keyboard on every screen (`WScreen`).

## 23 October 2026: iOS platform added

- `customer/ios` and `captain/ios` were generated with `flutter create --platforms=ios` (Flutter 3.38.6). Bundle IDs `com.amanmaheshwari.wheelio.customer` / `.captain` match the SwiftUI apps, so a phone install replaces them; team `8CCQQM7TP3`; iOS 15+ (Firebase); portrait only on iPhone; camera, photos, microphone and location texts in `Info.plist`.
- Xcode's Run uses the Release configuration for both Runner schemes, so an app installed from Xcode keeps opening from the home screen after Xcode disconnects (Flutter debug builds don't). For hot reload, use `flutter run -d <iPhone> --dart-define=WHEELIO_DEMO=true` in Terminal instead.
- The yellow DEMO strip is shown only on the web; phone builds hide it.
- Phone builds use sample data: `--dart-define=WHEELIO_DEMO=true` does what `?demo=true` does on the web. `tool/run-ios.sh` builds and installs both apps on a connected iPhone.
- Live Firebase on phones is not wired yet (iOS Firebase apps, native phone sign-in, native Razorpay); see "Native iPhone builds" in `BACKEND-HOOKUP.md`.

## 22 October 2026: browser acceptance fixes

Captain application uploads now restore from private Storage metadata after refresh, and submission requires the three documents, a society and a valid UPI ID. Account switches clear application state. Pending location permission requests time out instead of locking wash controls. Arrival is visible to Customer, and dry-dusting review uses the selected wash description. Accept uses the green action style and Captain job navigation has an accessible back label.

All 39 backend/rules/payment-adapter tests, 4 Customer tests and the Customer, Captain and shared Firebase analyses passed. Completed browser acceptance, fixture boundaries and release checks are recorded in [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md). iOS and Android remain deferred.

The final acceptance also fixed hidden unpaid bookings: both unpaid and unconfirmed states remain in Upcoming, display payment not confirmed, and reopen the same checkout. Repeat booking no longer promises WhatsApp gate-pass handling or invents a voice note when none exists; Customer photos are labelled optional. Both production web builds, Hosting and the changed payment/refund Functions deployed on 22 October. Approval/rating, earnings, persisted sessions, delayed payment reconciliation, dispute holds and both actual test refunds passed. The initially rejected netbanking refund processed in full after a virtual test balance payment. Customer now distinguishes delayed/review refunds from provider-accepted and processed refunds, and can safely check an existing refund's status. Physical GPS and merchant live cutover remain future checks.

## 21 October 2026: Firebase booking implementation

Both release web bundles and the Customer, Captain and shared Firebase package analyses passed. The first hosted review caught blank Captain name/mobile inputs: shared `WTextField` now uses its label as the hint when no separate placeholder is supplied. This keeps the existing design and makes empty fields identifiable in both apps.

The Firebase release build now runs a clean build and validates generated Functions, Storage and location web registrations. A cached prelaunch registry had routed callable requests through a native codec, producing `Int64 accessor not supported by dart2js` on web. The rebuilt hosted Customer draft now calls availability successfully; errors provide Retry, stale errors clear when changing dates, and the empty-capacity explanation appears above the disabled slots. No captain availability is simulated to unblock checkout.

The Customer booking steps now use Firebase phone OTP, a server catalog and capacity, Razorpay checkout, saved orders and private uploaded photos. Live booking details subscribe to assignment/wash/refund states, protected before/after photos and optional captain coordinates. The Captain app uses the existing WashKrew screen components for real phone accounts, private applications, offers, atomic acceptance, arrival, before/after uploads, wash stages and earnings. The full original screen gallery remains isolated behind `?demo=true`.

The owner confirmed real SMS delivery on 21 October and showed the Customer name screen after OTP verification. At their request the existing name was saved in their Chrome session; the signed-in Profile page confirmed account completion. Test-payment browser acceptance was completed on 21–22 October, with fixture boundaries recorded in WEB-ACCEPTANCE.md.

Trustkeyper billing and its stored **test** Razorpay credentials are reused. Live charges require live merchant keys; actual captains require operator approval. No demo lifecycle timer, sample OTP, fake KYC decision or invented payout runs in the live controllers. See [FIREBASE-BOOKINGS.md](FIREBASE-BOOKINGS.md) for the server model, test settings, release commands and remaining human operations. Native platform work remains deferred.

The 20 October entry below describes the earlier deployed prelaunch foundation.

## 20 October 2026: Firebase web foundation

Both `main.dart` entry points now start the shared `washkrew_firebase` package. Normal URLs open a real prelaunch app: email/password login and reset, saved profiles, customer wash requests/history/cancellation, and Captain applications. Firebase rules enforce per-account access and prevent client-side payment, job-state and KYC approval changes.

The complete previous design experiences are preserved behind **`?demo=true`** with a persistent "DEMO · Sample data · No bookings or payments" strip. No sample data or hardcoded OTP is used in the live portal. This is an initial request/application release; the entire designed paid-wash lifecycle is not connected yet.

`apps/hosting/` and both Flutter builds package into `build/firebase-hosting/`. Firebase Hosting serves `/`, `/app/` and `/captain/`. Project: `wheelio-apps`, owner account: `ajay@trustkeyper.com`, Firestore: Mumbai (`asia-south1`). See [FIREBASE.md](FIREBASE.md) for commands. iOS/Android platform generation and signing remain future steps; the new backend code is in Flutter and reusable there.

The entries below describe the earlier demo implementation and historical status.

Decided on 15 October 2026: both WashKrew apps, Customer and Captain (washer), are built in Flutter from one codebase. The release order is:

1. **Web**: the first launch target, available now as a build.
2. **iOS**: later, from the same code.
3. **Android**: after iOS, from the same code.

**All development happens in Flutter.** The Flutter apps are ports of the SwiftUI apps in `apps/ios/`. They have the same screens, states, copy (English, Hindi and Telugu for Captain), interactions, sample data and Screens gallery. The SwiftUI apps remain the design reference until the Flutter apps ship on iOS.

**Keeping them consistent:** every app change lands in Flutter in the same task. If something is changed in the SwiftUI reference first, it is ported to Flutter before it is committed. Anything a screen fakes (demo data, timers, test buttons) goes on the list in [BACKEND-HOOKUP.md](BACKEND-HOOKUP.md).

## Where the code lives

```text
apps/flutter/
├── packages/washkrew_ui/   # Shared design system and app shell
│   └── lib/src/
│       ├── tokens.dart       # Colours, type scale, spacing, radii (from apps/ios/Shared/DesignSystem)
│       ├── icons.dart        # SF Symbol names mapped to Material icons
│       ├── components.dart   # Buttons, fields, cards, banners, sheets, alerts, pager…
│       ├── nav.dart          # Path-based navigation stack (like SwiftUI NavigationStack)
│       ├── phone_frame.dart  # The phone frame on laptops (see below)
│       ├── device*.dart      # Sound, notifications, voice, photos and calls; web and phone versions
│       └── fonts/            # Bundled Roboto
├── customer/              # Customer app (C01–C55)
│   └── lib/{main.dart, data/, screens/}
├── captain/               # Captain app (W00–W57)
│   └── lib/{main.dart, data/, screens/}
└── tool/serve.mjs         # Small static server for local previews
```

Each app keeps its state in one `ChangeNotifier` store (`data/store.dart`) and a router that holds the screen path. The store and router are passed down through an `InheritedNotifier` (`AppScope` / `CaptainScope`), and screens read them with `context.store` and `context.router`. File names follow the iOS files, so a Swift screen and its Flutter port are easy to find side by side.

## Decision: one design on every screen size

The apps are **not** redesigned for large screens. On a laptop or desktop, the phone layout sits in the middle of the window and the space on either side is grey. On a phone, the app fills the screen. The web app and the mobile apps therefore look the same.

`PhoneFrame` (in `washkrew_ui`) handles this for both apps:

| Window width | What you see |
|---|---|
| Wider than 600 px | Grey surround (`#D9DEE6`). The phone screen is centred: 390 px wide, as tall as the window minus 48 px (between 560 and 844 px), with 36 px rounded corners and a soft shadow. |
| 600 px or narrower | Full screen, with the device's safe areas. |

Reasons:

- Customers and captains mostly use phones. The laptop view is for demos, reviews and the occasional desktop user.
- With one layout, every screen is designed, tested and kept up to date once, not once per screen size.
- The web launch shows exactly what the iOS and Android apps will show later.

Screens with a lot of content (for example, the job alert with three stacked jobs) scroll inside the frame, so the main actions stay in view on short laptop screens.

## Decision: swipes on the web

A mouse can't swipe comfortably, so each swipe has a visible control on the web instead. Native iOS and Android builds keep the swipes. The check is Flutter's `kIsWeb`, so phone browsers get the web controls too. That keeps the web behaviour the same on every device.

| Where | Phone gesture (iOS / future native) | Web replacement |
|---|---|---|
| Captain · new job alert (W22) | Swipe the top job either way to see the next one | **See next job →** button under the stack. Reject does the same, and the hint text changes to match. |
| Captain · owner's vehicle photos | Swipe between photos | ‹ › arrows on the photo and tappable dots |
| Customer · before/after photo compare (C26) | Swipe between photos | ‹ › arrows and tappable dots |
| Both · notification list | Press and hold a message for Mark read/unread and Delete | **⋯** button on each message opens the same menu. Right-click also works. The help line under the list says "Use ⋯…" |
| Both · in-app notification banner | Swipe up to dismiss | **×** button on the banner (it still closes itself after a few seconds) |
| Both · long-press actions (for example, remove profile photo) | Press and hold | Right-click, or press and hold |

These stay the same on the web because a mouse can do them: dragging the map pin, dragging the before/after slider (a tap also works), and the Customer welcome slides: a `PageView` carousel where picture and words move together under a finger or mouse drag, the dots follow the scroll position (the wide pill slides between dots), and Back, Next and Skip stay fixed (24 Oct 2026).

## Other web differences

These do not change the design, but each uses the browser's version of the feature (`device_web.dart`):

- **Calls** (support, owner): on a phone browser, the dialler opens with `tel:`. On a laptop, a short message shows the number instead: "Calls work on your phone: …".
- **Notifications**: the browser Notification API, after the user allows it. When they are blocked, the Captain app says "browser settings" instead of "iPhone Settings".
- **Owner's voice note** (Captain): read aloud with the browser's speech voice in the captain's language until real recordings exist.
- **Job ring**: a short Web Audio tone. There is no vibration on laptops.
- **Photos** (profile, problem reports): the browser's file or camera picker. The guided wash camera remains a demo screen, as it is in the iOS sample.

## Commands

Flutter 3.38 / Dart 3.10 is installed at `~/development/flutter` (add `~/development/flutter/bin` to `PATH`). From `apps/flutter/customer` or `apps/flutter/captain`:

```sh
flutter pub get
flutter analyze
flutter run -d chrome
flutter build web --release --pwa-strategy=none
```

`--pwa-strategy=none` leaves out Flutter's offline service worker, so testers always load the latest build instead of a cached one.

To preview a release build locally from the repository root (these are also in `.claude/launch.json` as `flutter-customer` and `flutter-captain`):

```sh
node apps/flutter/tool/serve.mjs apps/flutter/customer/build/web 8081
node apps/flutter/tool/serve.mjs apps/flutter/captain/build/web 8082
```

The build output in `build/web` is a static site. It can be hosted on any static host, such as Cloudflare static assets next to the Next.js site. It has not been deployed yet.

### Adding iOS and Android later

Each app currently has only the `web` platform folder. When it's time for the next target, run this in each app folder:

```sh
flutter create --platforms ios,android --org <reverse-domain> .
```

This adds `ios/` and `android/` without touching `lib/`. iOS builds also need Xcode and CocoaPods, which is not installed yet. Native code paths are already in place: `device_stub.dart` is used off the web, and the swipes come back automatically because `kIsWeb` is false. The remaining native work is real phone services: push notifications, haptics, the camera and the owner's recorded audio.

## Features added on 16 October 2026

These were built in the SwiftUI reference and then ported to Flutter, so both apps match:

**Captain**
- **Today's plan countdowns.** As soon as a job's time window opens, its card shows a live timer chip and a progress bar: blue with "Finish by …" while there's time, amber with "Hurry up" at 30 minutes left, "Not started! Go now" at 25 minutes left (if the captain hasn't started), and red "Late mm:ss · −₹1 every late minute" once the window is over. Urgent cards shake once, and the timeline dot gets a ripple.
- **Plan alerts.** Window opened ("Time to start"), 25 minutes left and not started, and running late are sent as notifications (in-app banner or browser notification). Tapping one opens that job.
- **Demo plan clock.** The demo day starts at 9:29:20 AM, so the current job is about 30 minutes from its end and the next job's window opens about 40 seconds after launch. A **TEST +5 min** button (test only, `planClockTest`) jumps ahead to show each state.
- **Job alert.** 60 seconds to decide, shown as a "Decide in" bar inside each card. When time runs out, the card stays greyed out with an "Opportunity missed" band for 30 seconds, and Accept is disabled. A **Go offline** pill in the header stops new jobs.
- **Code screen.** A pencil next to the number goes back to fix it (the number keypad opens). Resend unlocks after 15 seconds, with at most 3 resends, then "try again after 10 minutes".

**Customer**
- **First-time Home hidden.** New customers go straight to "What are we washing?". The old first-time Home is kept behind `DesignFlags.firstWashHome` (see [hidden-designs.md](hidden-designs.md)), and gallery **C40h** previews it.
- **Message for the captain (C11) redesigned.** Record a video or a voice note (one of the two), and optionally write text as well. Gallery entries C11, C11v and C11d show each state.
- **Walk-around video** tile now carries an "OPTIONAL" tag.
- **Welcome:** three timed slides ("Wake up to a clean car", "See it, then pay", "Your weekend is yours").

## Status

- 16 Oct 2026: Customer and Captain both pass `flutter analyze` with no issues and build for the web. The features above were checked in the browser: plan timers in every state with their alerts, and the job alert's missed state.
- Both run on sample data, as the iOS apps do. Demo login code: 123456 (000000 is expired). The **Screens** tab on the left edge opens every designed screen and edge state. In Captain, **Step through all screens** walks the gallery with ‹ › controls.
- Checked in the browser at laptop size (phone frame) and 375 px (full screen):
  - Captain: language → welcome → guest Home, a stacked job alert with See next job and Accept, the day plan, Go to vehicle, the owner's note, face check, the guided camera and washing.
  - Customer: welcome → Home → booking (vehicle type), and Check and pay with the payment sheet.
- Not connected yet: Neon / Better Auth API, payments, push and real photo upload. Screens call the store, and the store is where backend calls go (see `backend/API-CONTRACT.md`).
- The React ports at `apps/web` `/app` and `/captain` came first and are now superseded by these Flutter apps as the launch target. They stay until the Flutter web build is deployed, then can be removed.
- `legacy/` holds an older, unfinished Flutter customer app from before the iOS apps. The new code does not use it.
