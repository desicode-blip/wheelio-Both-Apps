# Flutter apps (Customer and Captain)

## 23 October 2026: iOS platform added

- `customer/ios` and `captain/ios` were generated with `flutter create --platforms=ios` (Flutter 3.38.6). Bundle IDs `com.amanmaheshwari.wheelio.customer` / `.captain` match the SwiftUI apps, so a phone install replaces them; team `8CCQQM7TP3`; iOS 15+ (Firebase); portrait only on iPhone; camera, photos, microphone and location texts in `Info.plist`.
- Phone builds use sample data: `--dart-define=WHEELIO_DEMO=true` does what `?demo=true` does on the web. `tool/run-ios.sh` builds and installs both apps on a connected iPhone.
- Live Firebase on phones is not wired yet (iOS Firebase apps, native phone sign-in, native Razorpay); see "Native iPhone builds" in `BACKEND-HOOKUP.md`.

## 22 October 2026: browser acceptance fixes

Captain application uploads now restore from private Storage metadata after refresh, and submission requires the three documents, a society and a valid UPI ID. Account switches clear application state. Pending location permission requests time out instead of locking wash controls. Arrival is visible to Customer, and dry-dusting review uses the selected wash description. Accept uses the green action style and Captain job navigation has an accessible back label.

All 39 backend/rules/payment-adapter tests, 4 Customer tests and the Customer, Captain and shared Firebase analyses passed. Completed browser acceptance, fixture boundaries and release checks are recorded in [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md). iOS and Android remain deferred.

The final acceptance also fixed hidden unpaid bookings: both unpaid and unconfirmed states remain in Upcoming, display payment not confirmed, and reopen the same checkout. Repeat booking no longer promises WhatsApp gate-pass handling or invents a voice note when none exists; Customer photos are labelled optional. Both production web builds, Hosting and the changed payment/refund Functions deployed on 22 October. Approval/rating, earnings, persisted sessions, delayed payment reconciliation, dispute holds and both actual test refunds passed. The initially rejected netbanking refund processed in full after a virtual test balance payment. Customer now distinguishes delayed/review refunds from provider-accepted and processed refunds, and can safely check an existing refund's status. Physical GPS and merchant live cutover remain future checks.

## 21 October 2026: Firebase booking implementation

Both release web bundles and the Customer, Captain and shared Firebase package analyses passed. The first hosted review caught blank Captain name/mobile inputs: shared `WTextField` now uses its label as the hint when no separate placeholder is supplied. This keeps the existing design and makes empty fields identifiable in both apps.

The Firebase release build now runs a clean build and validates generated Functions, Storage and location web registrations. A cached prelaunch registry had routed callable requests through a native codec, producing `Int64 accessor not supported by dart2js` on web. The rebuilt hosted Customer draft now calls availability successfully; errors provide Retry, stale errors clear when changing dates, and the empty-capacity explanation appears above the disabled slots. No captain availability is simulated to unblock checkout.

The Customer booking steps now use Firebase phone OTP, a server catalog and capacity, Razorpay checkout, saved orders and private uploaded photos. Live booking details subscribe to assignment/wash/refund states, protected before/after photos and optional captain coordinates. The Captain app uses the existing Wheelio screen components for real phone accounts, private applications, offers, atomic acceptance, arrival, before/after uploads, wash stages and earnings. The full original screen gallery remains isolated behind `?demo=true`.

The owner confirmed real SMS delivery on 21 October and showed the Customer name screen after OTP verification. At their request the existing name was saved in their Chrome session; the signed-in Profile page confirmed account completion. Test-payment browser acceptance was completed on 21–22 October, with fixture boundaries recorded in WEB-ACCEPTANCE.md.

Trustkeyper billing and its stored **test** Razorpay credentials are reused. Live charges require live merchant keys; actual captains require operator approval. No demo lifecycle timer, sample OTP, fake KYC decision or invented payout runs in the live controllers. See [FIREBASE-BOOKINGS.md](FIREBASE-BOOKINGS.md) for the server model, test settings, release commands and remaining human operations. Native platform work remains deferred.

The 20 October entry below describes the earlier deployed prelaunch foundation.

## 20 October 2026: Firebase web foundation

Both `main.dart` entry points now start the shared `wheelio_firebase` package. Normal URLs open a real prelaunch app: email/password login and reset, saved profiles, customer wash requests/history/cancellation, and Captain applications. Firebase rules enforce per-account access and prevent client-side payment, job-state and KYC approval changes.

The complete previous design experiences are preserved behind **`?demo=true`** with a persistent "DEMO · Sample data · No bookings or payments" strip. No sample data or hardcoded OTP is used in the live portal. This is an initial request/application release; the entire designed paid-wash lifecycle is not connected yet.

`apps/hosting/` and both Flutter builds package into `build/firebase-hosting/`. Firebase Hosting serves `/`, `/app/` and `/captain/`. Project: `wheelio-apps`, owner account: `ajay@trustkeyper.com`, Firestore: Mumbai (`asia-south1`). See [FIREBASE.md](FIREBASE.md) for commands. iOS/Android platform generation and signing remain future steps; the new backend code is in Flutter and reusable there.

The entries below describe the earlier demo implementation and historical status.

Decided on 15 October 2026: both Wheelio apps, Customer and Captain (washer), are built in Flutter from one codebase. The release order is:

1. **Web**: the first launch target, available now as a build.
2. **iOS**: later, from the same code.
3. **Android**: after iOS, from the same code.

**All development happens in Flutter.** The Flutter apps are ports of the SwiftUI apps in `apps/ios/`. They have the same screens, states, copy (English, Hindi and Telugu for Captain), interactions, sample data and Screens gallery. The SwiftUI apps remain the design reference until the Flutter apps ship on iOS.

**Keeping them consistent:** every app change lands in Flutter in the same task. If something is changed in the SwiftUI reference first, it is ported to Flutter before it is committed. Anything a screen fakes (demo data, timers, test buttons) goes on the list in [BACKEND-HOOKUP.md](BACKEND-HOOKUP.md).

## Where the code lives

```text
apps/flutter/
├── packages/wheelio_ui/   # Shared design system and app shell
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

`PhoneFrame` (in `wheelio_ui`) handles this for both apps:

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

These stay the same on the web because a mouse can do them: dragging the map pin, dragging the before/after slider (a tap also works), and the welcome slides, which already have Next and Skip buttons.

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
