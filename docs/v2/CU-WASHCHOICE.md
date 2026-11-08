# CU-WASHCHOICE — Choose your wash and your own time windows

Feature map: [FEATURES.md](FEATURES.md). Screens: C05 (vehicle), C05w → CU-02 "Choose your
wash", C12 → CU-06/CU-14 "When is your vehicle free?", C13 → CU-15 Check and pay.

Source: ChatGPT handoff `~/Desktop/WashKrew_Final_Product_Handoff_2026-11-08`
(prototype `af71723`, built on our `721649a`; integrity check passed 8 Nov). Aman approved
on 8 Nov: two-step vehicle → wash; custom windows replace the slot checkboxes; server
prices until real prices are approved; build in five phases (this is phase 1).

## 8 Nov 2026 — Phase 1: wash choice and custom time windows

### What changes for the customer (when switched on)

- **C05 vehicle** — "What should we wash?" with vehicles only, no prices.
- **Choose your wash** — vehicle badge; *Exterior only* / *Exterior + interior*; Basic,
  Premium, Extra Premium with the price on the right; *What's included?* sheet; total and
  Next at the bottom. Options without an approved server price show **Coming soon** and
  can't be picked (today: only Basic exterior has a price — the vehicle's current price).
  The *One-time / Monthly plan* toggle stays hidden until phase 2.
- **When is your vehicle free?** — Today / Tomorrow / next day, or any date; one or more
  windows with exact start and end times (e.g. 8:15–10:45 AM and 7–11 PM). Nudges under
  the windows (Aman, 8 Nov):
  - shorter than 1 hour → "This window is shorter than 1 hour. Give at least 1 hour so your
    Captain has time to reach you and wash."
  - ends after 11 PM (or starts at/after 11 PM) → "We don't wash after 11 PM. Choose an end
    time by 11 PM."
  - starts before 4 AM → "We start at 4 AM. Choose a start time from 4 AM."
  - too late today for a 1-hour window → "It's too late for a wash today…" and it opens on
    tomorrow; reversed, overlapping, incomplete and already-ended windows are refused too.
  - picking a start fills a 2-hour end automatically (inside service hours).
- **Check and pay** — one card: *One-time wash* + **Change**, *Basic · Exterior only*, the
  day and windows. Notes and the money lines only when there is something to show (notes,
  free wash or wallet). Wallet toggle, cancellation link and plate check from 6 Nov stay.
- Book again → Change wash, a saved vehicle (C04) and "Book again" after a booking all use
  the same new screens.

### Switches (nothing changes for customers until Ajay turns them on)

| Switch | Where | Effect |
|---|---|---|
| `washChoiceV2` | `config/operations` (liveConfig) | New flow for everyone |
| Preview new features | Profile → tap **WashKrew** at the bottom 7 times (this phone only) | New flow on this phone; paying is blocked until the server switches below are on, with a plain "Preview… nothing was charged" line |
| `customTimeWindows` | liveConfig | Server accepts exact-minute windows; Pay allowed |
| `washTiers` | liveConfig | Server accepts `serviceLevel` + `coverage`; Premium/interior payable when priced |
| `washPrices` | liveConfig `{car|sedan|suv|bike: {basic|premium|extraPremium: {exterior|exteriorInterior: rupees}}}` | Prices shown; missing = Coming soon |
| `serviceHours` | liveConfig `{startMinute, endMinute}` | Window limits (default 240–1380, 4 AM–11 PM) |
| `monthlyPlans` | liveConfig | Shows the Monthly plan toggle (phase 2) |

### Not copied from the handoff (demo-only)

Sample sign-in, offline bridge, demo checkout and repositories, URL fixtures, the
`credit = 0` wallet reset in its adapter, draft fixture prices, "simulated availability" copy.

### Files changed

- New package `apps/flutter/packages/washkrew_purchase_ui/` (handoff module + 2 changes:
  `time_windows.dart` 1-hour/4 AM/11 PM nudges, host hours, auto end, late-day start;
  `screens.dart` `priceFor`/Coming soon, `allowMonthly`, host header, Done label) + tests
  (`time_window_nudges_test.dart` new).
- `customer/lib/purchase/wash_choice.dart` (new) — `WashStepScreen`, `TimeStepScreen`, `customSlot`.
- `customer/lib/data/models.dart` — `TimeSlot.minuteWindows`.
- `customer/lib/data/store.dart` — switches, `washPrice`, service hours, preview flag,
  draft `serviceLevel`/`coverage`/`chosenPrice`, request fields, preview block.
- `customer/lib/screens/booking.dart` — C05 vehicle-only in the new flow; Check and pay summary.
- `customer/lib/screens/home.dart` — Profile preview switch.
- `customer/lib/main.dart`, `pubspec.yaml` — routes and package.
- `customer/test/wash_choice_flow_test.dart` (new).

### Backend needed (Ajay)

1. **Exact-minute windows.** `createBooking` accepts `minuteWindows: [{startMinute,
   endMinute}]` (sorted, non-overlapping, each ≥ 60 min, inside service hours, same-day not
   ended). Store them on the booking; `startHour`/`endHour`/`windows` still sent as the
   span for older readers. Availability, dispatch, offer timeouts, slot expiry, the Captain
   app (job card, W25/W26) and admin must read minute windows. Then set
   `customTimeWindows: true`.
2. **Service hours.** Today's server cut-off is 10 PM; Aman wants 11 PM. Set
   `serviceHours {startMinute: 240, endMinute: 1380}` once operations agree.
3. **Wash tiers.** Accept `serviceLevel` (`basic|premium|extraPremium`) and `coverage`
   (`exterior|exteriorInterior`); price server-side from `washPrices`; show them to the
   Captain. Then set `washTiers: true` and the prices. Bikes: exterior only.
4. Turn on `washChoiceV2` when 1–3 are live.

### How to test on the iPhone

Profile → tap **WashKrew** at the bottom 7 times ("Preview new features: on"). Home → Book a
wash → vehicle (no prices) → Choose your wash (Basic price, others Coming soon) → plate,
photos, place → time: try 8:15–8:45 (1-hour nudge), 10–11:30 PM (11 PM nudge), then a valid
window → Check and pay shows the summary card; Pay is blocked with the preview line. Tap
7 times again to turn it off.

### Status

Built; see the 8 Nov phases 2–5 entry below for the current test counts.

## 8 Nov 2026 — Phases 2–5: everything else in the handoff (preview)

Aman, 8 Nov: adopt everything in the handoff. The handoff's own notes say these features
are a disconnected prototype: plans, mandates, referrals, rewards, evidence, review and
replacement keep state on the phone. So every screen is integrated as designed, but opens
**only with Preview new features** (Customer: Profile → tap *WashKrew* ×7; Captain: Me →
tap *WashKrew Captain* ×7), says "preview" where state is local, and can't pay. Real
customers, real jobs and real money are untouched until Ajay connects each server part.

### Phase 2 — Monthly plans (Customer)

- *Choose your wash* shows **One-time / Monthly plan**, days per week (reprices every tier).
- Days screen ("Pick your 3 days", start date) → time windows (same 1-hour / 11 PM rules)
  → Check and pay: plan card with all dates, **Renews monthly** (UPI AutoPay ·
  Recommended / debit-card mandate / prepaid invoice), *Plan policy* dialog. Pay is blocked
  ("monthly plans need the server update"); **See the plan screens (preview)** opens the
  confirmation and **Your monthly plan**: cancel subscription (paid cycle kept, ₹0 refund),
  resume (new authorization), edit next cycle (days, frequency, windows; current cycle
  unchanged), all dates. Bookings shows the plan card with "Subscription cancelled · Paid
  visits remain" when cancelled.
- Prices: no monthly price exists on the server; the preview shows the handoff's draft
  prices marked **· draft** (for customers they'd say Coming soon).

### Phase 3 — Referrals (both apps)

- Customer: Profile → *Refer & earn Premium washes* (code, invite link, progress, free
  Premium wash after a friend's 5 paid washes; *Use* starts a booking with Premium locked,
  ₹0 — blocked from paying in preview); *Were you referred?* code entry; *Referral progress*
  controls.
- Captain: sign-up has an optional referral code; Me → *Refer a Captain* (₹50 + ₹50 at 5
  washes, +₹500 at 50 = ₹550); Money → **Referral bonuses** card, separate from wash pay;
  *Admin referral view* (read-only, sample data).
- Invite link on a phone shows `https://washkrew.com/?ref=CODE` (no link handling yet).

### Phase 4 — Vehicle not found, replacement, make-up (both apps)

- Captain (Me → *Vehicle not found*): confirm parking → contact owner → **record video with
  the phone camera** (retake allowed) → read-only review → send proof → "received, in
  review" (not approval). Outcomes via *Review outcomes*: approved (50% of the visit quote,
  separate receipt on Money), clearer proof requested, dispute, owner corrected parking,
  cancelled/replacement pending, replacement arranged, customer credited, failed upload/retry.
- Captain *Cancel a wash*: reason and exact deduction before confirming (0% within 5 min of
  accepting; then ≥24 h 10%, 2–24 h 50%, <2 h 100%).
- Customer (Profile → *Vehicle not found*): owner evidence and response, approved with no
  refund + dispute, dispute pending, corrected location, quiet replacement search, Captain
  change, full visit credit, monthly make-up proposal/confirmation, visit credit after
  make-up runs out. Bookings shows an open case card.
- The video stays in the Captain app's memory; the Customer side says it plays "once video
  upload is connected".

### Phase 5 — Captain pay and recurring work

- Job offer card shows the server's exact **visit pay** (one-time or monthly-plan visit,
  service, coverage, minutes, listen button) when a job carries `visitTerms`; Accept is
  disabled if those terms have no confirmed pay. Today's jobs carry none, so offers look as
  before. Me → *Job offer pay* shows both examples (₹120 / ₹35 — illustrative, not rates).
- Me → *Understand your pay* (EN/HI/TE, listen).
- Me → *Recurring assignment*: vehicle, place, every date, per-visit pay and estimated
  cycle total ("not a salary"); accepting shows a calendar card on Jobs.

### Applied for everyone (no switch)

- Tracking no longer shows the "₹… held safely" badge (handoff CU-33).
- "assign a captain" → "assign a Captain" on the booked screen.

### Not copied

Offline bridge, forced sample sign-in, URL fixtures, the j1 sample-job wiring (a real job
never opens a preview case), the 1-hour offer timeout, the web video frame (replaced by the
phone camera), the demo checkout screen, Hindi/Telugu web fonts (iOS has its own).

### Files

- New packages: `washkrew_referrals`, `washkrew_captain_jobs`, `washkrew_service_recovery`
  (+ `phone_evidence.dart`, `startCancelling`), with the handoff's tests.
- Customer: `lib/features/preview_features.dart` (new), `lib/purchase/wash_choice.dart`
  (monthly steps), `store.dart` (plans, lazy previews, blocks), `booking.dart` (Check and pay
  monthly/reward), `home.dart` (Bookings cards, Profile preview list), `live.dart`,
  `auth_pay.dart`, `main.dart`, `pubspec.yaml`; tests `handoff_preview_test.dart`,
  `wash_choice_flow_test.dart`.
- Captain: `lib/features/preview_features.dart` (new), `store.dart` (`Job.visitTerms`,
  preview flag, lazy previews), `home.dart` (offer terms, Jobs cards), `money.dart` (Money
  cards, Me preview list, switch), `welcome.dart` (sign-up code), `main.dart`,
  `pubspec.yaml`; test `handoff_preview_test.dart`.

### Backend needed (Ajay) — from the handoff's SERVER-CONTRACTS.md

1. **Plans:** plan/cycle documents, monthly prices, UPI AutoPay / debit mandate / invoice
   with Razorpay subscriptions or e-mandates, cycle charging, cancel (stop renewal, keep paid
   cycle, ₹0 refund), resume (new authorization), next-cycle amendments, per-visit
   generation and assignment. Then `monthlyPlans: true` and a plan checkout call.
2. **Referrals:** one code per verified account and role, attach after OTP, reject
   self/invalid/conflicting codes, count paid completed washes server-side, grant ₹50/₹500
   cash (payout) and Premium wash credits once each, reserve/redeem/release the free wash.
3. **Vehicle not found:** private video upload and storage with retention, case documents,
   human review in admin (approve / ask for proof / dispute), owner response, 50% Captain
   compensation in the ledger, block the Captain's further work on that job.
4. **Captain cancellation and replacement:** server quote of the deduction band from
   acceptance time, release + atomic re-offer, customer quiet update, make-up proposals for
   monthly visits, visit-only credit when nothing works.
5. **Visit pay:** send `visitTerms` (net pay in paise, kind, service, coverage, minutes,
   visit n of N) on each offer; recurring assignments as a calendar commitment.
6. Replace the in-memory preview repositories (`DemoReferralRepository`,
   `DemoRecoveryRepository`) with server-backed ones before any switch goes on.

Owner decisions still open (handoff CONFIGURATION.md): final tariff and Captain rates,
Premium reward scope/expiry, evidence thresholds and review timelines, replacement
deadlines, mandate timing, translations.

### How to test on the iPhone

Customer: Profile → tap **WashKrew** ×7 → Book a wash → Monthly plan → … → See the plan
screens; Profile → Refer & earn / Were you referred? / Vehicle not found.
Captain: Me → tap **WashKrew Captain** ×7 → the Preview list (8 entries).

### Status

Built; Customer 112/112, Captain 48/48, modules 58/58 tests pass. iPhone check pending.

