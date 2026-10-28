# WashKrew

The current Customer and Captain apps live in **apps/flutter/customer** and
**apps/flutter/captain**. Both use the shared Flutter design and Firebase packages.
These are the only mobile app implementations in this checkout.

The owner locked the design to commit **af036f0**. Preserve its layouts,
components, fonts, palette and assets while connecting real functionality.
The owner separately approved hiding training/quiz and excluding direct credit
card checkout. See [the design audit](docs/DESIGN-AUDIT-2026-10-28.md).

## Run the current apps

Use Flutter **3.38.6**, Node.js 24 and pnpm 11. If Flutter is not on PATH, set
`FLUTTER_BIN` to its executable. Copy `firebase.example.json` to
`firebase.local.json` and configure the public Firebase app identifiers; never
put merchant secrets into a client configuration.

```sh
pnpm dev             # Customer Flutter web app, localhost:8081
pnpm dev:captain     # Captain Flutter web app, localhost:8082
pnpm typecheck       # Both apps and shared packages
pnpm test            # App and shared Firebase tests
pnpm build           # Both release web apps plus admin and landing page
pnpm preview         # Preview that build at localhost:8083
```

Normal builds connect to Firebase **wheelio-apps**. The server selects payment
mode: the deployed configuration currently uses the separate WashKrew **LIVE**
merchant. A real checkout charges money. Training/quiz are hidden; human admin
approval is required before a Captain can work. Do not seed fake Captains,
payments or fixed OTPs in production. `?demo=true` is a labelled, isolated design
gallery using sample data; it is not functional acceptance.

## Install on an iPhone

On a Mac with Xcode and CocoaPods, use `apps/flutter/tool/run-ios.sh` and follow
[the complete Aman/Claude guide](docs/AMAN-IPHONE-ACCEPTANCE-2026-10-28.md).
The Xcode workspaces are **apps/flutter/customer/ios/Runner.xcworkspace** and
**apps/flutter/captain/ios/Runner.xcworkspace**. Keep bundle IDs
`com.amanmaheshwari.wheelio.customer` and `.captain` and Apple team `8CCQQM7TP3`.
See [Mac setup](docs/MAC-HANDOFF.md). Windows tests do not prove native signing,
compilation, camera/GPS/APNs or real payment-app switching.

## Repository layout

| Path | Purpose |
| --- | --- |
| apps/flutter/customer | Current Customer app: web and iOS |
| apps/flutter/captain | Current Captain app: web and iOS |
| apps/flutter/packages/washkrew_ui | Authoritative shared design system/assets |
| apps/flutter/packages/washkrew_firebase | Shared Firebase and native integrations |
| apps/admin | Private Google-authorized Captain review webpage |
| apps/website | Current washkrew.com marketing website; separate Hosting site |
| apps/hosting | Default Firebase site's landing page |
| backend/firebase | Current Functions, rules, operations and tests |
| backend/photo-check | Private photo/identity service |
| brand, designs, Wheelio-designs | Approved brand and design exports |
| docs, output/pdf | Reports, build and acceptance guides |

The retired SwiftUI, Next.js/React and legacy Flutter apps and empty Android
placeholder were removed at the owner's request on 28 October. Their history
remains in Git; do not recreate them or follow older build instructions. Historical
database files are archives, not an instruction to migrate or delete any database.
Android platform work remains deferred until requested.

## Hosting and operations

- Customer: https://wheelio-apps.web.app/app/
- Captain: https://wheelio-apps.web.app/captain/
- Private admin: https://wheelio-apps.web.app/admin/
- Website: https://washkrew.com/

After a verified build, `pnpm deploy` publishes default Firebase Hosting.
Functions/rules/photo service changes have separate documented deployment steps;
see [Firebase bookings](docs/FIREBASE-BOOKINGS.md). Keep the organization's policy
and documented HTTP gateway authorization intact. Do not deploy to Cloudflare or
use the retired Neon frontend. Run backend/rules checks with `pnpm firebase:test`
after installing the backend npm dependencies; Java 21+ is needed.

Read [AGENTS.md](AGENTS.md) before editing. Current operational limits and human
inputs are in [completion notes](docs/COMPLETION-2026-10-28.md). Physical iPhone
acceptance, approved support/legal/commercial inputs and real Captain reviews
remain required; do not call an automated or sample-gallery check a device pass.
