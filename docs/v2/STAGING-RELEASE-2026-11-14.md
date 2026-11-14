# WashKrew — staging release, 14 Nov 2026

**From:** Aman (product sign-off: "the app is good to go from my end") and Claude (code).
**For:** Ajay. **Branch:** `staging` (also `main`), fast-forward from your `6ee74a4`, no rewrite.
**Apps in this push:** Customer **1.0.6 (11)**, Captain **1.0.7 (12)**: your version numbers,
already above what is in App Review.

Read this page first. It covers everything since the 13 Nov handoff and is the single list
of what you need to do. Earlier detail stays in
[AJAY-HANDOFF-2026-11-13.md](AJAY-HANDOFF-2026-11-13.md) (§4–§4c are the server contracts)
and [V2-FEATURES.md](V2-FEATURES.md).

---

## 1. Your to-do list (in order)

| # | What | Why | Where |
|---|---|---|---|
| 1 | Pull `staging`, run the checks in §5 | Confirm the same results here | — |
| 2 | Review and **deploy Functions** (all changed callables + `maintainBookings` + the Firestore order trigger), then run the usual post-deploy HTTP gateway step | Nothing new works on the live server until then. **No Firestore rules or indexes changed.** | §3 |
| 3 | Create **`privateConfig/testBookings`** = `{uids: [Aman's Customer uid, Aman's Captain uid]}` (from Firebase Auth; never in Git) | Lets Aman book Premium and monthly plans **without payment** so the Captain app gets real jobs end to end | Handoff §4c |
| 4 | Have Aman book one Premium test wash and one monthly test plan, and take them with his Captain account | First real two-phone run of the new features | §4 |
| 5 | When Aman says sell **Premium**: set `washPrices` (below), then `washTiers: true` | Customers can pay for Premium / Extra Premium | Handoff §4a |
| 6 | When Aman says sell **monthly plans**: `monthlyPlans: true` (optional `monthlyPlanPricing`) | One payment per month, visits split server-side; **no AutoPay yet** | Handoff §4a |
| 7 | Leave **`interior`** unset | Aman: interior stays closed for everyone, tests included | New, §3 |
| 8 | `vehicleAi: true` only after Aman approves the privacy wording | Photo-based "Is this your vehicle?" | Handoff §4 |
| 9 | App Store: decide with Aman (see §6) | 1.0.4 / 1.0.5 have waited for review since 5 Nov and don't contain this work | §6 |
| 10 | Account Holder: provide **EU trader status** in App Store Connect | Banner on the account; doesn't block India | — |

`washPrices` (rupees; Aman's prices). Car kinds `hatchback`, `sedan`, `suv` each:
`{basic:{exterior:292,exteriorInterior:372},premium:{exterior:392,exteriorInterior:472},extraPremium:{exterior:492,exteriorInterior:572}}`;
`bike`: `{basic:{exterior:149},premium:{exterior:199},extraPremium:{exterior:249}}`.
Basic exterior still uses each vehicle type's own `pricePaise`.

Everything in steps 5–8 is a `config/operations` switch: **no app update is needed** to
turn a feature on. Until a switch is on, live apps keep that feature greyed out (a tap shows
"…is coming soon. We're working on it."), so nobody can pay for something the server
can't serve.

---

## 2. What's new for users (since the 13 Nov handoff)

### Customer app

- **Book again cards:** every card has the blue address highlight; the ₹ sits on the right
  beside the arrow.
- **No "Coming soon" text anywhere.** Unavailable choices are greyed and unselected; a tap
  shows the coming-soon toast (wash level, interior, Monthly tab, gate pass, referral rows).
- **Monthly plan journey, end to end:** choose days and times → Check and pay → one payment
  for the month → "Plan confirmed" → each visit appears on Bookings (`scheduled` visits read
  as booked). Renewal/AutoPay choices are hidden on live (not built yet).
- **Premium / Extra Premium** checkout sends `serviceLevel` / `coverage` once `washTiers` is on.
- **After UPI payment:** iOS can't bring the app back from GPay/PhonePe by itself, so:
  the payment push now reads **"Payment received · booking confirmed — Tap to go back to
  WashKrew"** (lands on top of the UPI app; needs deploy), and on return the Pay screen
  shows "Confirming payment" at once and checks every 1.5 s for ~90 s, then moves on by itself.
- **Name is mandatory:** the name step after the SMS code has no back arrow and shows the
  standard missing-field error; an account opened without a name is sent back to it at
  launch. (Root cause: the account is created at the SMS-code step, before the name screen.)
- **Keyboard** closes whenever the screen changes (both apps).

### Captain app

- **First launch:** logged out → always Language, then the welcome slides; logged in →
  straight to Home. A short logo screen (max 8 s) waits for the saved login, so the two no
  longer flicker.
- **Name:** asked at sign-in if the Captain profile has none; Quick KYC and Rules open an
  "Add your name" screen instead of failing at "I agree".
- **Serving area, rebuilt as two steps** (same experience as the Customer "Is your vehicle
  here?" step):
  1. *Where will you work?* GPS starts as the screen opens; full-width map with the radius
     circle; **Change** to search; travel radius; "Location is off" offers Turn on location /
     Search area.
  2. *Working hours:* the slider, and now the **sun/moon arc is draggable** too (nearer end,
     30-minute steps, at least 1 hour).
  - **Go online** without a serving area opens this first-time setup; **Save and continue**
    goes straight to the next KYC step (Aadhaar …), not back to Home.
- **Quick KYC:** serving area is now step 1, grouped **"Where you work"**, then **"Your KYC"**
  (Aadhaar, photo, Bank or UPI).
- **"Your account is approved"** pop-up on the first open after approval (once per account
  per phone): welcome by name, **Go online** (or Start if already online), Later.
- **Home bell** aligned with the right edge of the cards (tap area unchanged).
- **Test jobs** show "Test job, no pay"; monthly-plan visits (`planVisit` / `planVisits`)
  use the gold monthly styling.

### Aman's phone only (never App Store builds)

`tool/ios.dart` adds `--dart-define=WASHKREW_PREVIEW_UNLOCK=true` for device installs
(`run-ios.sh`, the Desktop shortcut) and **`=false` for App Store archives**. With it, live
builds open Premium, monthly plans, referrals (sample data) and gate pass; **interior stays
closed**. Premium/monthly then show **"Book test wash · no payment"** after a clear confirm:
- once step 3 above is done, a real server test booking (Captains get it for real);
- until then, a labelled on-phone preview (`PREVIEW-…`, sample Captain updates).

A test booking can never open Razorpay (`TestBookingUnavailable` guard in
`checkout_flow.dart`); a server without test bookings also rejects it on price.

---

## 3. Server changes in this push (please review before deploy)

| Area | File | Change | Test |
|---|---|---|---|
| Wash tiers | `vehicle-care.mjs` (`washTier`), `service.mjs`, `checkout-identity.mjs` | Premium / Extra Premium / interior priced from `washPrices` behind `washTiers`; Captain fixed pay scales with price | `vehicle-care.test.mjs` |
| **Interior switch (new today)** | `vehicle-care.mjs` | Interior also needs **`config.interior === true`**, for everyone including test bookings | `vehicle-care.test.mjs` |
| Monthly plans | `monthly-plan.mjs` (new), `service.mjs`, `index.mjs` | `createBooking` `plan` → one payment → visits split at capture → `activatePlanVisit` ~36 h ahead → per-visit cancel/refund/earnings | `monthly-plan.test.mjs` |
| Test bookings | `service.mjs`, `vehicle-care.mjs` (`DEFAULT_WASH_PRICES`) | `testBooking: true` for uids in `privateConfig/testBookings`; settles without Razorpay (`paymentSource: 'test'`); Captain pay 0; no quote, no refunds | `monthly-plan.test.mjs` |
| Payment push | `notifications.mjs` | `pendingPayment → searching` push: "Payment received · booking confirmed — Tap to go back to WashKrew" | `notifications.test.mjs` |
| Captain name | `service.mjs` (`registerAccount`) | Copies an account name that never reached the Captain profile; `needsName` uses the trimmed name | full suite |
| Earlier (13 Nov) | `vehicle-care.mjs` | `vehicleProfile`, `careRoutine`, `minuteWindows` on orders/offers; `identifyVehicle` (off until `vehicleAi`) | `vehicle-care.test.mjs` |

Statuses: plan visits use a new order status **`scheduled`** (paid, waiting to be offered).
Cancel, the cancellation quote and account-deletion checks accept it. The apps map it to
"booked".

---

## 4. How to test the new journeys (after deploy + step 3)

1. **Premium (test):** Aman's Customer app → Premium → Check and pay → *Book test wash · no
   payment* → Book test. The order is `searching`, `paymentSource: test`, `captainPayPaise: 0`.
   Aman's Captain (online, area covering the address) gets the alert, marked *Test job, no pay*.
   Accept → arrive → wash → photos → Customer approves and rates.
2. **Monthly (test):** Monthly tab → days + times → *Book test plan · no payment*. Visit 1 is
   `searching`; later visits are `scheduled` orders with `planId`, which become `searching`
   about 36 h ahead. Cancel a future visit: no refund (test).
3. **Real paid Basic wash:** unchanged path, still works end to end with live Razorpay.

---

## 5. Checks at this commit

| Suite | Result |
|---|---|
| Backend `npm run firebase:test` (emulators) | **263 / 263 pass** |
| Customer Flutter | all tests pass · `flutter analyze` 1 info (yours, pre-existing, `booking.dart` coupon dialog) |
| Captain Flutter | all tests pass · 0 issues |
| `washkrew_firebase`, `washkrew_ui` | all tests pass · 0 issues |
| `washkrew_purchase_ui`, `washkrew_referrals` | all tests pass · lint infos only (pre-existing) |
| `tool/ios_test.dart` | pass |

```sh
npm run firebase:test
cd apps/flutter/customer && flutter analyze && flutter test
cd apps/flutter/captain  && flutter analyze && flutter test
```

**Not proved yet (needs devices / deploy):** the server changes on the live project, a real
two-phone test booking, the GPS map step and the draggable arc on a physical iPhone.

---

## 6. App Store status (read from App Store Connect, 14 Nov, 10:00 IST)

| App | Version in review | Submitted | Status | Release |
|---|---|---|---|---|
| WashKrew (Customer) | 1.0.4 (10) | 5 Nov, 1:03 AM, Sumit Mandal | Waiting for Review | Manual |
| WashKrew Captain | 1.0.5 (11) | 5 Nov, 1:03 AM, Sumit Mandal | Waiting for Review | Manual |

Neither has been picked up by App Review yet; no rejection or message. **They don't contain
any of this v2 work.** Options for Aman and you:
- **A.** Let 1.0.4 / 1.0.5 finish review, release them, then submit 1.0.6 / 1.0.7 as an update.
- **B.** Remove both from review and submit 1.0.6 (11) / 1.0.7 (12) now (back of the queue).

Before either: deploy the server (§3) so live builds show what the server can sell; App Store
archives never get the preview unlock. Reviewer sign-in notes (Firebase test number, fixed
code) are already in both versions.

---

## 7. Still open (not in this push)

AutoPay and plan renewal · server-side plan cancel/edit (customers cancel visits one by one) ·
all plan visits to one Captain (`claimJob` siblings) and the Captain's recurring-assignment
list · `listOpenJobs` · **referrals server** (codes, attribution, count 5 washes, 1 free
Premium wash valid 1 year; referred customer gets nothing extra; Captain referrals later) ·
gate-pass upload, photo reuse, vehicle-not-found recovery · Captain milestones
(`captainMilestones`, someone to own the 100-wash merchandise).
