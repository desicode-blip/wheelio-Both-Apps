# Deletion, fresh signup and stale-state recovery - 3 November 2026

Owner reported Customer place selection blocked by deletion status, and a deleted
Captain seeing old account information on login. No approved screen layout or
asset is redesigned. Source builds: Customer **1.0.4 (5)**, Captain **1.0.5 (6)**.

## Confirmed cause

The privately supplied account was stuck in a last-role Captain deletion:
`deletionStatus:pending`, `deletingRole:captain`. Cloud logs recorded Storage
HTTP 403 during cleanup. The actual runtime had bucket object-viewer permission
and Auth deletion, but no object-delete permission. The global pending marker
also blocked guest-safe discovery, while app listeners treated any shared profile
or cached Captain document as a usable app account. The initial deletion tests
missed interrupted cleanup followed by login and same-phone re-registration.
No phone number, UID, KYC or credential belongs in this report.

## Corrected backend

- Permission setup adds a custom role containing only `storage.objects.delete`,
  with a conditional bucket binding for KYC, identity, profile and Customer/
  problem attachment paths. It does not grant Storage admin, object creation,
  public access or deletion of other wash-evidence paths. Existing bindings and
  organization policy remain. Setup itself deletes no account/file.
- Existing server-marked pending requests can resume through scheduled recovery.
  Deletion attempts use a lease; errors release their lease and retain the request
  for retry. Cleanup completion remains distinct from an attempted delete.
- Fresh verified login can finish an interrupted deletion while preserving that
  newly verified Auth identity for clean registration. Cached pre-deletion tokens
  cannot recreate a deleted role. Completed tombstones are replaced with clean
  role data only under the fresh-login checks.
- New/recreated Captain accounts start unapproved, offline and without old KYC,
  payout, coverage, hours or training marks. An empty name uses the existing name
  form after login; already-verified phones do not need a second SMS to save it.
  Customer names do not inherit the Captain name. Human approval is required again.
- Historical financial records are detached/anonymized, not relabeled or erased
  as if no transaction occurred. Closed top-up/payment mappings and legacy private
  request records cannot reattach to a recreated Customer. Open-job/payment/
  funded-balance deletion guards remain; the other app role stays intact.
- Public coarse availability/place discovery remains available like guest access
  even with an old token. It grants no private booking write/approval permission.

Conditional object grants follow Google's
[Cloud Storage IAM conditions](https://docs.cloud.google.com/storage/docs/access-control/iam)
and [resource-name extraction rules](https://docs.cloud.google.com/iam/docs/conditions-attribute-reference).

## Corrected apps

Both stores gate private data on a **fresh server** profile for the current active
role. Cached or removed-role snapshots cannot populate old personal data. Fresh
metadata-only server transitions are observed. Generation checks discard old
account callbacks, including a delayed profile-photo response on the same UID.

Removal clears profile/photo, drafts and attachments, wallet display, histories,
notification state and navigation. Captain reset also clears KYC/progress, payout,
coverage, work hours, job/photos and approval flags. The authored welcome/login/
signup screens are reused. A fresh guest booking draft still survives normal
phone login; deletion reset is not applied to an unrelated valid guest draft.

Storage/network cleanup is an acknowledged server operation, not an instantaneous
multi-service transaction. Pending data is hidden from app hydration immediately;
physical cleanup must complete/retry. Historical financial records remain
separately retained as disclosed in the existing delete confirmation.

## Evidence

- **202 backend tests pass**, including interrupted last-role cleanup -> fresh
  Customer, same-phone Captain recreation, name/approval isolation, stale-token
  rejection, scheduled recovery and private history detachment.
- The expanded fresh Customer test also completes server checkout, mocked capture
  and a different Captain's atomic claim after re-registration; this is not a
  real-money or physical wash acceptance claim.
- **177 Flutter tests pass**: Customer 76, Captain 38, shared UI 9, shared Firebase
  54. Actual store listeners receive controlled server/cache snapshots and an old
  delayed photo response. Private state must stay empty until the new role is active.
- Analysis is clean in all four packages. An initial concurrent emulator run
  hit the existing transaction-closed timeout in a historical cancellation test;
  the standalone full rerun passed 202/202 without changing that financial policy.

No real Captain is approved or fake payment/wash evidence submitted as a test.
Windows cannot establish Xcode signing, compilation or physical iPhone behavior.
Use the updated Mac guide/results template for Aman's actual re-registration check.

## Live deployment and requested account recovery

Implementation commit **bafd72c** deployed nine affected Functions and Firestore
rules successfully to **wheelio-apps / asia-south1**. Post-deployment verification
confirmed all nine ACTIVE at minimum instances 0, exact source matches for
`service.mjs`, `account-access.mjs` and `index.mjs`, and matching published rules.
Anonymous register/delete/create-booking requests return **401 / UNAUTHENTICATED**.
The documented gateway setup was reapplied without weakening organization policy.

A temporary isolated probe under the actual deletion runtime identity verified
that allowed private cleanup objects can be deleted, while a different order path
returns **403**. It used the existing private Python image after function-image
ad-hoc launch attempts failed before running the test. No probe approved an
identity, made a booking or charged money. Temporary jobs/marker objects were removed.

The existing enabled maintenance schedule was run once to complete a previously
server-marked request, not to initiate a new account deletion or manufacture a
user login. Owner-side checks at **3 November 2026 09:08:15 UTC** establish that
the reported account's old Auth identity and Captain document are removed,
the completion record contains no old name/phone or pending-role flag, and its
KYC/identity/profile Storage prefixes each contain **zero objects**.
No private identifiers are copied here. Re-registration uses a genuine new phone
verification and does not resurrect the deleted role/approval.

Installed older apps do not receive the client reset/cache/registration changes
from a backend deployment. Rebuild Customer **1.0.4 (5)** and Captain **1.0.5 (6)**
from the current staging handoff before physical acceptance. Test deletion and
same-phone fresh signup on both roles, including preserving the other app role.
