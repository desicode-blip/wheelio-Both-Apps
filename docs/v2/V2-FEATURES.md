# v2 — what is standard, what is sample data, what the server must do

12 Nov 2026 (Aman): the v2 features are a standard part of both apps, not hidden. Until
the server parts exist they run on sample data. Switch everything off with
`config/operations.v2Features = false` (both apps read it from liveConfig).

## Customer → Captain: does each feature reach the other app?

| Customer feature | Sent with the booking | Captain shows it | Works on today's server |
|---|---|---|---|
| Own time windows | `minuteWindows: [{startMinute,endMinute}]` (+ legacy `windows`) | exact windows on offer, Jobs, Go to vehicle (`JobExtras`) | Only when the windows equal the server's fixed slots (e.g. 8–10 AM); others are blocked at Pay with a plain message |
| Basic / Premium / Extra Premium, interior | `serviceLevel`, `coverage` (when `washTiers` is on) | "Premium · Water wash + inside" on the booking strip and chip | Basic exterior only; others blocked at Pay |
| Monthly plan | — (no plan API yet) | "Monthly plan · Visit 3 / 13" (`plan {visitNumber,totalVisits}`), recurring assignment screen | No. Sample only |
| Gate pass | `uploadGatePass` (stub) → `entryPass.path` | image on Go to vehicle (W27) | No. Needs upload callable + rule |
| Use last time's photos | `reusePhotosFrom` | customer photos as usual | No. Needs server copy |
| Vehicle not found / cancel / replacement / make-up | — | both apps have every screen | No. Each app has its own sample case |
| Referrals | — | both apps have every screen | No. Sample codes and progress |
| Visit pay on offers | — | `VisitTermsCard` when the offer has `visitTerms` | No. Offers show today's pay row |

Sample data lives in: `DemoReferralRepository`, `DemoRecoveryRepository` (in-memory),
`PurchaseSelection.quotePaiseFor` (sample prices), Captain sample jobs j8/j9,
`exampleOnce`/`exampleMonthly` pay terms (₹120 / ₹35 — illustrative).

## For Ajay: server work, smallest first

1. **Copy v2 booking fields onto the job/offer** — in `createBooking` store
   `minuteWindows`, `serviceLevel`, `coverage` and include them in the offer and Captain
   job payloads. The Captain app already reads them (`captain/lib/features/v2_job.dart`).
2. **Exact time windows** — validate (sorted, no overlap, each ≥ 60 min, inside
   `serviceHours`, not ended), map to capacity, match Captains by their `workingSlots`
   minutes, expire by the last window's end. Then `customTimeWindows: true` and
   `serviceHours: {startMinute: 240, endMinute: 1380}` (11 PM).
3. **Gate pass** — callable `uploadGatePass(orderId)` + Storage rule (owner writes, the
   assigned Captain reads); set `entryPass.path`; notify the Captain.
4. **Photo reuse** — copy `customerPhotos` from `reusePhotosFrom` (same owner) at booking.
5. **Wash tiers** — price from `washPrices`, accept `serviceLevel`/`coverage`,
   `washTiers: true`.
6. **Visit pay** — `visitTerms` on offers (net paise, kind, service, coverage, minutes,
   visit n/N).
7. **Vehicle not found, Captain cancellation, replacement, make-up** — contracts in
   `packages/washkrew_service_recovery/lib/src/contracts.dart`; private video upload,
   human review in admin, ledger entries.
8. **Monthly plans and AutoPay; referrals** — see CU-WASHCHOICE.md "Backend needed".

Release gates: no customer release while sample prices, sample referral codes or sample
cases can be seen on a live build (items 5, 7, 8) — or set `v2Features: false`.
