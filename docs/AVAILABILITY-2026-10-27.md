# Booking availability and Aman's UI integration — 27 October 2026

This follow-up is based on remote staging `af036f0` and Aman's
[UI/backend report](CHANGES-2026-10-27-UI.md), merged locally as `1520bb4`.
The owner's decisions are **4 AM–10 PM booking windows** and **delete only the
account in the current app**. Payments remain test mode.

## What caused the reported empty slots

A read-only check of the actual Firebase project found one Captain account:
`kycStatus: notSubmitted`, `approved: false`, `online: false`, no approved
societies and no application submission timestamp. The phone's “Skip 30 min
(testing)” changed only local approval/Online state; it never made that account
eligible on the server. No account was fabricated, submitted or approved to
hide this condition.

Two further problems were real software defects: exact slider times were rounded
to the old 6–10 / 10–14 / 14–18 periods, and Customer C12 fetched capacity only once
per society/date. Later approval or a preference change could leave that screen
stale. The original “Any time of the day” card was already present, but its
designed empty-capacity state hides it when there are fewer than two open windows.

## Connected behavior

| Area | Result |
| --- | --- |
| Design | Retains Aman's staging C12 all-day card, multi-select chips, Captain two-step work profile, sliders, sun/moon arc, summary animation and existing deletion/OTP components. No asset, palette, typography or spacing replacement. |
| Exact work times | `workingSlots` stores integer `startMinute` / `endMinute` pairs from 240 through 1320, on half-hour boundaries, at least one hour per range, at most four ranges. Touching/overlapping ranges merge. An explicit empty list means any time. Restarts restore these exact values. |
| Matching | An exact period can overlap a Customer window, but a Captain whose period has already ended cannot supply capacity for the remaining part of that window. All comparisons use server time in IST. Offers still require an eligible approved Captain and a subsequent atomic claim. Saved area preferences apply consistently to displayed capacity, creation, capture and advancement as well as dispatch/claim. Historical whole-window preferences remain supported; an old-client edit explicitly replaces exact preferences. |
| Customer freshness | C12 rechecks every 20 seconds while open and on app resume. Request revisions discard old responses, including A–B–A date races. Background refresh keeps controls visible and preserves selections/all-day intent. Removed capacity cannot silently substitute an unchosen time. The server response governs live availability instead of the phone clock overriding it. |
| Flexible bookings | Original selected windows and the any-time flag restore from saved bookings and are included in Captain offers. Current dispatch still reserves one selected window and can advance to the next eligible requested window; it does not promise a Captain who has not accepted. |
| First work profile | A failed server save stays on the existing setup form rather than closing with an unsaved preference. |
| Approval/Online | Firebase sessions use actual server approval/Online values. Onboarding/review test skips are confined to the sample app. Actual submitted applications retain the existing review popup and countdown; a timer does not award approval. An approved waiting Captain can use the existing go-online path. |
| KYC errors | A Storage 404 is treated as a missing upload and produces an actionable precondition. Other Storage failures remain errors. Photo generation checks also handle a subsequently missing object. |
| DigiLocker | Its existing control explains that the provider is pending. It no longer substitutes a camera capture for a DigiLocker verification. The existing Aadhaar photo-upload control remains available. |
| Deletion | Both apps request fresh SMS verification in the existing phone/code screen before deleting. The backend checks recent authentication and open work in the selected role. The other app's bookings, Captain approval, wallet, private photo and notifications remain intact. Firebase Auth is removed only when no app role remains. Removed roles cannot use cached tokens to recreate app data; fresh SMS registration can create that role again. Legacy role records are handled conservatively. |

## Verification

- 98 backend, payment, service and security-rule tests passed using only the
  isolated `demo-wheelio` emulators. Cases include early/late windows, exact
  half-hour preferences, under-review versus approved capacity, payment/offer/claim,
  area filtering, role-only deletion with active work in the other app, recent-auth
  checks and private upload access after deletion.
- An additional targeted emulator test passed the complete nine-window all-day
  selection through booking, capture and both Captain offers (99 distinct backend
  tests verified in total).
- 16 Customer tests passed, including stale availability responses and the existing
  C12 all-day card actually saving a multi-window booking intent.
- 3 Captain tests passed, including guards against phone-only Firebase approval.
- 16 shared Firebase tests passed, including web/native current-phone
  reauthentication without signing into another account.
- Both app analyzers and release web compilations passed. No new actual merchant
  charge, refund, production test
  Captain, fixed OTP or native-device success is claimed by emulator tests.

## Publishing

Published successfully to project `wheelio-apps` on 27 October 2026: updated
Functions, Storage rules and both web apps at
[Customer](https://wheelio-apps.web.app/app/) and
[Captain](https://wheelio-apps.web.app/captain/). The deployment's authenticated
HTTP gateway configuration was reapplied without changing the organization
sharing policy. The separate marketing website was not redeployed by this change.

Post-deploy checks confirmed both hosted JavaScript bundles exactly match the
local release hashes, both app URLs return 200, and the actual availability
endpoint returns all nine configured two-hour windows from 4 to 22 with the
correct CORS origin. Unauthenticated claim, deletion and preference writes return
401. A final read-only configuration check confirms `paymentMode: test`; the
unsubmitted real Captain remains unapproved/offline, so actual capacity is
correctly unavailable until genuine onboarding/review is completed. No account
or booking was seeded or deleted during those checks.

The hours operation is
`node backend/firebase/operations.cjs configure-test-hours`: it refuses live mode,
updates only `slotWindows` using the document update-time precondition, and
preserves all Maps, society, training, support and merchant configuration.

## Required real-account and Mac check

1. Rebuild **both** Flutter apps from this updated staging source on Aman's Mac;
   an installed older iPhone binary does not update when Firebase Hosting changes.
   Aman's report records his earlier Release installs; this follow-up still needs
   a new native build and physical acceptance.
2. Complete the actual Captain's uploaded documents/payout/application. The
   operator must review the real submission and approve its requested societies
   using the existing owner workflow (`operations.cjs approve-captain`). Do not
   approve a skipped or unsubmitted account, seed a fake Captain, disable training
   requirements or turn placeholder art into training completion.
3. On two different accounts, save early/late work periods, reopen the Captain
   app and confirm exact values; open Customer C12 in the same served society.
   After real approval, capacity should refresh within 20 seconds or on resume.
   The same UID is intentionally excluded from booking itself as Captain.
4. Verify test checkout, Captain Online/offer/claim, optional GPS, actual camera
   before/after photos, Customer approval and earnings. Confirm both app deletion
   paths only with disposable **emulator** accounts before considering a real
   deletion; this task did not delete the owner's account.

Separate WashKrew merchant onboarding/access, approved training/policies/support
content and unavailable third-party provider accounts remain with Aman/the owner
as previously agreed. Review and payout/dispute decisions remain human operations.
