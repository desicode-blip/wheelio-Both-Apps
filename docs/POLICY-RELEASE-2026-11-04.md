# 4 November: website and app policy release

Read this after the 3 November store guide. Ajay explicitly approved implementing
Aman's new rules before publishing his website pages. Preserve Aman's website
and the existing native app designs. Customer is now **1.0.4 (9)**; Captain is
**1.0.5 (10)**. Older local AAB/ZIP receipts numbered 8/9 are historical artifacts,
not builds of this change. Native compilation/install on a physical iPhone still
requires Aman's Mac and final acceptance; no store submission is performed here.

## App/backend behavior

- New `walletByTime` snapshots include `earlyCreditBps:9800`: through exactly five
  minutes, 98% of total cash-plus-wallet value becomes credit (2% fee), including
  washes starting inside two hours. Later, at least two hours before the confirmed
  window, 50%; inside two hours, zero. Service failures/upheld complaints still
  return 100%. Old snapshots retain their original rules. Server quotes and
  atomic capacity/Captain/wallet changes remain mandatory.
- Customer Review/Help use the actual percentage from the saved/current policy.
  Older clients without `cancellationPolicyVersion:2` cannot create bookings on
  the new terms; they receive an update instruction. Assigned historical work
  remains finishable. Update Customer before creating new acceptance bookings.
- Wallet grants carry integer-paise amounts, grant times and one-year expiry.
  Spending consumes the oldest expiring credit first. An unpaid reservation
  restored on cancellation retains its original expiry; it cannot renew expired
  credit. New cancellation/service-failure awards get a new one-year grant.
  Existing legacy balances receive a full year from the recorded cutover, not
  from an invented historical date. Owner-only `configure-release-policy` dates
  these transactionally without changing amounts or historical booking terms.
- The existing wallet card shows remaining credit and its expiry dates. No new
  history screen, merchant, payment instrument or app layout was introduced.
- `/api/account-deletion-request` validates/rate-limits submissions and returns a
  private `DEL-` reference. The form also opens the authored email copy. No server
  email is claimed. A phone number in a form never authorizes deletion.
- Private admin lists requests, receipt/due dates, notes and status. Reviewers
  acknowledge, contact the registered number, verify ownership, and explicitly
  confirm deletion. The verified UID is bound to the request and expires after
  seven days; a changed account needs reverification. Existing role isolation,
  open-work/payment/wallet safeguards and retryable cleanup still apply.
- In-app support/problem submissions have stable `SUP-` references. Support
  staff must include a reference in manual email/phone replies and monitor
  acknowledgement/deletion deadlines; software does not make those human calls.

## Retention

The hourly, bounded, restartable `maintainDataRetention` job deletes terminal wash
media/foreground job locations after 90 days; unresolved disputes are held. It
deletes approved/rejected Captain KYC media after 90 days while preserving the
human verification record and payout details. A pending correction is not a final
rejection. Closed support content expires after one year, closed deletion records
after three, settled financial records after eight years. Private Storage failures
are logged for retry; no successful purge marker is written before deletion.

Deleting the old Captain selfie means there is no retained face reference to
compare against. Future job selfies therefore enter genuine **human review**,
not an automatic match. `/admin/` has a private job-selfie queue and authenticated
photo viewing. A reviewer must verify the assigned Captain before accepting;
retake remains available. Current approval/earnings are not fabricated or reset.

Provider settings checked on 4 November: application logs 30 days; Google's
mandatory `_Required` audit-log bucket is locked at 400 days; Storage soft-delete
recovery is seven days; no Firestore backups/schedules configured. The privacy
page explicitly discloses the mandatory audit-log exception and recovery window.
This does not change Google's locked security retention or organization policy.

## Release order

1. Backend emulator tests, native analysis/widget checks and portable iOS checks.
2. Deploy Functions, Storage rules and the deletion-rate TTL field override.
3. `node backend/firebase/operations.cjs configure-api-access` using the existing
   approved gateway model; no organization-policy relaxation.
4. `node backend/firebase/operations.cjs configure-release-policy` once the new
   controllers are ACTIVE. Publish `release/store/approved-content.json` with
   `operator.cjs publish-content ... --confirm`.
5. Build/deploy the private admin. Preserve all other default-site files.
6. Stage approved pages and deploy only the existing `apps/website` website
   target. Verify all five public URLs, the request rewrite and admin auth gates.
7. Commit/push staging; Aman pulls and tests BOTH apps on iPhone. Use
   `bash apps/flutter/tool/run-ios.sh` for device acceptance, then
   `bash apps/flutter/tool/archive-ios.sh` for signed App Store exports.

## Aman/Claude final acceptance

Pull staging without resetting local work. Read this file and the current store
publishing prompt. Test signup, documents, human approval, coverage/hours, live
booking, first Captain acceptance, selfie/before/after photos, Customer approval,
AI OFF/ON/direct-send, deletion/fresh signup and wallet reuse. Check the new 98%,
50%, zero and full service-failure outcomes against server quotes. Avoid creating
unnecessary real paid bookings; agree any actual live payment with its payer.
For one-year expiry use emulator fixtures, never change the production clock or
award production test credits. Check public support/legal links on iPhone.

Store gates remain: actual signed Mac archives and device checks, both App Store
Connect IDs/records, private safe reviewer access, current iPhone/iPad screenshots,
privacy/rating/audience/export answers and owner final submission. No store
approval or Xcode/device success is implied by Windows tests.
