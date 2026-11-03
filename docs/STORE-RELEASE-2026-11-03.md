# Initial Android and iOS store release

Current publishing starting point, 3 November 2026. Ajay reports that Aman tested
the apps and considers this version good for the initial release. That is
owner-reported functional acceptance, not an Xcode archive or store-review result.
Keep the approved app UI. Do not recreate screens, rename packages/team, restore
old implementations, change the live merchant, or touch the TrustKeyper Play apps.

## Prepared source

| Product | Bundle/package | Source version |
| --- | --- | --- |
| WashKrew Customer | com.amanmaheshwari.wheelio.customer | 1.0.4 (6) |
| WashKrew Captain | com.amanmaheshwari.wheelio.captain | 1.0.5 (7) |

Build numbers increased independently from the previous test bundles. Check both
store consoles for any build uploaded elsewhere. An occupied/higher code needs
a new higher build number; do not overwrite a store release or reset versions.
Different first public marketing versions for the two independent apps are valid.

The production Android command compiles arm32/arm64/x86_64 with R8/resource
shrinking and the existing private upload key. It preserves exact R8 mappings.
Android app backup is disabled to avoid restoring private account state onto a
new installation. Native iOS source includes app privacy manifests as Runner
resources. The new Mac export checks the actual IPA’s package, team, production
APNs entitlement, non-debug distribution signature/profile, iOS SDK, version and
app manifest, and saves IPA + xcarchive + dSYMs + provenance. Development push
entitlements in source are preserved; export must use a distribution profile
that produces `aps-environment=production`. Do not turn off Firebase verification.

## Required public content — concrete drafts included

Owner-confirmed legal name: **Washkrew**. Support: **info@washkrew.com**,
**+91 80885 16875**. Source-based drafts are in `release/store/policies/`.
They are not deployed or represented as approved legal policies.

```sh
node release/store/prepare-website.mjs --preview
# Review build/store/policy-preview/{privacy,terms,support,delete-account,policies}.html
```

Before submission Aman/Ajay must finalize the actual policy text, effective date,
business address, retention schedule, audience/commercial details and any needed
legal/grievance provisions. Verify the mailbox and phone are monitored. Review
photo/face processing and the Google Vertex AI/Gemini transfer, including any
required in-app consent. This is important for Apple’s data-sharing review.
Set the corresponding approval fields in `release/store/release.json` only after
the real review is done; the staging command rejects unresolved draft wording.

After approval, stage the pages and deploy only the existing website target:

```sh
node release/store/prepare-website.mjs --stage-approved
cd apps/website
firebase deploy --only hosting:website --project wheelio-apps
cd ../..
```

The target URLs are `https://washkrew.com/privacy`, `/terms`, `/support`,
`/delete-account` and `/policies`. They must work publicly over HTTPS without a
login. The deletion page provides a support email request without installing the
app. Monitor and handle those requests with ownership verification. Do not
describe a mailto link as automatically deleting an account.

Publish approved support/legal content into the EXISTING operations config so
the current in-app policies/support controls use it. The publishing login needs
to be valid for ajay@trustkeyper.com; client compilation does not need that login.
Use `backend/firebase/operator.cjs publish-content` with an approved JSON file:

```json
{
  "support": {
    "phone": "+918088516875",
    "email": "info@washkrew.com",
    "hours": "Contact us for current support hours."
  },
  "legal": {
    "entity": "Washkrew",
    "termsPrivacyUrl": "https://washkrew.com/policies"
  }
}
```

First run `node backend/firebase/operator.cjs publish-content PATH.json` to
inspect the action; after approval append `--confirm`. Do not copy the old
training example: training must stay hidden/disabled. Do not change prices,
coverage, payment mode, secrets or historical refund obligations in this step.
The support-hours sentence promises no invented hours; owner may replace it with
their actual schedule. On 3 November the public config read returned no support
or legal fields. The owner CLI login was expired, so no config change was made.

## Android production bundles

On the prepared Windows machine:

```powershell
$env:FLUTTER_BIN='C:/src/flutter/flutter_windows_3.38.6-stable/flutter/bin/flutter.bat'
$env:PUB_CACHE='D:/DevCaches/pub-cache'
$env:JAVA_HOME='C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot'
$env:WASHKREW_ANDROID_KEY_PROPERTIES='C:/Users/ajayb/.washkrew/signing/android-upload.properties'
pnpm android:store
```

On another machine set these to its real Flutter/JDK/private upload-key paths.
The private upload keystore/properties remain outside Git; never generate a
replacement key to make a build pass. No merchant secret or Firebase CLI login
is needed for native client compilation. The production command forces live
native Firebase, no demo/emulators, and the full ABI set. Internal-test flags are
ignored. Bundles, mapping files and build JSON are in `build/store/android/`.
These are ignored generated artifacts: forward them privately alongside the
source handoff, or rebuild with the same securely supplied upload key. A Git pull
alone cannot retrieve a private upload key or an ignored AAB.

Validate each bundle using the official Google bundletool and Java:

```sh
python apps/flutter/tool/verify-android-store.py build/store/android/WashKrew-Customer-1.0.4-6.aab --bundletool /private/tools/bundletool.jar
python apps/flutter/tool/verify-android-store.py build/store/android/WashKrew-Captain-1.0.5-7.aab --bundletool /private/tools/bundletool.jar
```

The verifier checks bundle structure/CRC, expected upload certificate/signature,
package/version/API 36, backup/debug/background-location settings, all three
engine/AOT ABIs, 64-bit ELF LOAD alignment, 16 KB packaging and R8 mapping. This
does not establish device behavior on every ABI or Google’s review result.

In Sumit’s Play Console, use ONLY the existing WashKrew Customer and Captain apps
(IDs are recorded in `release/store/release.json`). Complete listing/contact,
privacy/Data safety, App access/reviewer credentials, content rating, audience,
ads and any current policy questions accurately. Provide sanitized CURRENT
screenshots, store icon and feature graphic at the dimensions requested by Play.
No mock screenshots of unimplemented screens or test banners.
Use the generated store AAB for the corresponding app; do not upload the older
arm64-only internal bundles as this production release. Review warnings and
pre-launch results, choose intended countries/service availability and a manual
production release. Do not advertise public store links before approval/live.

## iPhone App Store export on Aman's Mac

```sh
git status --short
git fetch origin staging
git switch staging
git pull --ff-only origin staging
git rev-parse HEAD
flutter --version
flutter doctor -v
dart apps/flutter/tool/ios.dart check
dart apps/flutter/tool/ios_test.dart
bash apps/flutter/tool/archive-ios.sh
```

Use **Flutter 3.38.6**, full **Xcode 26+ / iOS SDK 26+**, CocoaPods, paid team
**28JNT7H8KA (Sumit Mandal)** and automatic signing with App Store distribution
access. Sign in to the authorized Apple developer account in Xcode. Resolve any
owner agreements/account verification there. Keep both native lockfiles; the
helper resolves missing plugins with `pod install` and preserves compatible
locks. Do not use Debug/device/ad-hoc IPAs for App Store Connect.

The archive helper cleans machine-generated paths, resolves locked dependencies,
builds both signed IPAs without selecting/installing a phone, and exports locally
using `AppStoreExportOptions.plist`. It never uploads/submits. Successful output:
`build/store/ios/customer-TIMESTAMP/` and `captain-TIMESTAMP/` containing an IPA,
the full archive/dSYMs and `release.json`. A Flutter “archive succeeded” message
without a valid IPA is a failure. See the first actual Xcode/export error if the
helper stops. Do not change team/bundle ID or revoke keys as a workaround.

If a build code is occupied, update the corresponding source pubspec (preferred)
or use `archive-ios.sh customer --build-number NUMBER` / Captain separately and
record the exact number. Commit successful Mac-resolved Podfile.lock changes.
Windows source checks do not establish an Xcode archive or distribution signing.

Create/choose TWO App Store Connect app records with the exact existing bundle
IDs. Record their numeric IDs in release.json. Complete metadata, public policy
and support URLs, current age rating, export-compliance/privacy answers and private
reviewer access. The current targets include iPhone **and iPad**: supply required
screenshots and verify iPad compatibility; do not silently change device family.
Generate the aggregate Privacy Report from EACH Xcode archive and reconcile SDK
disclosures. Upload each verified IPA through Transporter, or distribute the
matching archive through Xcode Organizer. Wait for processing, attach the build,
resolve validation/issues, and select **manual release after review** so the
owner controls launch. This guide does not authorize accepting new agreements or
public submission on the owner’s behalf.

## Final gates for both platforms

Read `release/store/PRIVACY-AND-REVIEW.md` for source-based data flows, AI/face
processing and safe private reviewer access. Screenshots, public approved policy
pages, real contact verification and review-access instructions are store
requirements, not optional polish. Do not give stores an admin Google account,
someone’s private KYC, invented approved Captain or fake credit. Store app access
must be solved with the owner without weakening the live backend.

```sh
node release/store/check.mjs --source-only  # portable source/metadata checks
node release/store/check.mjs                # fails until owner/public gates are real
```

Record each actual console outcome, archive/hash and any remaining blocker.
Preserve production keys and the existing training/coverage/cancellation/payment
rules. No backend redeploy is required just to compile or upload the clients.
The final public Submit/Publish action is for the owner/Aman after these gates.

Official requirements are linked in `release/store/PRIVACY-AND-REVIEW.md`.
