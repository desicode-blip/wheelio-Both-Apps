# Current WashKrew website

`public/` is the latest washkrew.com static website, including Aman's footer
changes of 2 November. Cleanup preserves every public HTML/CSS/image/font file.
See [the latest footer report](../../docs/CHANGES-2026-11-02-WEBSITE-FOOTER.md).
There is no React/Next.js website implementation or JavaScript build dependency.

## Preview and maintain

From the repository root:

```sh
node apps/flutter/tool/serve.mjs apps/website/public 8765
```

Open http://127.0.0.1:8765. Layout and behavior live in `public/index.html` and
`public/styles.css`; brand images are in `public/assets/` and fonts in `public/fonts/`.
Use current authored structure/styles, brand tokens and assets; do not redesign.
Public store links are controlled by `STORE_LINKS` in index.html. Empty links
remain Coming soon; never advertise an unpublished store release. Existing
city-copy configuration and footer social placeholders remain unchanged.
Approved commercial/contact/legal content comes from the owner/Aman.

## Hosting

This website uses its own existing **washkrew** Firebase Hosting site/website
target in project **wheelio-apps**. Its `.firebaserc` and `firebase.json` are
separate from default app/admin/landing Hosting. For an authorized website deploy:

```sh
cd apps/website
firebase deploy --only hosting:website --project wheelio-apps
```

Reuse the existing site and domain configuration. Do not create another site,
replace it with default Hosting or change GoDaddy/email records during a source
cleanup. The dated [original deployment record](../../docs/WEBSITE-DEPLOYMENT-2026-10-27.md)
is historical DNS/certificate evidence, not a current domain-health check.
This cleanup does not publish or change any deployed website.
