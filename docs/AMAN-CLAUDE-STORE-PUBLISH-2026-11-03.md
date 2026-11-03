# Prompt to send Aman for Claude on his Mac

Read AGENTS.md, CLAUDE.md, docs/STORE-RELEASE-2026-11-03.md and
release/store/PRIVACY-AND-REVIEW.md first. Aman approved the tested version for the
initial release. Prepare BOTH existing Flutter apps for App Store submission;
preserve their current designs and functionality. Do not recreate screens,
restore retired apps, change bundle IDs/team/payment backend or touch TrustKeyper.

Also read docs/AI-PHOTO-CONSENT-2026-11-03.md. The owner subsequently approved an
optional alert in the existing style: Customer permission before checkout and
Captain permission before AI. Test both Allow and Continue without AI. Refusal
must still lead through after photos -> Customer review -> approval. Do not
remove the server consent gate/protocol check to work around a server-version
message; deploy/verify the documented backend update first if needed.

Preserve local work, fetch origin, switch to staging and pull --ff-only. If it
cannot fast-forward, inspect/preserve changes; no hard reset or force push.
Record the source commit. Use Flutter 3.38.6, Xcode 26+ with iOS SDK 26+ and
CocoaPods, paid Sumit Mandal team 28JNT7H8KA, and the existing .customer/.captain
bundle IDs. These are two separate App Store apps. Source versions are Customer
1.0.4 (7), Captain 1.0.5 (8); check App Store Connect for occupied build numbers.

Run the portable iOS checks, then `bash apps/flutter/tool/archive-ios.sh` from
the repo root. It prepares locked dependencies, signs/builds/exports both App
Store IPAs and verifies production APNs/distribution entitlements. Output includes
IPA + xcarchive + dSYMs + provenance under build/store/ios/. Keep those artifacts.
An archive without a verified exported IPA is not success. Fix actual build/export
errors narrowly; do not disable real SMS verification, regenerate APNs keys or
change the Apple team. The existing APNs key is already configured in Firebase.
No Firebase CLI login or merchant secret is needed to compile either client.

Guide Aman through App Store Connect: select/create the two records with the
correct existing bundle IDs, record numeric IDs, generate/review each archive’s
aggregate Privacy Report, collect accurate current iPhone/iPad screenshots, and
fill the current listing/privacy/rating/export compliance/review-access fields.
Use the prepared metadata and policy drafts as review material, never pretend
drafts or placeholder credentials are approved. The owner supplied Washkrew,
info@washkrew.com and +91 80885 16875; verify contacts and obtain approval for
actual policy/retention/commercial text. Stage/deploy approved pages on the
EXISTING website and update only the approved support/legal config as documented.
Preserve hidden training and the existing live WashKrew payment policy.

The owner must arrange safe private reviewer access with no Indian-SIM/GPS/admin
login barrier; do not expose another person’s KYC, invent approval or seed fake
production accounts/credits. Review AI/photo disclosures and required consent.
Run `node release/store/check.mjs` when all recorded gates are complete. Do not
mark a gate true until the actual work/evidence exists.

Upload the verified IPAs using Transporter or Xcode Organizer when Aman authorizes
that action. Wait for processing, attach each correct build and resolve actual
validation messages. Prepare manual release after review. Show Aman a concrete
summary before final submission/publication and leave that final action to him.
Do not submit an unsigned/device/ad-hoc build or assume approval is guaranteed.

For Android, Ajay’s full production signed AABs and exact mapping/provenance files
are in build/store/android/ and must be forwarded separately (generated files and
private signing keys are not in Git). If rebuilding on this Mac, obtain the
existing upload keystore/properties privately; never replace the key. Use ONLY
the two existing WashKrew Play app records, never TrustKeyper. Follow the Android
section of the publishing guide and preserve the credit-card/EMI/pay-later ban.

Report the commit, both version/builds, artifact hashes, actual validation/upload
outcomes and any owner/store gate still open. Commit narrow Mac fixes/Pod lock
updates and push only when asked. Do not claim store approval before the stores
have reviewed the apps.
