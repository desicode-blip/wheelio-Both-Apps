# Captain Online and dynamic area capacity — 2 November 2026

Status: the backend correction is published and verified in `wheelio-apps`.
The owner-approved Captain successfully went Online in the installed Play app
without a society assignment. Live availability followed temporary work-hours
edits; the original hours and Offline state were restored. Source: `8d4f4b7`.

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

## Production and physical Android evidence — 2 November

1. All **62 existing Functions** updated successfully using the official Firebase
   CLI with process-local deployment concurrency of two. No function was added or
   deleted. Every function is ACTIVE, with minimum instances **0** and maximum
   instances **5**. No paid warm instance or organization-policy change was made.
2. The exact GCS source generation of each of the 62 functions was downloaded.
   SHA256 comparison of normalized `service.mjs`, `captain-area.mjs`,
   `booking-policy.mjs` and `index.mjs` matched the release for every function.
   This checks the actual deployed archives, including the previously stale
   `setCaptainOnline`, rather than assuming a deployment summary proves parity.
3. `configure-api-access` completed on retry after one request timed out. Read-back
   confirmed all **55 documented HTTP gateways** enabled and all **7 scheduled /
   triggered functions** retaining their IAM checks. Anonymous calls to
   `setCaptainOnline`, `createBooking` and `listCaptainApplications` each returned
   HTTP 401 / `UNAUTHENTICATED`; application/reviewer checks remain enforced.
4. On the connected OnePlus, the already-installed Play Captain app's existing
   **Go online** action succeeded with the owner's previously approved account,
   a saved 10 km work area and **zero legacy society assignments**. The native
   green Online state and authenticated backend read agreed. The agent did not
   approve this Captain. The original Offline state was restored afterward.
5. The existing native work-area editor was used to temporarily change hours.
   A read-only live `getAvailability` request at the saved work-area centre for
   **3 November** returned the following results:

   | Saved hours | Available Customer windows | Unavailable windows |
   | --- | --- | --- |
   | 9 AM–6 PM | 10 AM–noon, noon–2 PM, 2–4 PM, 4–6 PM | 4–6 AM, 6–8 AM, 8–10 AM, 6–8 PM, 8–10 PM |
   | Restored 4 AM–10 PM | All nine existing two-hour windows | None |

   The saved hours and availability revision were read back after each change.
   The final state is **4 AM–10 PM, 10 km radius, Offline**. No map-centre or
   approval change was intended or needed.

Private raw source archives, live-read records and the native Online screenshot
are retained in ignored local `.cache/` files, outside Git; they are not public
customer/Captain records. No app rebuild is required for this backend-only fix.
Customer and Captain Flutter source, authored designs and installed app versions
were unchanged by this correction.

The two-Captain saturation, concurrent capture, cancellation and claim assertions
are **emulator evidence**, not a real paid wash. The live checks above used normal
Online/hours controls and read-only availability; no live booking, payment, wallet
credit, job acceptance/completion or approval was fabricated. Full paid-job and
physical iPhone acceptance remain distinct checks.
