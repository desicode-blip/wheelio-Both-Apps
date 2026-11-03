# Store disclosures and reviewer access — owner review required

This is a source-based preparation record, not a declaration already filed with
Apple/Google. Review each platform’s questions against the FINAL signed app,
current provider disclosures, actual service operations and legal policy.
Do not select “no data collected” merely because access is private/encrypted.

## Observed data flows

| Data | Customer | Captain | Purpose/recipients |
| --- | --- | --- | --- |
| Name, phone, Firebase UID | Yes | Yes | Native phone sign-in, role profile; Firebase/Cloud |
| Precise/approximate location, selected address | Yes | Yes | Nearby places/parking, fixed coverage and job checks; Google Maps/Places and Firebase |
| Vehicle plate, parking note, bookings | Yes | Assigned job | Service delivery; only relevant authorized parties |
| Photos/video/voice supplied in app | Yes | Yes | Vehicle information, wash evidence, help; private Storage and authorized parties |
| Aadhaar/document photo, selfie | No Customer KYC | Yes | Private human review; private face/quality checks, not automatic KYC approval |
| Face similarity/identity-check results | No | Yes | Private operational checks; disclose sensitive/biometric processing appropriately |
| Payout bank/UPI details | No payout form | Yes | Human-reviewed payout operations; private backend |
| Payments, top-ups, wallet, earnings references | Yes | Job/earnings | Service/accounting; separate WashKrew Razorpay merchant handles checkout credentials |
| After-wash photo suggestions | Wash evidence | Submits images | Four vehicle after-images sent to Google Vertex AI/Gemini; human review remains decisive |
| Support notes, notification tokens, technical logs | Yes | Yes | Help, security, notifications and reliability; Firebase/Cloud |

App-level privacy manifests list linked data for app functionality, no app
advertising/tracking, and app-container file-stat/timestamp access C617.1 (temporary
media in `media_native.dart`/`playback_native.dart`). They do not override SDK
manifests or replace the App Store privacy questionnaire. Generate Xcode’s
aggregate Privacy Report from each final archive and reconcile all SDK entries,
including Firebase, Maps and Razorpay. The Mac export check verifies the app
manifest is actually in the IPA. It does not certify every third-party SDK.

Source references: `backend.dart`, `live_backend.dart`, `service.mjs`,
`photo-checks.mjs`, private photo service `server.py`, Storage/Firestore rules.
No advertising SDK or custom native CAPTCHA is added by this release preparation.
Review merged Android permissions/provider practices before the “contains ads”,
advertising-ID and Data safety answers. Data encrypted in transit is still
collected data. “Shared” has platform-specific service-provider exceptions;
review them rather than automatically classifying every provider identically.

## Policy and consent decisions before submitting

The owner replaced the earlier consent popups with an explicit paid-booking toggle
and adjacent Google AI/photo-sharing explanation, plus Captain Check with AI /
Send without AI actions. See `docs/AI-PHOTO-TOGGLE-2026-11-03.md`. Server protection,
manual alternatives and in-flight preference invalidation remain mandatory.
Owner policy/provider/retention review and public policy publication are still
required; this software change does not auto-complete those approval flags.

- Confirm privacy/support mailbox and phone work. Publish owner-approved privacy,
  terms, support, deletion and combined policy pages on washkrew.com. Drafts are
  outside public Hosting; changing a flag does not approve unresolved draft text.
- Confirm the legal address, audience, applicable retention periods and provider
  settings. Current deletion scrubs role data and disconnects ownership from
  operational records; it does not erase all counterparties’ evidence/accounting.
- Review the existing capture/AI-check notices and consent. In particular,
  distinguish face processing from identity approval and disclose the Google
  Vertex AI/Gemini vehicle-photo transfer. Obtain any required explicit consent
  before personal data is shared with a third-party AI. A privacy-policy link
  alone is not necessarily sufficient. Preserve the approved designs; obtain an
  owner decision before introducing a new consent screen or other UI change.
- Complete both platforms’ current age-rating/audience questions honestly. No
  children’s/financial/health/UGC answer is inferred from an app category.
- Use Razorpay for physical vehicle washes and corresponding closed-purpose
  service credit, not digital unlocks or an external general wallet. Do not add
  Apple/Google digital in-app billing to this real-world service flow.

## Private store reviewer access

Apple/Google reviewers need stable access even without an Indian SIM or a Captain
standing inside the coverage circle. Do not give them a real person’s private
Aadhaar/payout data or an admin Google login. Do not invent an approved Captain,
seed production QA documents, disable app verification, grant fake KYC, add free
wallet money or silently switch the live merchant into test mode.

The owner must arrange a consenting, appropriately scoped review account and
human-approved Captain access, and provide instructions privately in App Review /
Play App access. If using existing owner-controlled Firebase test numbers,
confirm that arrangement explicitly; keep their codes outside Git and public
listing text. Do not assume existing development numbers are safe to share.
Supply an address inside that Captain’s saved area, the saved work hours/timezone,
and a reachable review contact. Explain the human approval process and describe
how the reviewer can see both roles without creating an actual paid job. Agree
any reviewer payment/credit arrangement with the owner; a live charge needs the
payer’s authorization. A review-access solution is a submission gate, not a
reason to bypass production security.

## Review notes to adapt privately

“WashKrew facilitates real-world exterior vehicle washes. Customer and Captain
are separate apps connected through Firebase. Customer availability depends on
an approved Captain’s fixed coverage circle, continuous work hours and remaining
capacity. After payment, eligible online Captains receive the offer together;
the first valid acceptance is assigned. Captains submit before/after evidence;
the Customer reviews completion. Identity/payout approval and dispute decisions
are human operations. Training videos are currently hidden. Cancellation rules
are shown in the app and policy. Account deletion uses two in-app confirmations
and removes only the selected role, with support for unresolved transactions.
Reviewer access instructions and contact follow in this private review field.”

Then add the actual approved private credentials/location/work hours, never
placeholders. Store login alone is not sufficient evidence of completed review
access. The public admin portal URL is not a reviewer credential.

## Official references checked 3 November 2026

- [Apple SDK requirements](https://developer.apple.com/news/?id=ueeok6yw)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Google account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Android 16 KB pages](https://developer.android.com/guide/practices/page-sizes)
