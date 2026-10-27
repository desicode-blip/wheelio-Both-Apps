# Website deployment - 27 October 2026

Pulled Aman's website commits from `origin/staging` through `023e9e9` by fast-forward. The static HTML, CSS, assets, copy and app-download placeholders were deployed without source/design edits.

## Hosting

- Existing Firebase project: `wheelio-apps`, authenticated as `ajay@trustkeyper.com`.
- Created the separate Hosting site `washkrew`, matching `apps/website/.firebaserc`'s `website` target.
- Deployed only `hosting:website` from `apps/website/`.
- Available now: <https://washkrew.web.app/>.
- Registered `washkrew.com` and `www.washkrew.com` on that site. The latter has Firebase `redirectTarget: washkrew.com` (301 when HTTPS provisioning completes).
- The default `wheelio-apps` Hosting site, Customer `/app/`, Captain `/captain/`, Functions, rules, app design and payment mode were not redeployed or changed.

To redeploy this website, reuse the existing site; do not run site creation again:

```sh
cd apps/website
npx -y firebase-tools@latest deploy --only hosting:website --project wheelio-apps --account ajay@trustkeyper.com
```

## GoDaddy DNS changes

The logged-in GoDaddy domain portfolio was used to save only these website/certificate changes. Original and final zone-page text was retained in the local ignored `.cache/` for the deployment session.

| Type | Host | Result |
| --- | --- | --- |
| A | `@` | Replaced the old Coming Soon IP `160.153.0.34` with Firebase's `199.36.158.100`. |
| CNAME | `www` | Changed `washkrew.com` to `washkrew.web.app`. |
| TXT | `@` | Added `hosting-site=washkrew`, alongside the existing SPF TXT. |
| TXT | `_acme-challenge` | Replaced the old Cloudflare certificate-challenge CNAME with the exact Firebase-provided TXT challenge. |
| TXT | `_acme-challenge.www` | Added the exact Firebase-provided TXT challenge. |

Public Google DNS subsequently returned all five expected website/verification records. The GoDaddy nameservers, SPF, DKIM, DMARC, Domain Connect and other domains were left intact. Existing records had one-hour TTLs; new TXT entries use GoDaddy's half-hour default. Keep Firebase's ownership TXT; it is needed for continued domain ownership and certificate renewal. Certificate challenge values are public DNS material but are omitted here because they are provisioning-specific and can change.

## Checks and current certificate boundary

- All 18 referenced local website resources exist; the browser script parses and JSON-LD is valid.
- All 23 published files match their staging source hashes. The custom missing-path response returns the supplied 404 page.
- Both existing hosted Customer/Captain JavaScript bundles still match the previously checked app release.
- The deployed marketing page renders and its console has no captured warning/error. The app dialog opens/closes and still shows store links as Coming soon, as authored by Aman.
- Public DNS has the new records, but the latest Firebase check still reports **CERT_VALIDATING** for both names. `www` has active host/ownership state; the apex check still observes cached old host/ownership data. Strict HTTPS requests to both custom names currently fail hostname-certificate validation. No TLS warning was bypassed and neither custom HTTPS URL is claimed ready yet.

Firebase must finish its DNS reconciliation and managed certificate issuance. Use the working Firebase URL above meanwhile. After provisioning, verify <https://washkrew.com/> has a valid certificate and the deployed HTML, and <https://www.washkrew.com/> returns a valid HTTPS 301 redirect to the apex. Firebase documents that certificate provisioning can take up to 24 hours after DNS is pointed correctly: <https://firebase.google.com/docs/hosting/custom-domain>.

This publication does not approve real booking operations or activate live payments. Aman is handling the separate WashKrew merchant account; approved contact/policy content and App Store/Play Store links remain his website follow-ups in `CHANGES-2026-10-27-WEBSITE.md`. No app/backend code or merchant secret changed during this deployment.
