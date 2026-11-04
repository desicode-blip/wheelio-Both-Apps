# Website handoff for Ajay: 4 November 2026

Everything in this push is the **washkrew.com website** (`apps/website/`) and the policy text behind it (`release/store/`). The Customer and Captain apps, Functions, Firestore/Storage rules and payments are **not changed**.

The pages now promise a few things the apps and backend do not do yet. Please finish the **"Before you deploy"** items first, then deploy the website. Full detail is in `docs/CHANGES-2026-11-03-POLICY-PAGES.md`.

## What changed on the website

1. **New pages:** `/privacy`, `/terms`, `/support`, `/delete-account`, `/policies`. They are generated from Markdown in `release/store/policies/` by `node release/store/prepare-website.mjs --stage-approved`. Edit the Markdown, never the generated HTML.
2. **Footer:**
   - New "Help and policies" column.
   - Support phone (24/7) and email.
   - Section labels in small uppercase.
   - Distinct App Store (app grid) and Google Play (play triangle) icons. These are generic icons. Use the official store badges once the apps are published.
3. **Account deletion form** on `/delete-account`. On submit it opens a pre-filled email to info@washkrew.com and POSTs the request to `/api/account-deletion-request`, an endpoint you need to build (below).
4. **Positioning:** no more "gated societies" anywhere. The copy says "Now live across Hyderabad", "near where you live" and "area by area".
5. **What we wash, cars:** adds "Complete wash, including interiors", greyed out and tagged "Coming soon". The apps should keep not offering it.
6. **Small things:**
   - Links to `/#get-app` and `/#get-captain-app` open the matching app prompt.
   - Policy pages fade in on load.
   - `sitemap.xml` lists the new pages.
   - `release/store/release.json` records Aman's decisions and three approvals.

## Aman's decisions the pages now state

| Topic | Decision |
|---|---|
| Legal name and address | Washkrew, Works/Office No. 08 (FF), Block: MART, Mahagun Moderne, Plot No. GH-02, Sector 78, Noida, Uttar Pradesh 201301 |
| Support | info@washkrew.com, +91 80885 16875. Phone 24/7, 365 days. Email replies within 6 hours |
| Grievance Officer and Apple review contact | Aman (Aman Maheshwari), same email and phone. Complaints acknowledged within 48 hours, resolved within 1 month |
| Customer cancellation | Within 5 minutes of confirmation: **98%** back as wallet credit. After 5 minutes and at least 2 hours before the wash window: **50%**. Under 2 hours before the window: **nothing**. WashKrew-side failure or upheld complaint: **100%** as wallet credit |
| Wallet credit | Expires **1 year** after it is added |
| Retention | Payment/invoice/wallet/payout records **8 years**. Wash photos, videos and voice notes **90 days** after the wash. Captain ID documents and selfies **90 days** after the approve/decline decision. Job locations 90 days. Support messages 1 year after closed. Deletion-request records 3 years. Logs up to 90 days |
| Website deletion requests | Acknowledge within 48 hours, verify ownership on the registered number (never ask for OTP), complete within **90 days**, confirm when done |
| Aadhaar | Full or masked accepted; masked recommended; review stays manual |

## Before you deploy (the pages promise these)

| # | Work | Notes |
|---|---|---|
| 1 | **Cancellation: first band 98% instead of 100%** | Only change to the current `walletByTime` policy: 9800 bps within 5 minutes. The 2-hour cutoff, 50% band and 0 after stay. Update the in-app cancellation quote/copy and tests; keep older bookings on their saved policy. |
| 2 | **Wallet credit expiry after 12 months** | Expiry per credit (top-ups, cancellation credit, service-failure credit, offers). Spend oldest first, expire unused credit, show expiry dates in the wallet. Decide how existing balances are dated (suggest 12 months from go-live). |
| 3 | **Retention clean-up jobs** | Scheduled deletion of wash media after 90 days (skip open complaints), Captain ID documents/selfies 90 days after decision (keep a "verified on/by" record), job locations after 90 days, support messages 1 year after closed, deletion requests after 3 years. Set Cloud Logging retention to 90 days or less, and make sure any backups roll off within 90 days. |
| 4 | **Deletion request endpoint** | HTTP function (e.g. `accountDeletionRequest`, `asia-south1`) plus this rewrite in `apps/website/firebase.json`: `{"source": "/api/account-deletion-request", "function": {"functionId": "accountDeletionRequest", "region": "asia-south1"}}`. Body: `{role: "customer"\|"captain"\|"both", name, phone: "+91XXXXXXXXXX", email?, reason?, source}`. Reply `200 {"reference": "DEL-…"}`; any other reply makes the page fall back to the email. Validate, ignore the honeypot field `website`, rate-limit per IP and phone. |
| 5 | **Admin portal list** | Store requests (e.g. `accountDeletionRequests`, status `new` → `acknowledged` → `verified` → `completed`/`declined`) and show them in `/admin/` with the 90-day due date. Reuse the existing role-scoped deletion routine. Optionally email info@washkrew.com and the requester. |
| 6 | **Complaint reference numbers** | The support page promises one for every complaint. Make sure in-app Help/Report a problem and email replies give one. |
| 7 | **In-app support/legal config** | `node backend/firebase/operator.cjs publish-content <file>` with phone, email, hours "Phone 24/7. Email replies within 6 hours.", entity "Washkrew", Grievance Officer "Aman", `termsPrivacyUrl: https://washkrew.com/policies`. Preview, then `--confirm`. |

Optional: a short hint on the Captain document step, "You can upload a masked Aadhaar".

## Deploy

```sh
git pull --ff-only origin staging
cd apps/website
npx -y firebase-tools@latest deploy --only hosting:website --project wheelio-apps
```

Add the rewrite from #4 in the same deploy once the function exists. A rewrite to a function that does not exist yet will fail the deploy, so leave it out until then. Nothing else needs deploying for the website.

## Check after deploy

- `https://washkrew.com/privacy`, `/terms`, `/support`, `/delete-account` and `/policies` load over HTTPS without login.
- Every footer link opens the right page. `/terms#cancellation-and-refunds` jumps to the cancellation table.
- On the delete form: an empty submit shows errors. A valid submit opens the email and, once #4 exists, shows a `DEL-` reference and appears in `/admin/`.
- `node release/store/check.mjs` passes the URL checks. Its other gates (App Store IDs, age rating, store privacy answers, reviewer access, screenshots) are still open.

## Store consoles

- Privacy policy URL: `https://washkrew.com/privacy`
- Support URL: `https://washkrew.com/support`
- Google Play account-deletion URL: `https://washkrew.com/delete-account`

App Privacy (Apple) and Data safety (Google) answers must match the retention table in the privacy policy.

## Preview

Aman reviewed the whole site, including every policy page, at https://claude.ai/artifact/7c3eP8xAZSfwTpPX8BPcct. Locally:

```sh
node release/store/prepare-website.mjs --preview
```

This writes `build/store/policy-preview/`. Serve it with clean URLs, or deploy to a Firebase preview channel:

```sh
firebase hosting:channel:deploy review --only website
```
