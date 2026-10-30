# Earlier real slot loading without paid warming - 30 October 2026

Ajay's agent owns this work. Aman is only preparing the Apple notification key;
see [the key-only prompt](AMAN-CLAUDE-APNS-KEY-ONLY-2026-10-30.md). Firebase APNs
configuration remains pending the real private key, and will be handled here.

## Behavior

Previously the Customer app first preloaded three days of availability when
leaving C10 parking. It now begins when both catalog and a real saved society
are available, or when a new society is selected, and when a new/repeat booking
starts. It prefers the actual draft society; a saved society is only considered
when it appears in the active catalog. It does not choose a parking place for
the user or query every society. With no known society it makes no speculative
availability requests. Repeated unrelated state updates do not restart preload.

The same three single-day calls are started earlier, using the existing API.
Preloading can overlap with navigation instead of making C12 start all work.
Opening the app can now start those normal requests even if the user does not
finish a booking. The usual request/read charges still apply; no idle-instance
baseline or periodic keep-alive has been added.

The shared request cache now:

- Deduplicates in-flight calls, including explicit refreshes and a slow pending
  request that has taken more than 45 seconds.
- Reuses completed results for 45 seconds; expired and failed results are removed.
  A fresh refresh replaces the completed result, and its failure cannot restore
  old capacity as bookable.
- Separates societies/dates and invalidates on account, live/test mode or relevant
  catalog changes. Old in-flight responses are rejected after invalidation;
  their failures cannot erase a replacement request.
- Discards pending cache state on store disposal. Background preload errors are
  consumed so the slot screen can make a genuine retry.

The C12 request-order key includes account/catalog context, so changing context
while a request is pending starts a new load and prevents the previous response
from winning. Existing visible-screen refresh and resume behavior remains.
Booking/payment/claim capacity validation is unchanged; a cache is not a booking
reservation and never bypasses the server.

## Design and service boundaries

Only the Customer store, a data-only cache and one request-key line in C12 change.
No authored widget/layout, text, styling, asset, camera/map implementation,
shared UI, native project or dependency is edited. Captain source is untouched.
No demo mode, test button, fixed OTP, fake availability or production fixture is
introduced. There is no new service or multi-day API contract. Paid warming stays
off; the earlier backend startup optimization remains deployed separately.

The new tests supply isolated request futures and profile-state fixtures. They
do not initialize Firebase, create production users or alter Captain approval,
payments, training or work-hour policy. They establish request ordering and
early initiation, not physical iPhone latency or real APNs/payment acceptance.

## Verified results

- All four Flutter analyses passed without issues.
- All **62 Flutter tests passed**: Customer 31, Captain 10, shared Firebase 21.
  Ten new cases cover request coalescing/expiry, forced refresh failure, context
  replacement, disposal, known/unknown societies, early initiation, genuine
  retry and the real C12 widget rejecting an old account's response.
- Both clean **release web builds passed**, including required plugin registry
  checks. The first focused attempt used stale generated dependency resolution
  from before Aman's camera package; refreshing with the committed lockfile
  resolved it. No dependency, app lockfile or camera implementation changed.
- Compared against Aman's `79d17af`: replacing just the new C12 context-key line
  with the old key reproduces the entire booking screen source exactly. All
  other Customer screens, Captain and shared packages remain unchanged. This
  is a source comparison, not a new 157-screen pixel-render audit.
- Published the verified default Firebase Hosting build successfully. Release
  version: `43cbe17ef39cd4e3`, 30 October 2026 at 10:49:22 UTC. Downloaded hosted
  Customer/Captain JavaScript and admin module each return 200 and match their
  local verified artifact's SHA-256. The separate washkrew.com website/site was
  not republished or reconfigured.
- Read-only deployed runtime check confirms `getAvailability` ACTIVE, min **0**,
  max **5**, 256 MiB. No Function, cloud billing setting, live payment policy,
  user, approval, booking, charge/refund, device token or push was modified by
  this client follow-up.

Safe artifact hashes, runtime/release metadata and counts are in
[checks.json](../output/client-availability-2026-10-30/checks.json).
Physical iPhone timing/build acceptance and real push delivery remain pending.
The new source must be rebuilt on the Mac for the installed apps to receive it;
publishing the web app does not update an already installed native binary.
