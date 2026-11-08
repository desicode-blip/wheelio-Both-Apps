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

Built; Customer tests 103/103, package tests 28/28. iPhone check pending. Phases 2–5
(monthly plans, referrals, vehicle not found, Captain recurring/earnings) to follow.
