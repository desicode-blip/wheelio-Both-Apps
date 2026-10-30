# Backend follow-up to Aman's 29-30 October report

Later owner decision: keep idle warming off and pursue measured startup/preload
improvements. See [SLOT-STARTUP-2026-10-30.md](SLOT-STARTUP-2026-10-30.md) and the
Mac prompt linked there. The cost-choice references below record the earlier
report state; they are superseded by that decision.

Pulled staging **79d17af** by fast-forward with a clean working tree. Read
`CHANGES-2026-10-30-UI.md` and checked its items against the actual Flutter and
server code. Aman's UI, guided camera, map controls, background-save handlers,
native projects, paid team and lockfiles are preserved. No Flutter/iOS file is
changed by this follow-up. The complete `apps/flutter` tree remains
`22b670f27d9bb85384c371583263b878b7e91603`, identical to Aman's commit.

## Report items

| Item | Actual status |
| --- | --- |
| Exact Captain hours and breaks | Already implemented on 27 October, before Aman's new UI work. Current `liveSaveWorkPreferences` sends minute-based `workingSlots`; server validates, normalizes and persists them. Availability, capture, dispatch and claim use those exact periods. Legacy four-hour windows are compatibility data only. The new regression tests verify a saved break removes capacity and a work-hour edit invalidates an incompatible outstanding offer. No UI or matching-policy replacement was needed. |
| iPhone notifications / APNs key | Both registered Firebase iOS apps are ACTIVE and Aman's native push entitlements remain intact. No `.p8` key was found in Downloads/Documents; owner will ask Aman. Actual credential upload and physical delivery remain pending the correct paid-team key/Key ID. See the dedicated key request below. No key was fabricated, Apple account changed or real push sent as a test. |
| Cold starts | The optional runtime policy can reserve one instance each for getAvailability, saveCustomerPlace and setCaptainPreferences. The owner will ask Aman about the recurring cost. **The source default remains zero**, so pulling or deploying it does not add idle charges. All other controllers stay on demand; CPU/memory/max-instance caps are unchanged. Emulator policy always reserves zero. |
| Company App Store seller | Apple business/account enrollment remains Aman's responsibility. No Firebase code can change an Individual seller into the legal company. No legal entity or enrollment information was invented. |
| Other UI changes | Existing location matching and private photo/media endpoints remain compatible. No new backend endpoint/provider or client UI change was required for camera/map/background-save changes. |

## Backend correction

FCM may resolve a multicast call even when individual device deliveries failed.
The previous handler only removed expired tokens and missed per-device APNs
authentication failures. The handler now explicitly counts actual successes and
failures, logs bounded error-code counts and flags credential/configuration
errors. Only invalid/expired registration tokens are removed. Transient errors
and configuration failures do not erase still-valid device registrations; the
private inbox remains the durable source. Provider messages, tokens and private
booking details never enter these diagnostics.

The existing trigger retry policy for thrown transport errors is unchanged.
This change adds visibility, not a new per-device retry queue or a guarantee of
exactly-once push delivery. It does not turn a queued/failed push into a success.

## Verification

- **128 backend/rules tests passed**, zero failures/skips, with only the local
  demo-wheelio Auth/Firestore/Storage emulators. Seven additions cover the
  limited runtime policy, safe push-failure diagnostics and real service-level
  work-hour/break behavior. No production fixture or fixed OTP was seeded.
- Existing phone registration, uploads/admin authorization, eligibility,
  booking/payment/refund isolation, assignment conflicts, private identity and
  photo gates, wash approval/earnings, notifications and deletion tests passed.
- Node syntax check and actual Functions export discovery passed. With warming
  explicitly enabled, only the three selected callables can reserve one instance;
  **the current source and deployed minimum remain zero**. Max stays 5, 256 MiB,
  fractional gcf_gen1 CPU and concurrency 1. Photo checks retain 512 MiB / 120
  seconds / min 0. Invalid reservation values fail validation.
- Read-only owner check found the existing `(default)` database is STANDARD,
  FIRESTORE_NATIVE, asia-south1. No database was created or migrated.
- Read the previously deployed preference function's source without changing any
  production document. Its exact-minute save method matches the current method;
  deployed `booking-policy.mjs` matches byte-for-byte. Other methods in that older
  archive differed, so no whole-service-file equality is claimed. The final
  selected function deployment packages the current tested source.
- All application/native sources are unchanged from Aman's staging tree. These
  backend checks are not a new Xcode, physical camera/GPS/APNs or live charge /
  refund acceptance result. No Hosting/website/native binary was published.

## Publication

Published `getAvailability`, `setCaptainPreferences`, `saveCustomerPlace` and
`sendInboxPush` successfully to the existing asia-south1 Functions codebase.
The optional warming attempt first stopped at Firebase's minimum-bill guard;
after the owner said they would ask Aman, the source default was explicitly kept
at **zero** and the final deployment required no force/billing override.
Reapplied the documented `operations.cjs configure-api-access` step, then verified:

- All four selected functions are ACTIVE with min **0**, max **5**, 256 MiB.
- The three callable HTTP gateways are configured as intended; the Firestore
  event service still requires its IAM-authenticated trigger.
- Anonymous preference/place writes, job claims, admin review, wash approval
  and push-token registration return **401**.
- The public coarse availability endpoint returns **200**, with all nine
  windows from **4 AM to 10 PM**.
- Configuration remains LIVE / separate WashKrew merchant /
  no-credit-card-checkout; training enabled/required remain false, and private
  photo checks remain enabled for test/live. No launch policy was changed.

Safe read-back evidence is in
[checks.json](../output/backend-followup-2026-10-30/checks.json). The final full
emulator rerun passed all 128 tests after explicitly keeping the idle-cost flag
off. Cloud organization policy, Firebase authentication, reviewer checks and
event-service IAM protection remain in place. No real account, booking, approval,
charge/refund, device token or push notification was created for these checks.

## What is still needed from Aman

[AMAN-APPLE-PUSH-KEY-REQUEST-2026-10-30.md](AMAN-APPLE-PUSH-KEY-REQUEST-2026-10-30.md)
contains a forwardable message and exact key/team/app/environment details. The
owner said they will ask Aman. No Apple password is requested. Keep the key out
of Git/public chat; only genuine private key possession/configuration and later
iPhone delivery can close the APNs acceptance gate.

For the optional warming choice, Firebase documents an approximate baseline of
$3/month per 256 MiB fractional-CPU minimum instance (roughly $9/month for these
three), with regional/usage differences. Its deployment guard requested an
explicit decision. See [Firebase's scaling and billing guidance](https://firebase.google.com/docs/functions/manage-functions?gen=2nd#keep_a_minimum_number_of_instances_warm).
