# Private Captain reviews

**28 October owner policy:** training/videos and quiz are hidden and not required
for now. The detail view says **Admin document review**. Actual document/payout/
society review and authorized approval remain mandatory; no automatic approval
or training completion is awarded. Approved Captains can choose to go online.

Published at https://wheelio-apps.web.app/admin/. This separate operations page
does not replace or redesign either Flutter app. Its static sign-in shell is
public; every application, image and decision requires server authorization.

Sign in using an owner-approved, verified Google account. The server checks the
exact email against `privateConfig/captainReviewers.emails` on every request;
phone OTP accounts and arbitrary Google accounts do not have review access.
The reviewer list is never included in the browser build. The admin app uses a
separate Firebase app name and session persistence, so Customer phone login is
not replaced by admin login.

1. Choose an application awaiting review and inspect its private identity photos,
   payout details, training status and requested societies.
2. To request corrections, select the specific items and write an explanatory
   note. Confirm the review. The Captain receives an account notification and
   can update/resubmit those items in the existing app screens.
3. To approve, review the identity and payout details, choose active societies
   requested by that Captain, write a note and confirm. Required current training
   and quiz completion cannot be bypassed by this page. Google authentication
   must be no more than 30 minutes old; use **Verify Google session** if needed.
4. Approval records the reviewer, note, societies and audit history. It leaves
   the Captain offline. The Captain can then choose **Go online**; existing work
   restrictions, area, work hours, payment mode and assignment checks still apply.

These are human identity/work-eligibility decisions. A clear photo, model result,
uploaded bank image or entered UPI ID is not verification of identity or bank
ownership. Do not approve a real person without the operator's actual review.

Owner CLI: `node backend/firebase/operations.cjs configure-captain-reviewers
PRIVATE_REVIEWERS_JSON` accepts `{"emails":["reviewer@example.com"]}` and changes
only this private reviewer allowlist. It does not grant Google Cloud IAM roles or
approve Captains. Keep the input file outside Git.

Build as part of `node apps/flutter/tool/build-firebase.mjs`, or rebuild only
the admin assets with `node apps/admin/build.mjs firebase.local.json
build/firebase-hosting/admin`. Only public Firebase configuration is generated.
After a Functions deployment, run the existing owner-only
`configure-api-access` operation; do not disable the organization policy.

Local emulator builds require a loopback `demo-*` project. Disposable reviewer,
identity/evidence and payment fixtures must never be seeded into production.
