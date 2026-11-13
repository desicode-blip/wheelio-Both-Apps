# WashKrew v2 — handoff to Ajay (13 Nov 2026)

**From:** Aman (product decisions) and Claude (code). **Branch pushed to:** `staging`, which fast-forwards
from your `6ee74a4` (no rewrite). Everything is bucketed by feature ID; each ID has its own doc
in `docs/v2/`. **Read this page first, then [V2-FEATURES.md](V2-FEATURES.md) for the server list.**

## 1. What this push is

- **Both apps:** all v2 screens are now the standard app (not hidden behind preview), merged on
  top of your refund-coupon work.
  - Customer **1.0.6 (11)** and Captain **1.0.7 (12)**: your version numbers are kept.
  - Where the server isn't ready, the apps either block payment with a plain message, or show
    clearly labelled sample data.
  - Switch all of v2 off with `config/operations.v2Features = false`.
- **Server (new in this push, written for your review and not deployed):**
  - `createBooking` now accepts and stores `vehicleProfile`, `careRoutine` and `minuteWindows`,
    and copies them onto every Captain `jobOffer`.
  - New callable `identifyVehicle`, off until `config/operations.vehicleAi = true`.
  - Details in §4.
- **Tests at this commit:**

| Suite | Result |
|---|---|
| Backend: `npm run firebase:test` (emulators) | 255 / 255 pass (4 new) |
| Customer Flutter | all pass, `flutter analyze` 1 info (yours, pre-existing) |
| Captain Flutter | all pass, 0 issues |
| Referrals package | all pass |

- **Nothing deployed.** No Functions, rules, config or website were deployed, and no merchant,
  key or Firebase setting was touched.

## 2. Release gate — please read

The live server still sells only **Basic, exterior, the fixed windows**. The apps already handle
this:
- Premium, interior, monthly plans, exact times that don't match a server slot, and free
  referral washes all show a short reason at Check and pay, plus **Change wash / Change time**.
  Nothing can be paid by mistake.
- Referrals, "vehicle not found" and monthly jobs for Captains run on sample data in the apps.
- **Before an App Store release:** either finish the matching server items below, or set
  `v2Features: false` so no sample data is visible on a live build.

## 3. What changed since `6ee74a4` (product view)

| ID | Change | Doc |
|---|---|---|
| CU-WASHCHOICE | Choose your wash (Basic / Premium / Extra Premium, ±interior); one-time or monthly plan; real prices from Aman (§5) | CU-WASHCHOICE.md |
| CU-TIME | Own time windows with a range slider (15-min steps, ≥1 h, 4 AM–11 PM); windows matching server slots book today | CU-TIME.md |
| CU-VEHICLE | Your vehicle screen: view, edit, delete (blocked while a wash is booked), book again | CU-VEHICLE.md |
| CU-CARE | After photos: AI "Is this your vehicle?" (make, colour, glossy/matte), optional details form, 2–3 step care routine; Captain sees it on the job | CU-CARE.md |
| CU-REVIEW | Check and pay: **Make payment** always moves forward (log in → straight to payment, any time window books today); your refund coupons shown up front (Apply / tick / Remove, 3+ in a sheet), no typed code; quiet cancellation-policy line; "Log in to pay" first; blocked choices get Change wash / Change time | CU-REVIEW.md |
| CU-REFER | Referral screen simplified (Share → 5 washes → 1 free Premium wash), progress blocks, copy toasts; entry from Coupons; full rules in website terms §9 | V2-FEATURES.md (Referral rule) |
| CU-START | Logged out → Welcome slides; logged-in launch unchanged | — |
| SH-NOTIFY | Customer and Captain ask only for notifications at launch; camera/mic/location at first use. Both apps: no Clear all / Delete on notifications, only **Mark all as read** | SH-NOTIFY.md |
| CA-JOURNEY | Captain My level: wash milestones 50 / 100 / 500 / 1000 / 2000 after the first 3 days (100 = surprise merchandise); stars match the rating | CA-JOURNEY.md |
| CA-MONTHLY-JOBS | Monthly jobs ring on a gold full-screen alert; Jobs tab: one **Find new jobs** banner → every open job (gold monthly cards, normal one-time cards, no timer); Recurring assignments list + detail (monthly package, M–S circles, cancel ≥2 days ahead); recurring visits gold in Today's plan | CA-MONTHLY-JOBS.md |
| CP-OFFERS / CP-MONEY | Visit pay terms on offers, pay guide (handoff) | CU-WASHCHOICE.md |
| Recovery | Vehicle not found / Captain cancellation / replacement / make-up — every screen, sample data | V2-FEATURES.md |
| Tools | Xcode **Play** on Customer also installs Captain afterwards; `run-ios.sh` forces a UTF-8 locale (CocoaPods crashed without one when started from Xcode) | §6 |

## 4. Server work done in this push (please review)

**File:** `backend/firebase/functions/src/vehicle-care.mjs` (new). Wired into `service.mjs`,
`index.mjs` and `runtime-policy.mjs`. Test: `backend/firebase/vehicle-care.test.mjs`.

**`createBooking` (all fields optional; old clients unchanged):**
- `vehicleProfile`:
  - fields `{make, model, color, finish: glossy|matte|unknown, seats: fabric|leather|unknown, source: ai|customer}`;
  - text is trimmed and capped at 40 characters; unknown values become `unknown`;
  - if nothing useful is left, the field is dropped.
- `careRoutine`: up to 3 `{title ≤60, detail ≤160}`.
- `minuteWindows`: up to 4 `{startMinute, endMinute}`.
  - Each window must be between 4 AM and 11 PM, at least 60 minutes long, and overlap one of the
    server windows booked for that order. Windows can't overlap each other.
  - The app books the fixed slots inside the customer's window (or the one it overlaps most), so
    any window can be paid today.
  - Stored **for the Captain to see**. Capacity and matching still use the fixed windows (your
    item 2 in V2-FEATURES.md is unchanged).
- All three are stored on the order and copied onto each `jobOffers` doc (`offerCareFields`).
  The Captain app reads them already (`captain/lib/features/v2_job.dart`, "Care for this
  vehicle" on the wash screen).

**`identifyVehicle({vehicleKind, images: [base64 JPEG/PNG ≤1.5 MB, 1–2]})`:**
- Returns `{make, model, color, finish, confidence}`. The app uses it only when confidence is 0.6
  or more; otherwise it shows the form.
- Off unless `config/operations.vehicleAi === true`, so it is safe to deploy dormant.
- Limited to 10 checks per customer per hour (`vehicleAiRate/{uid}`, server-only).
- Uses the same Gemini model setting as the wash-photo review (`privateConfig/photoChecks.aiModel`,
  location `global`) via `VertexVehicleAi`. Images are sent inline and **never stored**.
- The prompt says not to read number plates or people.
- Runtime: 120 s timeout, 512 MiB memory, like `checkWashPhotos`.

**Before switching `vehicleAi` on:**
1. Aman to approve the privacy and consent wording: customer photos are sent to Google AI.
2. Deploy `identifyVehicle`.
3. Run the post-deploy HTTP gateway step, as for the other callables.

## 5. Server work still open (smallest first)

The full list is in [V2-FEATURES.md](V2-FEATURES.md); each item has its contract in its feature doc.

1. **Wash tiers:**
   - Price from `washPrices`, accept `serviceLevel` / `coverage`, then `washTiers: true`.
   - Real prices (Aman): car ₹292 / ₹392 / ₹492, +₹80 interior; bike ₹149 / ₹199 / ₹249.
2. **Exact time windows for capacity and matching** (`customTimeWindows`, `serviceHours` 240–1380).
3. **Monthly plans + AutoPay**, then monthly offers to Captains:
   - Ordinary `jobOffers` whose job carries `plan: {totalVisits, dates:[…]}`, plus `visitTerms`
     with the per-visit pay.
   - `claimJob` assigns all visits.
   - Push kind `newMonthlyJob`.
   - `cancelRecurringAssignment({assignmentId})` with the 2-day rule: the next 2 days' visits stay
     with the Captain, later ones are re-offered.
   - A list of the Captain's accepted assignments.
4. **Open jobs list** (`listOpenJobs`), so Captains can find jobs they missed.
5. **Referrals** (rule in V2-FEATURES.md and terms §9):
   - Codes and attribution at sign-up.
   - Count any 5 completed washes, including plan visits.
   - Reward 1 Premium wash for any vehicle.
   - **Deploy the website terms only when this is live.**
6. **Gate pass upload; photo reuse; vehicle-not-found recovery**: contracts in
   `packages/washkrew_service_recovery/lib/src/contracts.dart`.
7. **Captain milestones:**
   - Optional `config.captainMilestones` (defaults built in).
   - Someone needs to own sending the 100-wash merchandise.

## 6. How to run and check

```sh
# Backend (emulators)
npm run firebase:test                       # 255 tests
# Apps
cd apps/flutter/customer && flutter analyze && flutter test
cd apps/flutter/captain  && flutter analyze && flutter test
# iPhone (Aman's Mac): Desktop shortcut "Install WashKrew on iPhone", or
bash apps/flutter/tool/run-ios.sh --prepare && bash apps/flutter/tool/run-ios.sh
```

- **New Xcode setting:** the Customer scheme has a Run pre-action that installs the Captain app
  about a minute after Customer.
  - It runs only from Xcode's Play, never from `flutter build` or the archive script.
  - To remove it, delete `<PreActions>` under `LaunchAction` in
    `customer/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`.
- **Locale fix:** `run-ios.sh` now exports `LANG` / `LC_ALL=en_US.UTF-8`. This fixes CocoaPods'
  "Unicode Normalization not appropriate for ASCII-8BIT" crash when started from Xcode.

## 7. Merge notes

- **Conflicts we resolved when merging your `6ee74a4`:**
  - Your version numbers, `checkout_flow` and auth/pay wording were kept.
  - `ReviewScreen` = our layout + your coupon logic.
  - The wallet toggle shows on sample builds only.
- **Your coupon code paths are unchanged:**
  - `store.applyCoupon` → `previewRefundCoupon`.
  - The draft coupon fields and the forfeit confirmation are as you wrote them.
  - Only the coupon picker UI is new (`customer/lib/screens/coupon_picker.dart`).
  - The coupon query moved into `AppStore.refundCouponDocs()` so tests can supply fixtures.
- If you change a screen we touched, the feature doc names every file per ID. See
  [MERGE-GUIDE.md](MERGE-GUIDE.md) for the layout.
