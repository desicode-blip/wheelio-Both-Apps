# Connecting the real services

Everything that needs an account, a key or an approval is listed here, in the
order it unblocks work. Each step says what you do and what Claude does next.
None of it was done on 10 Oct 2026 because it needs your accounts or approval.

## 1. Install Flutter (unblocks: building and testing the app)

**You:** say "install Flutter". It is about 1.5–2 GB from flutter.dev, installed into `~/development/flutter`. Xcode 26.6 and the iPhone 17 simulators are already on this Mac.
**Claude:** runs `tool/bootstrap_customer.sh`, which generates the `ios/` and `android/` folders, adds the camera, location and microphone permission texts, then runs `flutter analyze` and `flutter test`. Claude fixes any compile errors (the code was written without a compiler), then opens the app in the iPhone simulator and checks every screen through the in-app **Screens** gallery.

## 2. Supabase (unblocks: real logins, orders, photos, live status)

**You:** create a Supabase project in the **Mumbai (ap-south-1)** region and give Claude the project URL and anon key. The service-role key goes only into Supabase function secrets, never into the app.
**Claude:**
1. Applies `backend/supabase/migrations/20261010000000_init.sql` and `seed.sql`.
2. Creates the private storage bucket `order-photos`.
3. Writes `SupabaseBackend` (`apps/customer/lib/data/supabase_backend.dart`) against `backend/API-CONTRACT.md`.
4. Adds `supabase_flutter` to `pubspec.yaml`.
5. Switches with `--dart-define=BACKEND=supabase`.

## 3. SMS OTP (unblocks: real phone login)

**You:** register on the TRAI DLT portal (entity, sender ID, OTP template); approval takes 1–2 weeks. Then open an MSG91 (or Twilio Verify) account.
**Claude:** connects the provider in Supabase Auth → Phone. Until then, Supabase test phone numbers work.

## 4. Apple Developer Program (unblocks: TestFlight and App Store, real iPhone)

**You:** enrol as an organisation for USD 99 a year. This needs a D-U-N-S number and takes 1–2 weeks.
**Claude:**
1. Sets the bundle id `com.wheelio.customer` and signing.
2. Adds push notifications (APNs key) and the app icon.
3. Writes the privacy labels and builds for TestFlight.

The simulator works without this account.

## 5. Razorpay with Route (unblocks: real payments held until approval)

**You:** create a Razorpay account, complete business KYC and ask for **Route** to be enabled. Test keys are enough to start.
**Claude:**
1. Adds `razorpay_flutter`.
2. Writes the `create-payment` function and deploys `razorpay-webhook`.
3. Tests with Razorpay test cards and test UPI.

## 6. Google Maps (unblocks: real map and pin on C09)

**You:** turn on billing in a Google Cloud project and create a Maps SDK + Places API key, restricted to the app's bundle ids.
**Claude:** replaces `WMapPlaceholder` with `google_maps_flutter` and adds `geolocator`.

## 7. Firebase Cloud Messaging (unblocks: push notifications)

**You:** create a Firebase project and upload the APNs key.
**Claude:** adds `firebase_messaging`, saves push tokens to `customers.push_token` and sends status pushes from the functions.

## 8. WhatsApp Business (unblocks: entry-pass bot)

**You:** complete Meta Business verification, get a WhatsApp number (Cloud API or Gupshup/Interakt) and submit the templates in `backend/whatsapp-templates.md`.
**Claude:** writes and deploys `whatsapp-webhook`.

## 9. Masked calling (unblocks: "Call Raju")

**You:** open an Exotel (or similar) account with a virtual number.
**Claude:** writes `masked-call` and wires `callWasher()` in `live_order.dart`.

## 10. Anthropic API key (unblocks: AI photo check)

**You:** create a key at console.anthropic.com.
**Claude:** sets it as a Supabase secret and deploys `ai-photo-check`, which is already written.

## 11. Real device features in the app

When steps 1–2 are done, Claude adds `image_picker`/`camera`, `geolocator`, `url_launcher` and `shared_preferences`. It then writes `PluginDevice implements Device` (`lib/services/device.dart`), which replaces `MockDevice` in `main.dart`. The offline draft is saved on the phone (C50).

## Decisions still needed from you (they change config, not code)

- Final prices. The app reads them from the server.
- Cancellation fee after a washer accepts. Shown as `₹[CANCELLATION FEE]` until set in `app_settings`.
- Wait fee.
- Approval and dispute windows (2 h and 24 h now).
- Late-penalty cap (30% proposed).
- Final app name. One value: `BRAND_NAME`.
- Support phone and WhatsApp numbers.
- Terms and privacy URLs.
