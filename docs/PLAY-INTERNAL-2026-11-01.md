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

Both apps' version code 1, version 1.0.0, target SDK 36 were accepted and published
to their **separate internal-testing tracks only**. Play displayed **Available to
internal testers** for both: Customer released 1 November at 17:12 IST and Captain
at 21:39 IST, not reviewed. No public production release was created. Google shows
temporary package-based app names until app setup/review is complete.

A new **WashKrew Android Internal** email list contains only the phone account
explicitly confirmed by the owner. It is selected and saved for these two WashKrew
tracks. Existing publisher lists were not edited or selected for WashKrew, and no
TrustKeyper app, release, signing or track configuration was changed.

The join links were read directly from the corresponding track controls:

- Customer: https://play.google.com/apps/internaltest/4701042783652543665
- Captain: https://play.google.com/apps/internaltest/4700497850061297130

Open each link using the confirmed tester's Google account, join its test, then
use the Google Play installation link. Availability can take time to propagate;
being on the email list is separate from the tester opting in.

The initial two non-blocking Customer warnings were no testers selected and no
native R8 deobfuscation file. Tester access was subsequently saved. Captain's
only release warning was the absent native R8 mapping file. Internal builds
deliberately skip native shrinking; normal production builds retain it. Payment
mode is unchanged: these acceptance builds connect to the live backend and
payments charge real money.

## Play signing registration

The public signing-certificate archive was downloaded from each app's own
**App signing key → Download certificates** control. Each archive contains the
deployment, hybrid-classical and hybrid-PQC certificates. All three parse as
X.509 certificates. The deployment SHA256 was independently matched to that
app's package-specific Digital Asset Links example in Play Console.

| Role | Current Play deployment certificate SHA256 |
| --- | --- |
| Customer | `EC:03:97:52:11:A5:0A:51:34:6A:6B:D7:C5:48:32:69:4D:41:F0:C6:CA:48:37:12:94:2F:12:AE:80:B7:E9:91` |
| Captain | `11:32:2F:5F:22:51:8C:C4:ED:EF:38:D3:F8:D8:C5:B3:AE:8F:05:36:CC:7C:E4:25:68:D2:BF:4D:DB:4B:CD:31` |

The SHA1 and SHA256 of all three certificates were registered in the matching
`wheelio-apps` Firebase Android app. The matching package/SHA1 pairs were added to
the existing WashKrew Android Maps key. Existing debug entries and API restrictions
were preserved. Authenticated read-back verified all entries for both apps. No key
was regenerated, no signing key changed, and no TrustKeyper key/project was used.

Play-delivered installation and native OTP acceptance still require the device
check below. Do not claim sideloaded APK installation establishes Play Integrity
success or guarantees no Firebase challenge.

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
