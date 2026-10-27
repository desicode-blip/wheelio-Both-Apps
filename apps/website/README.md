# WashKrew website (washkrew.com)

The public marketing site for WashKrew. Plain static HTML and CSS, no build step. Built 27 October 2026 from the WashKrew design system (logo palette `#0049FF` / `#22282D`, canvas `#F6F9FD`, Roboto) and the brand book voice.

- `public/index.html`: the whole page. `public/styles.css`: all styles and tokens.
- `public/assets/`: logo SVGs (copied from `brand/`) and the crew mock-up photos as WebP (800 and 1400 px).
- `public/fonts/`: Roboto Regular, Medium and Bold as subset WOFF2.
- `firebase.json` / `.firebaserc`: deploys only this site to its **own** Firebase Hosting site, so the Customer `/app/` and Captain `/captain/` deployment on the default `wheelio-apps` site is never touched.

## Content rules

- Prelaunch: nothing says booking is live. No prices, payout timings, contact numbers, legal entity or policies until Aman approves them.
- "Request a wash", "Get the app" and "Apply as a captain" open a "Get the app" dialog (customer app or Captain app). The store buttons show "Coming soon" until links exist.
- **To add store links**, fill in `STORE_LINKS` near the bottom of `public/index.html`:
  ```js
  const STORE_LINKS = {
    customer: { ios: 'https://apps.apple.com/…', android: '' },
    captain: { ios: '', android: '' }
  };
  ```
  A filled link turns that button into a real "Download" link; an empty one stays "Coming soon".

## Preview locally

```sh
cd apps/website
python3 -m http.server 8765 -d public   # then open http://127.0.0.1:8765
```

## Going live (manual)

Needs the Firebase CLI (`npm i -g firebase-tools`) and a Google account with access to project `wheelio-apps` (owner: ajay@trustkeyper.com).

### 1. Create the site and deploy

```sh
firebase login
firebase hosting:sites:create washkrew --project wheelio-apps
cd apps/website
firebase deploy --only hosting:website --project wheelio-apps
```

- If the site ID `washkrew` is taken, pick another (for example `washkrew-web`) and change `"website": ["washkrew"]` in `.firebaserc` to match, or run `firebase target:apply hosting website <site-id>`.
- The site is then at `https://washkrew.web.app` (or `https://<site-id>.web.app`).
- For a temporary 7-day review link instead: `firebase hosting:channel:deploy review --only website --expires 7d --project wheelio-apps`.

### 2. Add the domain in Firebase

Firebase console → project **wheelio-apps** → Hosting → choose the **washkrew** site (not the default site) → **Add custom domain**:

1. `washkrew.com`
2. `www.washkrew.com`, with **Redirect to washkrew.com** ticked.

Firebase then lists the exact DNS records to add. Use its values, not ones from this file.

### 3. Change DNS in GoDaddy

GoDaddy → My Products → washkrew.com → **DNS** → Manage DNS. On 27 October 2026 the records were:

| Type | Name | Value | What to do |
|---|---|---|---|
| A | @ | 160.153.0.34 (GoDaddy "Coming Soon" page) | Replace with the A record value(s) Firebase shows |
| CNAME | www | washkrew.com | Change to what Firebase shows for www |
| TXT | @ | `v=spf1 include:secureserver.net ~all` | **Leave alone** (email) |
| MX | @ | GoDaddy mail, if any | **Leave alone** |

Then add the TXT record(s) Firebase asks for (domain ownership, and the `_acme-challenge` one for the certificate if shown).

If GoDaddy refuses to edit the A record, a GoDaddy website or domain forwarding is attached: turn off **Forwarding** (DNS page) or disconnect the GoDaddy website/"Coming Soon" page first.

### 4. Wait and check

- DNS usually updates within an hour; Firebase can take up to 24 hours to issue the HTTPS certificate. The console shows **Connected** when done.
- Check: `https://washkrew.com` shows the site with a padlock, `https://www.washkrew.com` redirects to it, and an unknown path such as `/abc` shows the WashKrew 404 page.
- Check email still works if a GoDaddy mailbox is used.

### 5. After launch

- Fill `STORE_LINKS` when the apps are published.
- Before using washkrew.com for the Razorpay merchant application, the site will likely need contact details plus terms, privacy, and cancellation/refund pages. Aman is supplying that content; add each as its own page in `public/` (for example `public/privacy.html`, served as `/privacy`).
