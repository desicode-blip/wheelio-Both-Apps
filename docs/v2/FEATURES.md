# WashKrew v2 — feature map

**Baseline:** the version 1 code submitted to the App Store on 5 Nov 2026 —
Customer 1.0.4 (10), Captain 1.0.5 (11). On Aman's Mac this is commit `4a96ee0`
(staging `e67a15e` + iPhone-only/build-number/store-record commits).
Every v2 change is made on top of this and pushed to staging for Ajay.

The whole product is split into **feature buckets**. Every change, design, document and
commit is filed under exactly one bucket ID, so designs can be reused and only the files
of that bucket need to be opened when working on it.

How to use this map:

- Name every change by bucket: branch `v2/<ID>-<short-name>` (e.g. `v2/cu-pay-upi-first`),
  commit title `[CU-PAY] …`, document `docs/v2/<ID>.md`.
- Screen IDs (C.., W..) are the existing design IDs from `docs/screen-index.csv`
  and the Figma frames. New screens get the next free ID in the same series.
- "Files" lists where the bucket lives. Paths are under `apps/flutter/` unless stated.
- A change that touches two buckets is split into two entries, one per bucket.

## Shared (both apps)

| ID | Feature | Screens | Files |
|---|---|---|---|
| SH-AUTH | Phone login, OTP, session | C14–C16, C54; W02, W03 | `packages/washkrew_firebase/lib/src/phone_otp.dart`, `customer/lib/screens/auth_pay.dart`, `captain/lib/screens/welcome.dart` |
| SH-NOTIFY | Notification permission, push, inbox | C49 | `customer/lib/screens/notifications.dart`, `packages/washkrew_firebase/lib/src/apns_readiness.dart` |
| SH-ACCOUNT | Profile, account deletion | C47, C53; W47 | `packages/washkrew_ui/lib/src/delete_account.dart`, `packages/washkrew_firebase/lib/src/account_deletion.dart`, `account_role.dart`, `captain/lib/screens/account.dart` |
| SH-HELP | Help and support | C48; W48, W57 | `customer/lib/screens/support.dart`, `captain/lib/screens/help.dart` |
| SH-STATES | Offline, error, loading, large text | C50–C52, C55; W50 | `customer/lib/screens/home.dart` (states), shared components |
| SH-CAMERA | Camera, photo/video/voice capture, photo quality | C08, C08b; W32, W33 | `packages/washkrew_ui/lib/src/live_camera.dart`, `media*.dart`, `photo_quality.dart`, `playback*.dart` |
| SH-MAPS | Maps, GPS, place search | C09, C09b, C09c | `packages/washkrew_firebase/lib/src/live_map.dart`, `packages/washkrew_ui/lib/src/map_controls.dart`, `customer/lib/data/place_search.dart` |
| SH-DESIGN | Design system: colours, type, icons, buttons, cards | all | `packages/washkrew_ui/lib/src/tokens.dart`, `components.dart`, `icons.dart`, `brand.dart`, `nav.dart` |

## Customer app

| ID | Feature | Screens | Files |
|---|---|---|---|
| CU-START | Splash and welcome | C01, C02 | `customer/lib/screens/start.dart` |
| CU-HOME | Home, credit banner, book again | C40–C42 | `customer/lib/screens/home.dart` |
| CU-VEHICLE | Vehicle type, number, saved vehicles | C05, C06, C06b, C46 | `customer/lib/screens/booking.dart`, `home.dart` (vehicles) |
| CU-PHOTOS | Vehicle photos before booking | C07–C08b | `customer/lib/screens/booking.dart` (camera screen) |
| CU-PLACE | Vehicle location, floor/slot, notes | C09–C11 | `customer/lib/screens/booking.dart`, `customer/lib/data/place_search.dart` |
| CU-TIME | Time windows, availability, no Captain free | C12, C12b | `customer/lib/screens/booking.dart`, `customer/lib/data/booking_availability.dart`, `availability_cache.dart` |
| CU-REVIEW | Check and pay summary, AI photo setting | C13 | `customer/lib/screens/booking.dart`, `booking_ai_setting.dart` |
| CU-PAY | Checkout, Razorpay, payment pending/failed, booked | C17–C19 | `customer/lib/screens/auth_pay.dart`, `packages/washkrew_firebase/lib/src/checkout_*.dart` |
| CU-WALLET | Wallet, top-up, credit and expiry | — | `customer/lib/screens/wallet.dart` |
| CU-LIVE | Finding a Captain, on the way, late, washing | C20–C24, C30 | `customer/lib/screens/live.dart` |
| CU-APPROVE | Check photos, compare, approve, rate | C25–C28 | `customer/lib/screens/live.dart`, `packages/washkrew_firebase/lib/src/photo_review_flow.dart` |
| CU-CANCEL | Cancellation by Customer (98% / 50% / 0%) | C29, C29b, C29c | `customer/lib/screens/common.dart`, `live.dart` |
| CU-REPORT | Report a problem, disputes, refunds | C31–C37 | `customer/lib/screens/problem.dart`, `customer/lib/data/refund_status.dart` |
| CU-BOOKINGS | Bookings list, detail, repeat | C43–C45 | `customer/lib/screens/home.dart` |

## Captain app

| ID | Feature | Screens | Files |
|---|---|---|---|
| CP-START | Welcome, language, sign-up | W00–W03 | `captain/lib/screens/welcome.dart` |
| CP-ONBOARD | Steps, Aadhaar upload, selfie, payout, fix documents | W04–W07, W15 | `captain/lib/screens/onboarding.dart` |
| CP-TRAINING | Training videos, quiz, refresher (hidden in v1) | W08–W11b, W45 | `captain/lib/screens/onboarding.dart`, `money.dart` |
| CP-APPROVAL | Rules, under review, approved, probation | W12–W14 | `captain/lib/screens/onboarding.dart`, `home.dart` |
| CP-AREA | Serving area (map, radius) and working hours | — | `captain/lib/screens/service_area.dart`, `help.dart` (Where I work) |
| CP-HOME | Home, online/offline, today's plan | W20, W21, W50 | `captain/lib/screens/home.dart`, `captain/lib/data/presence.dart` |
| CP-OFFERS | Job offer alert, accept, missed, daily limit | W22–W24 | `captain/lib/screens/home.dart`, `captain/lib/data/offer_feed.dart` |
| CP-JOBS | My jobs, go to vehicle | W25, W26 | `captain/lib/screens/home.dart` |
| CP-CANCEL | Captain can't reach/find vehicle, Customer cancelled | W27–W29 | `captain/lib/screens/home.dart` |
| CP-WASH | Face check, before photos, washing, after photos, AI check, upload, done | W30–W38b | `captain/lib/screens/wash.dart`, `captain/lib/data/evidence_uploads.dart`, `job_resume.dart` |
| CP-MONEY | Earnings, payouts, payout held | W40–W42 | `captain/lib/screens/money.dart` |
| CP-LEVEL | Ratings, probation, account removed | W43, W44, W46 | `captain/lib/screens/money.dart` |

## Operations (outside the apps)

| ID | Feature | Files |
|---|---|---|
| OP-ADMIN | Private admin review portal | `apps/admin/` |
| OP-WEB | Website, policy pages | `apps/website/`, `release/store/policies/` |
| OP-STORE | App Store / Play release | `release/store/`, `apps/flutter/tool/archive-ios.sh` |
| OP-BACKEND | Firebase functions and rules (Ajay) | `backend/firebase/` |

## Rules for v2 work

1. One change = one bucket ID = one branch = one `docs/v2/<ID>.md` entry.
2. Design changes stay inside the bucket's screens. Shared look-and-feel changes go
   through SH-DESIGN only, so every screen picks them up.
3. Add new screens/components in new files; do not rename, move or reformat existing ones.
4. No backend changes from Aman's side. Each entry lists **Backend needed** for Ajay.
5. Each entry records: screens, files changed, backend needed, how to test, and
   before/after screenshots (private details blurred).
6. Test on Aman's iPhone before pushing. Push to staging only when Aman asks.

## Entry template (`docs/v2/<ID>.md`)

```
# <ID> — <feature name>

## <date> — <change title>
- Why:
- Figma frames:
- Screens: (existing IDs changed / new IDs added)
- What changed for the user:
- Files changed:
- Backend needed (Ajay): none / fields, functions, notifications
- How to test on the phone:
- Status: designing / built / tested on iPhone / pushed to staging (commit)
```

## Change log

| Date | ID | Change | Doc | Status |
|---|---|---|---|---|
| 5 Nov | CU-BOOKINGS | Prefilled Book again + photos step (C45, C45b) | [CU-BOOKINGS.md](CU-BOOKINGS.md) | built, iPhone retest |
| 5 Nov | CU-TIME | "When is your vehicle free?" + slot checkboxes (C12) | [CU-TIME.md](CU-TIME.md) | built, iPhone retest |
| 5 Nov | SH-DESIGN | `WChip` optional checkbox (used by CU-TIME) | [CU-TIME.md](CU-TIME.md) | built |
| 5 Nov | CU-LIVE | Upload gate pass on C19/C22; Captain sees it on W27 | [CU-LIVE.md](CU-LIVE.md) | built, backend needed |
| 5 Nov | CU-APPROVE | (i) explanation on AI wash photo check (stays OFF) | [CU-APPROVE.md](CU-APPROVE.md) | built |
| 5 Nov | SH-NOTIFY | Ask once after install in both apps; Open Settings if refused | [SH-NOTIFY.md](SH-NOTIFY.md) | built |
| 5 Nov | CU-VEHICLE | Add a vehicle without booking; Which vehicle? at booking start; photo choice | [CU-VEHICLE.md](CU-VEHICLE.md) | built, backend needed |
