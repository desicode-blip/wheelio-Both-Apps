# Separate WashKrew Android internal apps — 1 November 2026

## Latest accepted updates — 2 November 2026

Customer **1.0.2 (3)** and Captain **1.0.1 (2)** from `844c77c` are available to
internal testers in their existing separate tracks, published at **14:15** and
**14:21 IST** respectively. The connected phone updated through Play at
**14:27:13** and **18:17:50 IST**. Package metadata and installed APK signature
verification confirm both versions, Play delivery and the registered deployment
certificates. Data/logins were preserved; no unrelated app was changed.

Customer Home/wallet balance and an owner-completed **₹1 live wallet top-up**
were checked on the phone and against authenticated server records. See
[WALLET-OFFERS-2026-11-02.md](WALLET-OFFERS-2026-11-02.md) for the scoped UI
authorization, full release/test evidence and remaining native acceptance gates.
Earlier delivery errors and old version numbers below are historical.

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

Both Play-delivered installations and fixed-code test-number logins were later
verified on the device, as recorded below. Real-number OTP acceptance remains
separate. Neither a sideloaded install nor a test-number login establishes real
SMS Play Integrity success or guarantees no Firebase challenge.

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

## Play-delivered device check — 1 November, 22:22 IST

The owner explicitly authorized replacing **only the two WashKrew USB apps**
with the Play versions, including loss of their local logins/drafts. No server
account, document or booking is authorized for deletion.

Device package inspection found Customer already absent before this replacement
work; Captain was still installed with no Play installer recorded. No app had
been uninstalled by the agent at that initial inspection. Play Store's selected account was
verified as the owner's confirmed tester account. Chrome initially used another
Google account for the invitations; selecting the confirmed tester account fixed
the invitation's **App not available** message.

The Customer invitation now says **You're a tester** and offers **Download test
app**. Its Play listing opens, but the original install attempt and one retry
both stop with **Something went wrong on our end. Please try again.** before any
package is installed. Storage inspection reports about 120 GB free. No specific
package-install failure was found in the filtered Play/Package Manager logs;
the generic message does not establish a cause or an application-code defect.

Captain's invitation subsequently showed **You're a tester**; the owner also
explicitly confirmed its invitation opt-in. The first download link showed
**Item not found**. One **Try again** subsequently opened its actual Play listing,
which correctly warned that the installed copy did not come from Google Play.
With replacement already authorized, only the Captain USB app was uninstalled
and reinstalled from that listing. No unrelated app was changed.

Captain installation completed at **22:18:36 IST**. Android package read-back
confirms version code 1 / version 1.0.0, target SDK 36 and installer
`com.android.vending`. Its installed base APK passed `apksigner verify`; SHA1
and SHA256 match the Captain Play deployment certificate registered above.
The SDK verifier reported unknown additional v3 attributes as warnings, with
successful verification; no signing certificate was bypassed or changed.

The Play Captain opens the authored language/welcome screens, then the existing
Guest Home. **Go online** opens native phone authentication. The owner is entering
the existing Captain number and SMS code directly on the phone; OnePlus Secure
Keyboard intentionally hides this entry from the mirror. OTP success/fallback is
not yet established. Customer delivery still needs a later retry. Do not clear
Google accounts, weaken Play Protect/Firebase verification, or modify unrelated
apps to work around delivery errors.

## Device follow-up — 2 November, 03:00 IST

Customer's next installation attempt succeeded on 1 November at **22:30:30 IST**.
Android read-back confirms both packages use installer `com.android.vending`,
version code 1 / version 1.0.0, target SDK 36. Customer's installed base APK also
passed `apksigner verify`; its SHA1/SHA256 match the registered Customer Play
deployment certificate above. The earlier delivery errors no longer block either
installation. No Google account/data reset, Play Protect change or unrelated-app
mutation was used to obtain delivery.

The owner then requested two dedicated fixed-code Firebase phone accounts and
supplied their numbers. Both normal Play-installed app logins succeeded on
2 November: Captain registered and reached Home, unapproved/Offline; Customer
reached its existing name step, saved the test name and returned Home. The codes
stay outside Git. These are **test-number** results, not real-SMS/Play Integrity
acceptance. Customer's initial generic post-login error did not recur in the
later normal attempt; its precise cause remains unproven. See
[FIREBASE-TEST-ACCOUNTS-2026-11-02.md](FIREBASE-TEST-ACCOUNTS-2026-11-02.md).
