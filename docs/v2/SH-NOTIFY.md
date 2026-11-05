# SH-NOTIFY — Notification permission, push, inbox

Feature map: [FEATURES.md](FEATURES.md). Screens: C49, new C49a (Customer), new W03n (Captain).

## 5 Nov 2026 — Ask once after install, take people straight to the right setting

- **Why (Aman):** both apps should ask for notifications right after install. Saying yes
  shows the iPhone prompt at once; if notifications were already refused, open Settings.
  Customers must hear that we only notify about what matters.
- **Branch:** `v2/cu-bookings-rebook`.

### What changes

- First time Home opens after install (signed in or not), a full screen asks once.
  It is not shown again on this device after either answer, or if notifications are already on.
- **Customer (C49a):** "Only what matters" — "We'll notify you when your vehicle is washed, or
  if something needs you. No ads. No offers." Buttons: **Turn on notifications** / Not now.
- **Captain (W03n, English/Hindi/Telugu):** "Turn on job alerts" — "New jobs ring with a sound,
  even when the app is closed. Without alerts you will miss jobs." **Turn on alerts** / Not now.
- **Turn on** shows the iPhone permission prompt immediately. If iOS already has
  notifications off for the app, the button reads **Open Settings**, the message adds
  "In Settings, tap Notifications and turn on Allow Notifications", and it opens the app's
  Settings page.
- A customer who says yes before signing in gets it saved to their account automatically
  after sign-in. The old after-booking ask (C49) is skipped when the first ask was answered.

### Files changed

- `packages/washkrew_ui/lib/src/notify_ask.dart` (new, SH-DESIGN) — shared `WNotifyAsk` screen.
- `packages/washkrew_ui/lib/src/local_flags.dart` (new) — on-device yes/no flags (`notifyAsked`, `pushWanted`).
- `packages/washkrew_firebase/lib/src/live_backend.dart` — `requestPushPermission()` (iOS prompt without an account).
- Customer: `data/store.dart` (`shouldAskNotificationsFirst`, `answerNotificationsFirst`,
  `syncWantedNotifications`, route `notifyFirst`), `main.dart`, `screens/auth_pay.dart` (C49a, C49 skip),
  `screens/home.dart` (trigger on Home).
- Captain: `data/store.dart`, `main.dart`, `screens/home.dart` (trigger + W03n).

### Backend needed (Ajay)

None. Uses the existing `setPushPreference` and push registration after sign-in.
Customer notifications must stay limited to booking/wash updates and important account
messages (no marketing), matching the screen's promise.

### How to test on the iPhone

Delete the app, reinstall, open it: the ask appears over Home → Turn on → iPhone prompt →
Allow. Reopen: no second ask. To test the Settings path: Settings → app → Notifications off,
delete the app's data by reinstalling, open → button says Open Settings.

### Status

Built; analyze clean; Customer 85/85, Captain 40/40, shared UI 9/9 tests pass. iPhone test pending.
