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

## 13 Nov (later): accepted monthly jobs (Aman)

- **Gold everywhere:** recurring visits look like a golden ticket on Home → Today's plan (gold card
  with a **Recurring** tag) and in Jobs (gold card). Jobs cards carry **Recurring** or
  **One-time**. Warnings (30 min left, late) still use amber and red.
- **Accepting** adds the job to *Recurring assignments*. In sample builds its visits for the coming
  week join the plan, so today's visit shows on Home. Live visits come from the server as orders
  that carry `plan`.
- **Jobs tab** shows a gold **Recurring assignments (n)** button (it replaces "Recurring
  assignment · View your calendar"). **Me → Recurring assignments** opens the same list.
- **List:** one gold card per job, with the place, vehicle, M–S weekday circles (visit days filled),
  the next visit and the monthly total.
- **Detail** (redesigned, less text):
  - the monthly package (₹ total) and the visits this month;
  - weekday circles and time;
  - the place and vehicle, then the visit dates (today highlighted);
  - two short notes;
  - **See today's jobs** goes to Home, which lists one-time and recurring visits together.
  - "₹35 per completed visit" and the long paragraphs are gone.
- **Cancel this recurring job:** this must be done at least 2 days ahead. Visits in the next 2 days
  stay with the Captain; later visits go back to other Captains. The confirmation lists both.
  BACKEND (Ajay): `cancelRecurringAssignment({assignmentId})` with that rule, and a list of a
  Captain's accepted assignments, so the list survives a restart (today it is kept in memory).
