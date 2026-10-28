# Captain document upload follow-up - 28 October 2026

The owner supplied Aman's iPhone screenshot and explicitly requested removing
**Open DigiLocker**. This is an approved change to the af036f0 W05 screen only.
The remaining Customer/Captain design, hidden training and human approval rules
remain unchanged. The screenshot's generic error alone does not identify its
exact native cause; the production configuration issue below was independently
confirmed during investigation.

## Phone upload and review

- The existing W05 primary button is now **Upload Aadhaar photo**, using the
  existing **Take photo / Choose from gallery / Cancel** action sheet. DigiLocker
  action, copy and its demo auto-completion path were removed. The duplicate
  inline upload link was removed; colours, typography, components and layout
  structure remain the same. English/Hindi/Telugu copy describes manual review.
- Real bytes upload to the existing private `kyc/<uid>/aadhaar.jpg` path.
  Unauthenticated and empty uploads are rejected. Capture cancellation, poor
  photo quality and upload failure do not advance the real KYC stage. Upload
  failures now give specific recovery guidance without exposing provider data.
  An unconfirmed upload is not claimed as saved or as identity approval.
- The Captain completes the existing selfie/payout steps and submits. Authorized
  humans inspect private evidence in https://wheelio-apps.web.app/admin/ and
  approve or request corrections. Uploading/clear-photo quality never approves
  a Captain. No applicant was approved or test document added to production.

## Production upload configuration repaired

The existing Storage rules consult Firestore for account state, KYC review locks
and assigned-job access. The production Storage service agent had its ordinary
Storage role but **no** `roles/firebaserules.firestoreServiceAgent` binding.
This cross-service permission is required for those checks; see
[Firebase's cross-service rules guidance](https://firebase.google.com/docs/rules/manage-deploy#manage_permissions_for_cross-service_cloud_storage_security_rules)
and the [documented service role](https://docs.cloud.google.com/iam/docs/roles-permissions/firebaserules#firebaserules.firestoreServiceAgent).
The installed official CLI also skips this permission check in noninteractive
deploys (`firebase-tools/lib/rulesDeploy.js`), explaining how a rules deployment
can succeed without this configuration. This is a plausible cause of the reported
upload failure, not a claim to have reproduced that exact iPhone request.

Added and executed the owner-only, idempotent operation:

```sh
node backend/firebase/operations.cjs configure-storage-rules
```

It resolves the existing project's number, verifies the existing Google Storage
service agent, adds only the documented role to that agent with an IAM etag, then
reads back the binding. Existing bindings/conditions are retained. A second run
confirmed the permission without adding another binding. No person, public user,
Captain or Customer gained a new role. Storage rules/authentication, KYC review
locks, organization policy and human approval were not relaxed. No secrets were
copied, private photos inspected or production documents created for this check.

## Design guard and checks

W05's explicitly approved upload-only snapshot is
`output/design-audit/captain-W05-document-upload-approved.png`. The design audit
compares W05 against that exact image while every other state stays pinned to
af036f0. It does not ignore the entire W05 screen. The snapshot is a disconnected
gallery fixture with sample-only controls; production tests verify those controls
are absent and training stays hidden.

- **44 Flutter tests passed:** 9 Captain, 18 shared Firebase and 17 Customer.
  New checks cover camera/gallery/cancel entry in all three languages, no
  DigiLocker, no live testing skip, no KYC/Online grant on cancel and safe
  upload-specific errors. Existing hidden-training/admin gates passed.
- **19 focused backend/rules tests passed** in the Auth/Firestore/Storage
  emulators: private uploads, review-time upload locks, unauthorized denial,
  application review/corrections, audited human decisions and approval gates.
- All four Flutter analyses, both release web builds and portable iOS
  source/tooling checks passed. The native Runner projects/IDs were not changed.
- **156 states pixel-match af036f0; W05 exactly matches the approved upload-only
  snapshot; zero unreviewed differences or capture errors.** Full results:
  `docs/KYC-UPLOAD-DESIGN-RESULTS-2026-10-28.json`.
- The missing production service role was applied, read back and verified on an
  idempotent second run. No production test account/document/approval was created.

Physical iPhone camera/library upload, Apple permissions and the exact previously
failing request still need Aman's rebuild/retest. No new live transaction
acceptance is claimed. Firebase's required IAM repair is already applied. A native
app must be rebuilt from this source to remove the old button; a backend change
cannot replace an installed iPhone binary. Hosting was not republished by this
follow-up.

## Aman / Claude retest

Pull the corrected staging commit containing this report, then rebuild. Open Captain -> Quick KYC
-> Aadhaar. Confirm no DigiLocker control/text; tap Upload Aadhaar photo, cancel
once, then select a genuine consenting document using camera or Photos. Confirm
the actual saved upload before continuing. Finish selfie/payout and submit.
A separate authorized reviewer checks the application in the admin portal.
Do not replace uploads while it is under review; request corrections first.
If upload still fails, preserve the specific new message and the safe Firebase
plugin/error code from Xcode. Keep document images, IDs, phone numbers and tokens
out of Git or shared error reports.
