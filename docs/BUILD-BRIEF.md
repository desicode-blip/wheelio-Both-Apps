# WashKrew – build brief and launch checklist

Draft, 10 October 2026. The Google Doc copy is in the WashKrew Drive folder. Sources: Business Plan, Product Roadmap, and the design "Read me" page (`designs/Main.dc.html`).

> Platform update, 11 October 2026: current development uses Next.js in `apps/web/` and native SwiftUI Customer/Captain apps in `apps/ios/`. `apps/android/` is reserved for later. The earlier Flutter implementation is preserved under `legacy/`. Flutter-specific stack and build-order choices below are historical; the business decisions and account checklist remain planning references. See the root README for the active structure and commands.

## 1. Build order

0. **Foundations:** backend, database, auth, payments in test mode, and the design system as Flutter widgets.
1. **Customer iOS:** C01–C55 at 393 × 866, then TestFlight.
2. **Customer Android:** same codebase, plus CA1–CA4 at 412 × 915, then Play internal testing.
3. **Washer Android:** W01–W50 at 360 × 800, in Hindi, Telugu and English.
4. **Admin console, alongside the apps:** KYC review, disputes, refunds, payouts and washer removal. Scope still to be agreed.

## 2. Decided

- **Language and apps:** Dart and Flutter. One codebase for the customer app on iOS and Android, and a separate washer app.
- **Design system:** the Figma design system is the source of truth. Layer names match the component names, so each component is built once as a widget.
- **Routing:** one route per screen ID. Suffixes b, c, h and t are states or language variants of the same screen. The button links in the designs are the navigation map.
- **Brand name:** kept in one config value (`brand/name`).
- **Placeholders:** `[CANCELLATION FEE]`, `[REFUND AMOUNT]` and `[WAIT FEE]` are config values.
- **Payments:** UPI and cards, with the money held until the customer approves the wash, then split to the washer (Razorpay Route).
- **Training videos:** YouTube official player only, never downloaded or re-hosted.
- **Appearance:** light mode only.

## 3. Recommended stack (needs sign-off)

- **App:** Flutter with Riverpod, go_router and a shared design-system package.
- **Backend:** Supabase with Postgres and PostGIS, auth, storage, realtime and edge functions, in the Mumbai region.
- **Push:** FCM, with APNs on iOS.
- **Maps:** Google Maps and Places.
- **OTP:** MSG91, with DLT registration.
- **Masked calling:** Exotel.
- **WhatsApp bot:** WhatsApp Cloud API or Gupshup.
- **AI photo check:** Claude vision through the Anthropic API.
- **Washer KYC:** DigiLocker through IDfy, Signzy or HyperVerge.
- **Voice quiz:** Hindi and Telugu speech-to-text (Sarvam or Google).

## 4. Accounts the owner must set up

| # | Item | Phase | Notes |
|---|---|---|---|
| 1 | Apple Developer Program, as an organisation | 1 | Needs a D-U-N-S number. Takes 1–2 weeks, so start now. |
| 2 | Mac with Xcode and Flutter, plus a test iPhone | 1 | |
| 3 | Private GitHub repo | 0 | |
| 4 | Supabase project | 0 | |
| 5 | Razorpay with Route turned on | 0–1 | Test keys first. |
| 6 | Firebase (FCM) and APNs key | 1 | |
| 7 | Google Maps API key | 1 | |
| 8 | SMS provider and DLT registration | 1 | Takes 1–2 weeks. |
| 9 | Meta Business verification and WhatsApp number | 1 | |
| 10 | Exotel or another masked-calling provider | 1 | |
| 11 | Anthropic API key | 1 | |
| 12 | Domain, privacy policy, terms, support contact | 1 release | Required by the App Store and the DPDP Act. |
| 13 | Google Play Console | 2 | |
| 14 | KYC provider and speech-to-text | 3 | |
| 15 | Figma design-system link | 0 | |

## 5. Open decisions

- Whose photos count as wash evidence.
- Final prices (proposed 69 / 149 / 179 / 219).
- Late-penalty cap (proposed 30%).
- Approval and dispute windows (proposed 2 h and 24 h).
- Cancellation fee, refund amount and wait fee.
- Time-slot rules.
- Service area and launch societies.
- V1 damage cover.
- Final app name.
- Backend choice.
- Admin console scope.

## 6. Timeline (roadmap)

Build V1 runs from 1 Dec 2026 to 15 Feb 2027. Pilot in March 2027, public launch in April 2027.
