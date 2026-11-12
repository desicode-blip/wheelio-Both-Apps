# v2 merge guide — bringing the v2 features onto a newer staging

Branch `v2/cu-bookings-rebook`, based on staging `e67a15e` (+ the App Store commits up to
`ecafb1b`). Every v2 edit in an existing file carries a `// v2` comment, so
`git grep -n "// v2"` lists all seams. New code lives in new files wherever possible.

## 1. Self-contained (copy as they are; no conflicts expected)

| Path | What |
|---|---|
| `apps/flutter/packages/washkrew_purchase_ui/` | Choose your wash, own time windows, monthly plan screens |
| `apps/flutter/packages/washkrew_referrals/` | Referral models and screens |
| `apps/flutter/packages/washkrew_captain_jobs/` | Visit pay terms, pay guide, recurring assignment |
| `apps/flutter/packages/washkrew_service_recovery/` | Vehicle not found, cancellation, replacement, make-up |
| `apps/flutter/packages/washkrew_ui/lib/src/local_flags.dart`, `notify_ask.dart` | On-device flags/files; notification first-ask |
| `customer/lib/purchase/wash_choice.dart` | Booking steps for wash choice, time, monthly plan |
| `customer/lib/features/preview_features.dart` | Referral and vehicle-not-found screens (sample repositories) |
| `customer/lib/screens/gate_pass.dart`, `sticky_list.dart`, `vehicle_detail.dart` | Gate pass card; sticky "Add new vehicle" list; Your vehicle screen |
| `captain/lib/features/v2_job.dart` | `JobExtras`: exact windows, service level, plan visit read from a job |
| `captain/lib/features/preview_features.dart` | Captain referral, pay, recurring, vehicle-not-found screens |
| all `test/*` files added by v2 | |

## 2. Seams in existing files (expect conflicts if staging changed the same lines)

**Customer**
- `pubspec.yaml` — 3 path packages.
- `lib/main.dart` — imports; routes `N.washType → WashStepScreen`, `N.timeSlot → TimeStepScreen`,
  + plan/referral/recovery routes.
- `lib/data/models.dart` — `Vehicle.photos`, `Order.gatePass*`, `TimeSlot.minuteWindows`,
  `plateKey`/`plateProblem`.
- `lib/data/store.dart` — route enum additions; `BookingDraft` v2 fields; Book again
  (`openRepeat` …); local vehicles; gate pass stub; notification first-ask; the block
  starting `v2 (12 Nov, Aman)` (flags, prices, hours, `serverWindowsFor`,
  `washChoiceBlockedReason`, plans, sample repositories); in `createOrderAndPay`:
  `serverWindowsFor`, `minuteWindows`/`serviceLevel`/`coverage` fields, unpaid-booking
  release and retry reuse (`_releaseUnpaid`, `_draftSig`), `_paidOutcome`.
  **This is where Ajay's payment work is most likely to overlap** — keep his payment
  logic, then re-apply: request fields, the blocked check, and (if he has not solved it
  another way) the retry reuse.
- `lib/screens/booking.dart` — C05 vehicle step, `WashOptionCard`, C06 plate check and
  `PlateFixSheet`, camera side label, C12 heading/checkbox, C13 `ReviewScreen` rewrite.
- `lib/screens/home.dart` — Book again (C45/C45b), vehicles list/edit, Bookings cards,
  Profile rows, review-tools switch.
- `lib/screens/auth_pay.dart` — gate pass card, notify-first screen, "Payment not
  completed" state. `lib/screens/live.dart` — gate pass card, no held-safely badge.
- `packages/washkrew_firebase/lib/src/checkout_flow.dart` — `closed: true` when Razorpay
  is closed. `live_backend.dart` — `requestPushPermission()`.
- `packages/washkrew_ui/lib/src/components.dart` — `WChip.checkbox`.

**Captain**
- `pubspec.yaml` — 3 path packages. `lib/main.dart` — imports and routes.
- `lib/data/store.dart` — route enum additions; `Job.visitTerms`, `Job.extras`,
  `whenLabel`; `JobExtras.fromOrder(o)` in `_orderJob`; flags and sample repositories;
  two sample jobs (j8, j9); notify-first.
- `lib/screens/home.dart` — offer card visit terms, Jobs-tab cards, W27 gate pass image,
  notify-first. `lib/screens/parts.dart` — service level / plan visit on the booking strip.
- `lib/screens/money.dart` — Money cards, Me rows, review-tools switch.
- `lib/screens/welcome.dart` — optional referral code at sign-up.

## 3. How to merge

```sh
git fetch origin staging
git checkout v2/cu-bookings-rebook && git merge origin/staging
# resolve: take staging's payment/backend logic, re-apply the v2 seams above
cd apps/flutter/customer && flutter pub get && flutter analyze lib test && flutter test
cd ../captain && flutter pub get && flutter analyze lib test && flutter test
```

Expected results before the merge: Customer 115 tests, Captain 48, packages 58 — all pass.
