# Changes 3 November 2026: policy pages and account deletion requests

For the developer (Ajay). Website and policy text only. The Customer and Captain apps, backend, rules and payments are **not changed**. Several items below need backend work before these pages go live, because the policies now promise them.

## Owner decisions (Aman, 3 November 2026)

- Legal name **Washkrew**. Registered office (legal address): Works/Office No. 08 (FF), Block: MART, Mahagun Moderne, Plot No. GH-02, Sector 78, Noida, Uttar Pradesh 201301.
- Support: **info@washkrew.com**, **+91 80885 16875**. Phone answered 24/7, 365 days; emails answered within 6 hours.
- Grievance Officer and Apple review contact: Aman Maheshwari, shown on the pages as "Aman", same email and phone.
- Retention: payment and invoice records **8 years**; wash photos **90 days**; Captain ID documents and selfies **90 days**.
- Account deletion requested from the website: completed **within 90 days**. Each request (1) opens a pre-filled email to info@washkrew.com and (2) raises a request in the admin portal.

## What changed

1. **Final policy text** in `release/store/policies/`: `privacy.md`, `terms.md` (cancellation and refunds is section 5, anchor `#cancellation-and-refunds`), `support.md`, `delete-account.md`. Written for DPDP Act 2023, IT Act/Rules, Consumer Protection (E-Commerce) Rules 2020, Apple 5.1.1/5.1.2 and Google Play User Data and account-deletion rules. The cancellation rules match `docs/WALLET-CANCELLATION-2026-10-31.md`.
2. **`release/store/prepare-website.mjs` rewritten.** It builds the pages in the website's own design (homepage header, footer and sprite are reused). `--preview` writes a whole-site preview to `build/store/policy-preview`; `--stage-approved` writes into `apps/website/public`. The approval and draft-wording gates are kept.
3. **Pages staged** in `apps/website/public`: `/privacy`, `/terms`, `/support`, `/delete-account`, `/policies` (all with `cleanUrls`). Added to `sitemap.xml`.
4. **Homepage footer:** new "Help and policies" column (Help and support, Privacy policy, Terms of use, Cancellation and refunds, Delete your account) and the support phone (24/7) and email. Links to `/#get-app` and `/#get-captain-app` now open the matching app prompt.
5. **`release/store/release.json`:** registered office, support hours, Grievance Officer, retention, and three owner approvals recorded with a dated note. Age rating, store privacy answers, reviewer access and screenshots stay `false`.

To change policy text later: edit the Markdown, run `node release/store/prepare-website.mjs --stage-approved`, commit, deploy.

## Backend work needed before go-live

| # | Task | Details |
|---|---|---|
| 1 | **Deletion request endpoint** | HTTP function, e.g. `accountDeletionRequest` in `asia-south1`, plus a Hosting rewrite in `apps/website/firebase.json`: `{"source": "/api/account-deletion-request", "function": {"functionId": "accountDeletionRequest", "region": "asia-south1"}}`. The page already POSTs there. |
| 2 | Request contract | Body JSON: `{role: "customer"\|"captain"\|"both", name, phone: "+91XXXXXXXXXX", email (optional), reason (optional), source: "washkrew.com/delete-account"}`. Reply `200 {"reference": "DEL-…"}`. Any non-200 makes the page fall back to "send the email". Validate server-side, ignore the honeypot field, rate-limit per IP and per phone, and never trust the phone as proof of ownership. |
| 3 | Admin portal list | Store in e.g. `accountDeletionRequests` (status `new` → `acknowledged` → `verified` → `completed` / `declined`, with timestamps and reviewer). Show in `/admin/` with the 90-day due date. Promised to users: acknowledge within **48 hours**, verify by contacting the registered number (never ask for OTP), complete within **90 days**, tell them when done. Reuse the existing role-scoped deletion routine. |
| 4 | Email to info@washkrew.com | Optional server copy on each new request (the page also opens the user's own email). If the user gave an email, send them a confirmation with the reference. |
| 5 | **Retention jobs** (scheduled) | Delete wash photos, videos and voice notes **90 days after the wash** (skip bookings with an open complaint until resolved). Delete Captain ID documents and selfies **90 days after the approve/decline decision** (keep only a "verified on, by" record). Delete Captain job location points 90 days after the wash. Support messages: 1 year after closed. Deletion-request records: 3 years. Payment, invoice, wallet, earnings and payout records: 8 years. |
| 6 | Logs and backups | Set Cloud Logging retention to 90 days or less. If Firestore/Storage backups exist, make sure they roll off within 90 days. |
| 7 | Complaint reference numbers | The support page promises a reference number for every complaint (E-Commerce Rules). Make sure in-app Help/Report a problem and email replies include one. |
| 8 | Publish in-app support/legal config | `backend/firebase/operator.cjs publish-content` with support phone/email, hours "Phone 24/7. Email replies within 6 hours.", legal entity "Washkrew", `termsPrivacyUrl: https://washkrew.com/policies`. Preview first, then `--confirm`. |
| 9 | Deploy the website | `cd apps/website` then `npx -y firebase-tools@latest deploy --only hosting:website --project wheelio-apps` (add the rewrite from #1 in the same deploy once the function exists). |
| 10 | Store consoles | Privacy URL `https://washkrew.com/privacy`, Support URL `/support`, Play account-deletion URL `/delete-account`. Data safety and App Privacy answers must match the retention table in the privacy policy. |

Until #1–#3 exist, the form still works through the pre-filled email only, and the page says so after submitting.

## Owner decisions, 4 November 2026 (pages updated; app/backend changes needed)

| # | Decision | What the developer needs to do |
|---|---|---|
| 11 | **Customer cancellation rule.** Within 5 minutes of the booking being confirmed: 98% back as wallet credit (2% fee), even if the wash is less than 2 hours away. After 5 minutes and at least 2 hours before the wash window starts: 50% back. Less than 2 hours before: nothing back. Service failures and upheld wash complaints still return 100% as wallet credit. | One change to the current `walletByTime` snapshot: the first 5 minutes return **98%** instead of 100%. The 2-hour band (50%) and the late band (0%) stay as they are. Update the in-app cancellation quote and copy, and tests. Keep older bookings on their saved policy. |
| 12 | **Wallet credit expires one year after it is added.** | Track an expiry date per credit (top-ups, cancellation credit, service-failure credit, offers), spend the oldest credit first, expire unused credit after 12 months, and show expiry dates in the wallet. Decide how already-existing balances are dated (suggest: 12 months from go-live). |
| 13 | **Aadhaar: full or masked both accepted; masked recommended.** Review stays manual. | Optional: add a short hint on the Captain document step ("You can upload a masked Aadhaar"). Admin reviewers should accept both. |
| 14 | Grievance Officer shown as **"Aman"**. | Use the same name in the in-app support/legal config if it shows one. |

The terms (sections 4 and 5), support FAQ and privacy policy already state these rules, so items 11 and 12 must be live in the apps before the pages are deployed.

## Update 4 November 2026: positioning and services

- The website and policies no longer say "gated societies" or "society". WashKrew starts there but is not limited to it, so the copy now says "across Hyderabad", "near where you live" and "area by area".
- "What we wash" for cars adds **Complete wash, including interiors** shown greyed out with a "Coming soon" tag. Terms section 2 says the same. No booking change is needed: the apps should keep not offering it until it launches.
