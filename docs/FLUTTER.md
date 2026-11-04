# Current Flutter apps - 3 November 2026

Store preparation: Customer **1.0.4 (8)** / Captain **1.0.5 (9)** preserve the
accepted app UI and functionality. Production Android builds use all three ABIs,
R8/resource shrinking and the private existing upload key. App backup is disabled
to avoid restoring private role state on reinstall. iOS Runner resources include
source-based privacy manifests; `archive-ios.sh` exports local App Store IPAs and
checks the signed distribution/APNs/team/package/SDK, preserving archives/dSYMs.
See [the store guide](STORE-RELEASE-2026-11-03.md). Metadata/policy drafts and
explicit publication gates live in `release/store/`; no store submission is
performed by the build tools. Policies still need owner review and deployment.

The latest owner-approved UI exception replaces consent popups with a paid-booking
AI toggle (default OFF) on Customer success/tracking. Captain ON offers Check with
AI or Send without AI; OFF sends directly. Checkout has no AI dialog. Both roles
use the existing switch/card/button design language. See
[AI-PHOTO-TOGGLE-2026-11-03.md](AI-PHOTO-TOGGLE-2026-11-03.md).

The lifecycle fix introduced in Customer **1.0.4 (5)** / Captain **1.0.5 (6)** clears private
state and navigation on removal, wait for fresh active-role server snapshots and
support same-phone signup without restoring old KYC, approval or saved settings.
See [the lifecycle recovery report](ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md).

Only `apps/flutter/customer` and `apps/flutter/captain` are app implementations.
Both build for Android/iOS and share `packages/washkrew_ui` and
`packages/washkrew_firebase` beneath `apps/flutter/`. Browser folders/tooling are
QA previews of this same source; native acceptance does not require a web release.
The private Captain admin and marketing website remain separate current products.

## Build and checks

Android internal builds select arm64 for both Flutter AOT/engine and the release
build-type NDK filter. This also filters plugin libraries; leaving Flutter 3.38's
three default build-type filters would advertise unsupported architectures with
no matching engine. Normal production release/debug/profile filters are unchanged.

Use Flutter **3.38.6 / Dart 3.10.7**. Keep both app lockfiles. Root `pnpm typecheck`
and `pnpm test` run the two apps and both shared packages. Native iPhone builds
need a Mac with Xcode/CocoaPods; read
[the current handoff](AMAN-IOS-HANDOFF-2026-11-02.md) and
[the current Claude prompt](AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md).
`bash apps/flutter/tool/run-ios.sh --prepare` prepares both workspaces; running it
without that flag builds/installs Release apps on a trusted physical iPhone.

Android internal bundles use `pnpm android:internal` and private local signing
configuration. See [Play setup](PLAY-INTERNAL-2026-11-01.md). WashKrew Customer
and Captain are separate Play apps; never modify TrustKeyper apps or signing.
Default app builds use Firebase; labelled `WHEELIO_DEMO`/browser demo previews
are isolated reference state and do not call live booking controllers.

## Designs

The owner locked the authored design to **af036f0**. Reuse shared components,
Roboto fonts, assets, palette, spacing and phone layout. Approved exceptions are
recorded in AGENTS.md: upload-only Aadhaar, hidden training, Captain coverage
map/radius, direct gateway checkout, wallet entry/top-ups/payment choice and
now the existing delete dialog's second confirmation. Do not recreate screens.
Canonical exports are in `designs/`; `docs/screen-index.csv` is the index.
The identical `Wheelio-designs/` copy was removed. Design QA tooling and its
approved W05 screenshot remain; see [the audit](DESIGN-AUDIT-2026-10-28.md).

## Current functional behavior

- Phone auth uses Firebase native verification on Android/iOS. No custom native
  bot screen and no real-SMS verification bypass. Silent APNs verification needs
  working signed capabilities and Background App Refresh; secure fallback can occur.
- Aadhaar/selfie/payout upload leads to private human admin review. Training,
  quiz and DigiLocker are hidden. Approval alone does not override coverage,
  saved work hours, remaining capacity or Online eligibility.
- A Captain chooses a fixed map centre and 1-10 km radius. Every confirmed home
  inside coverage can qualify without society approval. Entire Customer windows
  must fit a continuous saved work period. Capacity/payment/claim recheck this.
- Eligible Online Captains receive paid offers together; the first valid atomic
  claim wins. Expiry is not evidence that somebody else accepted the booking.
- Live Pay opens Razorpay directly. Wallet balance, captured top-ups, full-wallet
  checkout and shortfall top-ups use authenticated server state. Only verified
  captured payments issue credit. Direct credit cards, EMI and paylater are hidden.
- The guided wash camera advances while uploads proceed, but workflow transitions
  await actual registered evidence. Server-confirmed wash progress restores after
  reopening, including uploaded After photos; it must not restart at selfie.
- New cancellation policy gives full wallet value within five minutes, half at
  least two hours before start after grace, and zero inside two hours after grace.
  Service failures return full wallet value. Historical obligations stay distinct.
- Customer **1.0.3 (4)** and Captain **1.0.4 (5)** use two delete confirmations,
  no extra deletion SMS, a single pending action and retryable errors. Only the
  current role is removed; the server retains existing job/payment/balance guards.

## Evidence and remaining acceptance

The deletion follow-up passed **172 Flutter tests** (Customer 74, Captain 37,
shared Firebase 52, shared UI 9), static analysis and portable iOS checks.
Its backend passed **196 emulator tests**. See
[the deletion report](ACCOUNT-DELETION-2026-11-03.md). Cleanup does not change
runtime UI/functionality. Its source/config/reference checks are recorded in
[the cleanup report](REPOSITORY-CLEANUP-2026-11-03.md).

The previous Play builds remain Customer 1.0.2 (3) / Captain 1.0.3 (4); source
version changes do not automatically update installed apps. Mac builds, signing,
physical camera/GPS/APNs, UPI app switching and end-to-end iPhone acceptance
remain to be observed and recorded. Never label source tests as device acceptance.


## 4 November policy release

See [the current implementation and Mac acceptance guide](POLICY-RELEASE-2026-11-04.md). New bookings use 98/50/0 wallet credit, dated expiring credits, private human-reviewed website deletion requests and scheduled retention. No new service or fake approval/payment was introduced. Native layouts remain preserved; only the existing wallet card gains expiry text. Customer 1.0.4 (9), Captain 1.0.5 (10).
