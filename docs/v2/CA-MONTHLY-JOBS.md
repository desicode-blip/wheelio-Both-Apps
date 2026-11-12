# CA-MONTHLY-JOBS — monthly recurring jobs ring like one-time jobs

**13 Nov 2026, Aman.**

## Captain app

- **Gold alert (new):** when a customer's monthly plan needs a Captain, the app rings and opens a
  full gold screen, separate from the one-time job alert:
  - a **MONTHLY · RECURRING** badge, and a countdown when the offer has an expiry;
  - pay **per visit** in big type, with "13 visits · about ₹455 this month";
  - Days (Mon, Wed, Fri), Time, and Start date;
  - the place and the vehicle;
  - the visit dates (first 6, "+7" shows all);
  - "An estimate from planned visits, not a fixed salary."
  - **Accept monthly job** (green) or **Not now**.
- **Jobs tab → Find new jobs:** two tiles at the top, each with a count.
  - **One-time jobs:** single washes still open nearby, including any the Captain missed, each with
    Accept.
  - **Monthly jobs** (gold): open monthly jobs; tapping one opens the gold screen.
- **Me → Recurring assignment** stays, showing the accepted calendar.
- One-time job alerts no longer include monthly offers; they ring on the gold screen instead.
  Tapping a "new job" notification for a monthly offer opens the gold screen.

## Server work (Ajay)

- Offer monthly plans to Captains as ordinary job offers. The offer's job document carries
  `plan: {totalVisits, dates: ['YYYY-MM-DD', …]}` plus `visitTerms`, with the pay **per visit**.
  The app treats any offer with `plan.totalVisits > 1` (or more than one date) as a monthly job.
- **Accept** uses the same `claimJob` call; it should assign the whole plan's visits. **Not now**
  uses the same reject.
- **Push:** use kind `newMonthlyJob` with the title "Monthly job near you", so the Captain's phone
  shows it differently from a one-time job.
- **Missed jobs:** today the two lists show the offers still open for this Captain (`liveOffers`).
  To list jobs a Captain missed that are still unassigned, add a `listOpenJobs` query (area + work
  hours) and the lists will use it.

## Files

- `captain/lib/features/monthly_jobs.dart` (new): gold alert, Find jobs tiles, open-jobs lists.
- `captain/lib/features/v2_job.dart`: reads `plan.dates`.
- `captain/lib/main.dart`: monthly offers ring the gold screen.
- `captain/lib/screens/home.dart`: the one-time alert skips monthly offers; Jobs tab tiles.
- `captain/lib/data/store.dart`: routes, notification tap.
- Gallery entries W22r and W25a.
- Test: `captain/test/monthly_jobs_test.dart`.
