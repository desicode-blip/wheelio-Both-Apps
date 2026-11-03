# WashKrew

The maintained products are the **Customer** and **Captain** Flutter apps for
Android/iOS and the current **washkrew.com** website. Firebase backend, private
Captain-review admin, shared packages, tests and build tools support those products.
Keep the approved app designs pinned to **af036f0** plus the owner-approved
exceptions in [AGENTS.md](AGENTS.md). Do not recreate or redesign either app.

## Build both iPhone apps

Start with [the current Mac handoff](docs/AMAN-IOS-HANDOFF-2026-11-02.md).
Aman can give Claude [this build/retest prompt](docs/AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md).
Use Flutter **3.38.6 / Dart 3.10.7**, Xcode and CocoaPods on the Mac:

```sh
git status --short
git fetch origin staging
git switch staging
git pull --ff-only origin staging
bash apps/flutter/tool/run-ios.sh --prepare
bash apps/flutter/tool/run-ios.sh
```

Preserve local changes; inspect a failed fast-forward rather than resetting.
Open each app's `ios/Runner.xcworkspace`, sign with paid Apple team **28JNT7H8KA**,
and keep `com.amanmaheshwari.wheelio.customer` / `.captain`.
Source versions: Customer **1.0.4 (5)**, Captain **1.0.5 (6)**.
Private APNs keys are already configured in Firebase and are not needed to build.
Record actual results in [the iPhone results template](docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md).
Windows checks do not establish Xcode compilation, signing or physical acceptance.

## Current source

| Path | Purpose |
| --- | --- |
| apps/flutter/customer | Customer app; Android and iOS platform projects |
| apps/flutter/captain | Captain app; Android and iOS platform projects |
| apps/flutter/packages/washkrew_ui | Shared authored components, tokens, fonts and assets |
| apps/flutter/packages/washkrew_firebase | Shared Firebase, payments and native integrations |
| apps/flutter/tool | Current build, device, QA and preview tooling |
| apps/website | Latest washkrew.com website and separate Hosting configuration |
| apps/admin | Private Captain-review portal |
| apps/hosting | Default Firebase site's landing page |
| backend/firebase | Current Functions, rules, indexes, operations and emulator tests |
| backend/photo-check | Private identity/photo advisory service and its tests |
| brand, designs | Brand masters and one canonical set of approved design exports |
| docs, output | Current policies/build guides and retained QA references |

Flutter's browser targets remain QA/preview paths for the same source, not a
separate implementation or a prerequisite for native acceptance. Keep the
private admin available at **https://wheelio-apps.web.app/admin/**.

## Checks and development

Use Node **24** and pnpm **11**. `FLUTTER_BIN` overrides the Flutter executable.
App lockfiles are committed. Public Firebase configuration is in the native
projects; copy `firebase.example.json` to ignored `firebase.local.json` only for
browser builds/local admin preview. Never put merchant or signing secrets there.

```sh
pnpm typecheck          # Both apps and shared packages
pnpm test               # Flutter app/shared tests
pnpm firebase:test      # Isolated Auth/Firestore/Storage tests; Java 21+
pnpm android:internal   # Two signed internal bundles; private local signing required
pnpm dev                # Customer QA browser preview
pnpm dev:captain        # Captain QA browser preview
pnpm build              # Optional default Hosting build, including private admin
```

Install npm dependencies in `backend/firebase` and `backend/firebase/functions`
before backend tests. See [Flutter](docs/FLUTTER.md),
[Firebase operations](docs/FIREBASE-BOOKINGS.md),
[Play internal testing](docs/PLAY-INTERNAL-2026-11-01.md) and
[Mac troubleshooting](docs/MAC-HANDOFF.md).

## Current behavior and limits

Normal builds use Firebase **wheelio-apps**. New payments use the separate
WashKrew **LIVE** Razorpay merchant. Actual checkout/top-ups charge money; the
account holder authorizes payment/PIN. Direct credit cards, EMI and pay-later
are hidden; supported UPI, debit, netbanking and provider wallets remain available.
Training/DigiLocker are hidden; human admin approval, saved coverage/hours and
Online status govern Captain work. No manual society approval is needed for new
Captain-area bookings.

Cancellation benefits use wallet credits: 100% within five minutes of server
confirmation, then 50% at least two hours before the wash starts, otherwise zero.
The first-five-minute grace takes priority. Service failures return full wallet
value; historical payment/refund obligations keep their saved terms.
Deletion uses two confirmations without an extra deletion OTP and removes only
the current app role, subject to existing open-job/payment/balance safeguards.

See [current status](docs/STATUS.md) and [backend hookup rules](docs/BACKEND-HOOKUP.md).
Old implementations, duplicated exports and superseded handoffs are recoverable
in Git history; see [the cleanup record](docs/REPOSITORY-CLEANUP-2026-11-03.md).
No cloud database, merchant setup, deployed website or app UI was removed by cleanup.
