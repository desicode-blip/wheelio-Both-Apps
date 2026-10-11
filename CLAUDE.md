# Wheelio

Doorstep, photo-verified exterior wash for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name (`BRAND_NAME`).

Build order: 1) customer app iOS → 2) customer app Android (same codebase + CA1–CA4) → 3) washer app Android (separate Flutter app, Hindi/Telugu/English, 360×800).

## Layout

- `designs/` — export of the Claude Design file (124 `.dc.html` screens). Source of truth for layout and copy. `designs/Main.dc.html` is the design read-me; `designs/wheelio-screens.json` is the navigation map.
- `packages/wheelio_ui/` — design system (tokens, `W*` widgets). Widget names match design layer names (Button/Primary → `WButton`, Footer bar → `WFooterBar`).
- `apps/customer/` — Flutter customer app. One route per screen ID (`lib/routes.dart`); letter suffixes are states of the same route via `?state=`.
  - `lib/data/backend.dart` is the only server boundary. `MockBackend` (sample data) today; `SupabaseBackend` later per `backend/API-CONTRACT.md`.
  - `lib/services/device.dart` wraps camera/location/notifications; `MockDevice` today.
  - `/dev` route = screen gallery (mock mode) with switches for every edge case.
- `backend/supabase/` — migration, seed, edge functions.
- `docs/` — build brief, connect-later checklist, screen index.

## Rules from the designs

- One primary action per screen. Green only to pay, approve or accept. Red only for errors and destructive actions.
- One small decision per screen in the booking flow.
- Every payment screen says the money is held and released only after approval.
- Call/help bottom-left on task screens. Colour never the only signal: icon + word. Touch targets ≥ 48 px (washer 64).
- Undecided business values stay as config (`AppConfig`, `app_settings`), shown as `[CANCELLATION FEE]` etc.

## Commands (after `tool/bootstrap_customer.sh`)

```
cd apps/customer && flutter run            # simulator, mock data
flutter test                               # logic tests
flutter run --dart-define-from-file=env/dev.json
```

Demo login code in mock mode: 123456 (000000 = expired).
