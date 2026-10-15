# Flutter apps (Customer and Captain)

Decided on 15 October 2026: both Wheelio apps, Customer and Captain (washer), are built in Flutter from one codebase. The release order is:

1. **Web**: the first launch target, available now as a build.
2. **iOS**: later, from the same code.
3. **Android**: after iOS, from the same code.

The Flutter apps are ports of the SwiftUI apps in `apps/ios/`. They have the same screens, states, copy (English, Hindi and Telugu for Captain), interactions, sample data and Screens gallery. The SwiftUI apps remain the design reference until the Flutter apps ship on iOS.

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
| Captain · new job alert (W22) | Swipe the top job left to see the next one | **See next job →** button under the stack. Reject does the same, and the hint text changes to match. |
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

## Status

- Customer and Captain both pass `flutter analyze` with no issues and build for the web.
- Both run on sample data, as the iOS apps do. Demo login code: 123456 (000000 is expired). The **Screens** tab on the left edge opens every designed screen and edge state. In Captain, **Step through all screens** walks the gallery with ‹ › controls.
- Checked in the browser at laptop size (phone frame) and 375 px (full screen):
  - Captain: language → welcome → guest Home, a stacked job alert with See next job and Accept, the day plan, Go to vehicle, the owner's note, face check, the guided camera and washing.
  - Customer: welcome → Home → booking (vehicle type), and Check and pay with the payment sheet.
- Not connected yet: Neon / Better Auth API, payments, push and real photo upload. Screens call the store, and the store is where backend calls go (see `backend/API-CONTRACT.md`).
- The React ports at `apps/web` `/app` and `/captain` came first and are now superseded by these Flutter apps as the launch target. They stay until the Flutter web build is deployed, then can be removed.
- `legacy/` holds an older, unfinished Flutter customer app from before the iOS apps. The new code does not use it.
