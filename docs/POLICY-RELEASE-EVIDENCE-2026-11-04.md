# Website/policy deployment and Mac handoff: 4 November 2026

Aman's staging website handoff `ac9e2f7` was fast-forwarded, preserving his
website/UI. Ajay explicitly authorized the new financial/retention/deletion
functionality before public publication. The implementation is described in
`POLICY-RELEASE-2026-11-04.md`.

## Published and checked

- `https://washkrew.com/`, `/privacy`, `/terms`, `/support`, `/delete-account` and
  `/policies` all return HTTP 200 and match their actual generated source bytes.
  Only the existing `washkrew` website Hosting target was used. Privacy text
  clarifies actual selfie-reference retention, counterparties' wash evidence,
  Google's locked audit-log exception and the private Storage recovery window.
- Private admin assets match their built/published files. Default Hosting version
  `5eeb114c0622a30e` preserves all **130** non-admin/non-Firebase-generated files
  with unchanged paths and hashes. No Customer/Captain web rebuild was needed.
- All **74** Functions are ACTIVE with minimum instances zero. The retention
  Scheduler is ENABLED on `every 60 minutes`. New customer/admin callables return
  HTTP 401 without authentication. Website deletion rejects an invalid body (400)
  and an untrusted Origin (403), through the actual Hosting rewrite.
- New cancellation configuration is 9800/5000/0 basis points by time. Two existing
  undated wallets were dated from the single recorded cutover, with their value
  preserved. Existing booking snapshots and original-merchant refund obligations
  were not rewritten. The separate WashKrew LIVE merchant and hidden training
  settings were checked and preserved. Approved support/legal config is published.
- Google initially rate-limited the large Functions rollout. The remaining
  operations completed. The five new callable invoker-setup errors were recovered
  using the project's established `configure-api-access` operation, without
  changing organization policy. The final four deadline-related updates deployed
  successfully as a small, codebase-qualified batch.
- Downloaded representative live source archives were compared with their exact
  commits: `createBooking`/`maintainDataRetention` against `db6913f`, and the new
  public/private deletion controllers against `62091cb`: **28 module comparisons
  matched**. The later app-copy/docs commits do not alter that backend source.

No real account was deleted/approved as a test, no live payment/refund was
initiated, and no new production QA account/credit was created by these checks.
The wallet migration dates existing credit; it does not award additional credit.

## Verification

- Full backend demo-emulator suite: **215 passed**. Follow-up service/deadline
  suite: **109 passed**. Final policy/financial-retention suite: **9 passed**,
  including oldest-first/expired reservation handling, historical terms, new
  booking disclosure enforcement, human-request ownership/safeguards, retained
  dispute evidence, due-query coverage and eight-year settled-record cleanup.
- All four Flutter analyses passed. The full native/shared Flutter suite passed;
  the final focused wallet/cancellation run passed **13 tests**, including 98%
  versus historical 100% copy and displayed expiry dates. The wallet fixture was
  visually inspected; the authored screen/components remain.
- Browser inspection checked the website cancellation table and deletion form;
  empty submission displayed validation and generated no request/console error.
- Portable iOS source/tooling checks passed for both existing apps. No Xcode
  archive, physical iPhone acceptance or App Store upload was performed here.
- Store source checks pass. Full submission checker now passes all public URL
  checks, but still reports both numeric App Store Connect IDs unrecorded and
  privacy answers/reviewer access/screenshots/age-rating gates incomplete.

Private detailed logs/source comparisons are under ignored `.cache/`; no private
keys, phone test codes, KYC or signing material is part of this Git handoff.

## Aman next

Pull staging, then follow `AMAN-CLAUDE-STORE-PUBLISH-2026-11-03.md` and the current
4 November policy record. Build/install BOTH apps with `run-ios.sh`, test the
connected Customer → Captain → admin flows on iPhone, and only then create the
signed App Store exports with `archive-ios.sh`. Source versions are Customer
**1.0.4 (9)** / Captain **1.0.5 (10)**. Check store consoles for occupied codes.
Older Customer test builds need updating before making new-policy bookings.

Do not submit the older local Android 8/9 AABs/ZIPs as this updated release; build
new artifacts from this source if needed. Store publication still needs the real
Mac archives/device checks, screenshots, private safe reviewer access, metadata
and owner final submission. Public policy URLs are ready for those listings.
