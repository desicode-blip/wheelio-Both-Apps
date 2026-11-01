# Separate WashKrew Android internal apps — 1 November 2026

The owner explicitly requires two distinct WashKrew apps and no changes to the
existing TrustKeyper app setup. Both WashKrew registrations were created in the
existing publisher after the owner authorized their policy/export declarations.
The unrelated TrustKeyper and TrustKeyper Staging entries remain outside this task.
Do not reuse their releases, signing configuration or tester lists.

| Role | Package | Play app ID |
| --- | --- | --- |
| Customer — WashKrew | `com.amanmaheshwari.wheelio.customer` | `4974657291613494539` |
| Captain — WashKrew Captain | `com.amanmaheshwari.wheelio.captain` | `4974897678367286968` |

## Current evidence

Both upload-signed arm64 release bundles built from `f15f29f` and passed local
JAR signature verification. Exact hashes are recorded in
[CAPTAIN-COVERAGE-2026-11-01.md](CAPTAIN-COVERAGE-2026-11-01.md).

Customer version code 1, version 1.0.0, target SDK 36 was accepted and published
to its **internal-testing track only**. Play displayed **Available to internal
testers**, released 1 November at 17:12 IST, not reviewed. No public production
release was created. Google shows a temporary package-based app name until app
setup/review is complete. Tester selection is still pending, so the track summary
remains inactive despite the accepted internal release.

The two non-blocking Customer warnings were no testers selected and no native
R8 deobfuscation file. This internal build deliberately skips native shrinking;
normal production builds retain it. Payment mode is unchanged: this private
acceptance build connects to the live backend and payments charge real money.

Captain remains a separate registration with its current bundle ready to upload.
Its internal release, dedicated WashKrew tester selection, Play signing
fingerprints, Firebase/Maps registration and Play-delivered OTP acceptance remain
to be completed. Do not claim sideloaded APK installation establishes Play
Integrity success or guarantees no Firebase challenge.

## Physical APK follow-up

Both final USB profile APKs were installed while preserving app data. Captain
Home now shows **Documents under review** with the existing authored layout.
Pressing **Go online** opened the authored profile-under-review message and kept
the real unapproved Captain Offline. Customer reopened successfully into its
existing vehicle-selection screen. No identity approval or payment was created.

Play uses a different signing certificate from these laptop-debug-signed USB
builds. Do not uninstall the current apps or erase local data without the owner's
specific approval. Before a Play-delivered device test, confirm all important
uploads are saved and obtain approval for any required replacement. Server-side
accounts and bookings must never be deleted as part of that installation.
