# Changes 27 October 2026: washkrew.com website

For Ajay. Everything here is in the new `apps/website/` folder. The Customer and Captain apps, the backend, Firebase rules and the existing `/app/` and `/captain/` hosting are **not changed**.

## What changed

1. **New public website** for washkrew.com in `apps/website/`. Plain HTML and CSS, no build step. It uses the logo palette (`#0049FF`, `#22282D`), Roboto, the WashKrew logo files and the crew mock-up photos from `brand/`.
2. **Sections:** hero, what we wash (cars and bikes, exterior only), how a wash works (book, captain assigned, photos before, wash and photos after, customer confirms and rates), the crew, becoming a captain, and a closing launch line.
3. **Buttons:** "Request a wash", "Get the app" and "Apply as a captain" open a "Get the app" prompt for the Customer app or the Captain app. Store buttons show "Coming soon" until links are added in `STORE_LINKS` in `public/index.html`.
4. **Copy decisions (Aman):** says "Now live in Hyderabad". No prices, payout timings, contact details or policies. No mention of payment being held or released after approval; the site says we ask for the customer's feedback and confirmation instead. The captain section leads with "Earn ₹60,000+ a month", with a note that earnings depend on the number of washes completed.
5. **Visitor's city:** the page estimates the visitor's city from their IP address using ipapi.co (no permission prompt). Cities in `LIVE_CITIES` (Hyderabad and its areas) see "Now live in Hyderabad"; other Indian cities see "Coming soon to <city>"; outside India or on failure it shows Hyderabad.
6. **Favicon:** the Customer app icon (door mark on a white rounded square) in SVG, ICO, PNG and the iPhone home-screen size.

## What Ajay needs to do

| # | Task | Notes |
|---|---|---|
| 1 | Create a separate Firebase Hosting site `washkrew` in project `wheelio-apps` and deploy `apps/website` | Steps in `apps/website/README.md`. Deploy with `--only hosting:website` so the apps' site is untouched. |
| 2 | Connect washkrew.com and www.washkrew.com (www redirects) | Firebase console, then GoDaddy DNS. Replace only the A record pointing at GoDaddy's "Coming Soon" page and the www record; leave the email (SPF/MX) records alone. |
| 3 | Move the city lookup to a paid plan before real traffic | ipapi.co free tier is about 1,000 lookups a day and its commercial-use terms are unclear. The service is one setting, `GEO_ENDPOINT`. |
| 4 | Add store links when the apps are published | Fill `STORE_LINKS` in `public/index.html`. |
| 5 | Before using washkrew.com for the new Razorpay merchant account | Add contact details and terms, privacy and cancellation/refund pages when Aman supplies the content. The privacy policy must mention the IP-based city lookup. |

No backend connection is needed for the website itself.
