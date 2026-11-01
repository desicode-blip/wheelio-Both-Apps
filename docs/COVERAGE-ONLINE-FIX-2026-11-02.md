# Captain Online and dynamic area capacity — 2 November 2026

Status at this commit: local verification complete; production publication and
physical follow-up still pending. Append actual deployment/device results below
before claiming the live error is resolved.

## Cause and owner rule

The owner approved a Captain with a saved centre/radius and work hours. The live
`config/operations.coveragePolicy` was `captainAreaV1`, but the deployed
`setCaptainOnline` source generation still contained the unconditional
**Choose at least one approved society** guard and lacked the area module.
The active configuration/app and deployed controllers were inconsistent. An
ACTIVE function or a generic deployment-complete message alone does not prove
that the intended source is executing.

The owner additionally confirmed on 2 November that the **entire Customer time
window** must fit a Captain's working hours. Example: with 9 AM–6 PM work hours,
8–10 AM is unavailable; 10 AM–noon may be available. One continuous saved period
must cover the window; two periods separated by a break cannot be combined.
Adjacent saved periods are merged normally. The existing empty-period convention
means all day, 4 AM–10 PM; missing/invalid hours do not qualify.

## Resulting behavior

- Human-approved Captains with a valid saved map area/hours can go Online without
  manual society assignments. Human approval and work-status restrictions stay.
- Each confirmed home inside a covering Captain's fixed radius uses that
  Captain's saved work periods. Availability needs at least one eligible Captain
  whose complete period contains the Customer window.
- Paid capacity remains per Captain across **all homes**. Two overlapping
  eligible Captains permit two simultaneous reservations, not unlimited capacity
  once per building. When both are reserved, the window is unavailable; the
  server also rejects a new booking there. Cancellation releases capacity.
- Payment capture transactions and claim-time locks prevent concurrent purchases
  or reassignment from overselling the same Captain. Saved hours are rechecked
  before dispatch/claim. Existing assigned jobs remain finishable after area edits.
- Saved area/hours/approval changes and booking reservation changes use the
  existing availability revision signal and time-picker refresh. The existing
  design disables unavailable choices and revalidates selected windows.
- Historical society bookings retain their saved policy and prior hours behavior.
  No Customer/Captain layout, typography, asset, colour or widget was changed.

The live configuration, prices, payment merchant, wallet balances and human
approval records are not rewritten by this correction. No new paid idle instance
is enabled, and no fake live booking or payment is used for verification.

## Local evidence

The full Auth/Firestore/Storage emulator suite passed **175 tests**. After the
final invalid-hours alignment, all **12 focused coverage regressions** passed
against the final source. Syntax checks passed for the three edited modules.
The six added cases cover Online without society assignments, hours/area edits,
two-Captain saturation and cancellation, concurrent captures for three homes,
whole-window/break boundaries, and rechecking edited hours before claim.

All simulated payment captures and test approvals above are confined to
`demo-wheelio` and the existing fake provider, not the live merchant/project.
The target remains the existing Standard `(default)` database in `asia-south1`.

## Production verification requirements

1. Publish the matching function code with bounded deployment concurrency; keep
   existing organization policy, runtime limits and zero minimum instances.
2. Apply the documented `configure-api-access` operation after publication.
3. Inspect current function metadata/source generations and compare deployed
   `service.mjs`, `captain-area.mjs`, `booking-policy.mjs` and `index.mjs` with the
   local release. Do not infer publication from source present only on disk.
4. Check the owner's already-approved Captain can go Online through its installed
   app without the society error; restore its prior Offline state after testing.
   Do not approve someone or accept a real job as a test.
5. Read actual availability at the saved area without creating a paid booking;
   distinguish this live read/Online check from the emulator's saturation cases.
