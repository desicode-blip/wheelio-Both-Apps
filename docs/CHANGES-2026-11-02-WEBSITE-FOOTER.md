# Changes 2 November 2026: washkrew.com footer

For the developer (Ajay). Website only: `apps/website/`. The Customer and Captain apps, backend, Firebase rules, payments and the `/app/` and `/captain/` hosting are **not changed**.

## What changed

1. **New footer** on washkrew.com, in the brand charcoal (`#22282D`) with the white WashKrew logo (`assets/washkrew-lockup-dark.svg`, copied from `brand/`).
2. **Brand column:** one-line description and a "Follow us" row with Instagram, Facebook, YouTube, LinkedIn and X.
3. **Social buttons are placeholders.** No profiles exist yet, so each is a `<button data-social="...">`; clicking shows a small "<network> page coming soon" bubble beside it.
4. **Link columns:** For customers (How it works, What we wash, The crew, Request a wash) and For captains (Become a captain, Earnings, Captain app). Added `id="services"` to the "What we wash" section so its link works.
5. **Get the app:** App Store and Google Play buttons. They open the existing Get-the-app prompt while `STORE_LINKS.customer` is empty, and become real download links automatically once filled.
6. **Our offices**, Aman's company addresses (same as the TrustKeyper site):
   - Noida, head office: Works/Office No. 08 (FF), Block: MART, Mahagun Moderne, Plot No. GH-02, Sector 78, Noida, Uttar Pradesh 201301
   - Bengaluru, branch office: HD-198, Embassy TechVillage, Outer Ring Road, Bellandur, Bengaluru, Karnataka 560103
   - Hyderabad, branch office: 1st Floor, Rajpushpa Summit, Nanakramguda Rd, Financial District, Hyderabad, Telangana 500032
7. **Bottom bar:** "© <year> WashKrew. All rights reserved." and the visitor-city line ("Now live in Hyderabad"), driven by the existing city lookup.

Checked at desktop (1440 px), tablet (900 px) and phone (390 px): no sideways scroll, no console errors, social bubble and store buttons work.

## What the developer needs to do

| # | Task | Notes |
|---|---|---|
| 1 | Redeploy the website | `cd apps/website` then `npx -y firebase-tools@latest deploy --only hosting:website --project wheelio-apps`. Reuse the existing `washkrew` site; see `docs/WEBSITE-DEPLOYMENT-2026-10-27.md`. Nothing else needs deploying. |
| 2 | Check washkrew.web.app after deploy | Footer shows, offices are correct, clicking a social icon shows "coming soon", store buttons open the app prompt. |
| 3 | When social profiles exist | In `public/index.html`, replace that network's `<button class="social" data-social="...">` with `<a class="social" href="PROFILE_URL" target="_blank" rel="noopener" aria-label="WashKrew on Instagram">` (same icon inside). |
| 4 | When the apps are published | Fill `STORE_LINKS` near the bottom of `public/index.html`; the footer and prompt buttons switch to "Download" by themselves. |

## Waiting on Aman (not done on purpose)

- WashKrew contact email and phone. The TrustKeyper site's contacts were not reused.
- Legal entity / GST line, if WashKrew sits under the same entity as TrustKeyper ("A Brand by Paravent").
- Terms, privacy and cancellation/refund pages. Payments are live, so Razorpay and customers will expect them; add each as its own page in `public/` and link it from the footer bottom bar.

No backend connection is needed for this change.
