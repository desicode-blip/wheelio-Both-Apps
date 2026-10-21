# Firebase web release

**21 October update:** the booking implementation and current setup supersede this historical foundation record; see [FIREBASE-BOOKINGS.md](FIREBASE-BOOKINGS.md). Trustkeyper billing is now linked, phone SMS is enabled for India, Storage exists, and Razorpay test secrets have been copied securely. The new release uses the existing Flutter screens with Firebase controllers. Deployment/merchant acceptance status must be checked separately from implementation.

## Historical foundation — 20 October

The owner selected Firebase for backend and hosting on 20 October 2026. Project **wheelio-apps**, project number **763324255731**, created under **ajay@trustkeyper.com**. Firestore is Standard Native mode in Mumbai (`asia-south1`) with its free tier. No billing account was attached by this task.

Published: [website](https://wheelio-apps.web.app/), [Customer](https://wheelio-apps.web.app/app/), [Captain](https://wheelio-apps.web.app/captain/).

## What works

- Landing page: `apps/hosting/`.
- Customer: Firebase email/password signup/login/password reset/logout, persistent session, saved name, wash requests, realtime request history and cancellation.
- Captain: the same authentication/profile, with private Captain applications.
- Shared code: `apps/flutter/packages/wheelio_firebase/`. Both active Flutter app entry points use it, preserving the web → iOS → Android direction.
- Designed demos: `/app/?demo=true` and `/captain/?demo=true`, with a persistent sample-data label. The live app does not use hardcoded OTPs or simulated payment/job state.

The complete paid-wash marketplace is **not** shipped. Requests do not reserve a slot or charge money. KYC, document/photo uploads, payments/refunds, job dispatch/claim, evidence approval, payouts, push, maps, account deletion and native device integration remain to be implemented. Captain applications are interest records, not permission to accept jobs. Existing Neon/Supabase databases and integrations are retained and not migrated or used by this release.

## Configuration and build

Prerequisites: Flutter 3.38.6 / Dart 3.10.7 or compatible, Node 24, Firebase CLI 15.8+. The app lockfiles are tracked. `firebase.local.json` is ignored; no service account private key is needed in the client.

1. Copy `firebase.example.json` to `firebase.local.json`.
2. Fill its public Firebase web configuration from the existing "Wheelio Web" app in Firebase project settings. App ID: `1:763324255731:web:06973464f9d08d23ef9686`.
3. Run `node apps/flutter/tool/build-firebase.mjs` from the repository root. Set `FLUTTER_BIN` to the Flutter executable if it is not on PATH.
4. Run `firebase emulators:start --only hosting` to serve the assembled build at `http://127.0.0.1:5000` (this previews the live Firebase backend, unless the build uses emulator defines).

The build script runs both Flutter release builds with `/app/` and `/captain/` base paths and disabled offline service workers, then adds the landing page, bundled fonts and robots file. Output: `build/firebase-hosting/`.

For a fully local backend, add `FIREBASE_USE_EMULATORS: true` and `FIREBASE_EMULATOR_HOST: "127.0.0.1"` to a separate defines JSON and pass it to the build script. Set `FIREBASE_PROJECT_ID` to `demo-wheelio`, use matching demo app identifiers, and start emulators with `--project demo-wheelio --only "auth,firestore,hosting"`. Never deploy a build configured to use emulators.

## Deployment

```sh
firebase login --account ajay@trustkeyper.com
firebase deploy --only hosting,firestore,auth --project wheelio-apps --account ajay@trustkeyper.com
```

PowerShell: quote comma-separated values, for example `--only "hosting,firestore,auth"`. The default root `pnpm deploy` deploys Hosting and Firestore only, using the selected Firebase project/account. Prefer explicit project/account arguments when multiple accounts are logged in.

`firebase.json` enables email/password auth as code, declares closed Firestore rules, a composite request-history index, both app rewrites, and cache/security headers. Hosting's default domains are authorized for Firebase Auth; localhost is also authorized for development. Wait for the composite index to reach READY before checking request history on a fresh project.

Phone authentication is implemented for web behind `FIREBASE_PHONE_AUTH_ENABLED=true`. It is disabled in this release because SMS provider, region policy and billing must be configured and tested first. Email works without enabling SMS. Native phone auth will require the native verification flow and platform-specific Firebase app registrations. Storage rules deny all access and are not deployed or connected in this phase.

## Security model

- `users/{uid}`: only the signed-in owner can read; email and verified phone derive from Auth tokens. The owner can change only their name and update timestamp.
- `washRequests/{id}`: authenticated users with a profile can create their own schema-validated requests. Owners can read/query only their own requests and change `requested` to `cancelled`. Server timestamps are required. Clients cannot set prices or paid/approved states.
- `captainApplications/{uid}`: only the owner can create/read/edit their submitted application. Approval and other server-owned status fields are protected.
- Every other collection is denied by default. No public rules or privileged credentials are shipped.

## Validation

```sh
npm ci --prefix backend/firebase
firebase emulators:exec --project demo-wheelio --only "firestore,auth" "npm --prefix backend/firebase test"
```

The emulator suite requires Java 21+ (this workstation also has Java 26). There are 12 meaningful rules tests: anonymous access, profile ownership, identity/role spoofing, owner-scoped queries, cancellation, cross-customer access, invalid content, payment/price manipulation and Captain self-approval.

20 October verification: all 12 rules tests passed; Customer, Captain and the shared Firebase package passed `flutter analyze`; both release web builds succeeded. Live Auth/Firestore smoke checks passed signup, login/logout, profile update, request save/query/cancel, application save and account isolation. Browser checks exercised Customer login/request/cancellation/profile and Captain application, with phone and desktop layout checks. Generated QA accounts/documents/credentials were removed. Firebase CLI confirmed successful auth, Firestore rules/index and Hosting deployment.

Run `flutter analyze` in Customer, Captain and `packages/wheelio_firebase`. Compile both web apps through the build script.

For intentional live QA, run `node backend/firebase/smoke.mjs` from the root. It exercises signup, profiles, request save/query/cancel, Captain applications, isolation, login and logout without sending email or SMS. Its disposable credentials/record IDs go in ignored `.cache/firebase-qa.json` for browser testing. Afterwards run `node backend/firebase/cleanup-smoke.mjs`; this signs in as each generated QA user, enumerates only their records, deletes those exact documents using the Firebase CLI under the project owner, deletes the generated Auth accounts, then removes the local credentials. If a test fails, run cleanup before retrying. Do not retain QA accounts in production.

## Next implementation work

1. Decide service areas, pricing, capacity and cancellation/refund rules as server configuration.
2. Implement trusted Firebase functions for booking quotes, atomic job claims and state transitions.
3. Connect Razorpay with server-created orders and verified, idempotent payment/refund webhooks.
4. Connect private photo/document storage, real KYC review, push and evidence workflows to the existing designed Flutter screens.
5. Add account deletion with owned-data cleanup and production abuse controls.
6. Register separate iOS/Android Firebase apps, generate platform folders, integrate native services, and build/sign on suitable hosts. iOS builds require macOS/Xcode.
