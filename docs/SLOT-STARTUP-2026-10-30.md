# Slot startup without paid idle instances - 30 October 2026

The owner chose to pursue lower waiting time without enabling the proposed
roughly US$9/month idle-instance baseline. `interactiveWarmMinimum` remains **0**;
normal request/database/storage/SMS usage is still metered. No keep-alive timer,
new service, sample availability or production fixture is introduced.

## Change

The Functions entry point previously loaded `pdf-lib`, `yazl` and their module
trees for every cold invocation, including `getAvailability`, which does not
generate documents. The PDF module is now imported only after a booking document
download token is validated, and ZIP is loaded only for an evidence archive.
Node reuses these imports on later document requests. Existing receipt contents,
private evidence paths and one-time-token authorization remain unchanged.

This follows [Firebase's dependency-loading guidance](https://firebase.google.com/docs/functions/tips#use_dependencies_wisely).
The change removes avoidable initialization; it cannot eliminate on-demand
container startup, network or Firestore latency. No screen or Flutter/iOS source
was changed, including Aman's new camera/map and background-save work.

## Measurement

Seven alternating fresh Node 24 processes per source on this Windows machine
compared the prior committed source `29ff518` with the new entry point:

| Local module initialization | Before | After |
| --- | ---: | ---: |
| Median import time | 723 ms | 595 ms |
| Median resident memory | 113.3 MiB | 105.7 MiB |
| Loaded PDF/ZIP module files | 138 | 0 |

Raw samples and method are in
[module-benchmark.json](../output/slot-startup-2026-10-30/module-benchmark.json).
These are module-initialization measurements, **not** Cloud cold-start timings,
first-real-slot timings or iPhone acceptance. No artificial delay or timing
threshold was added to production/tests.

## Verification and deployment

- All **129 backend/rules tests passed**, with zero failures/skips, against
  demo-wheelio Auth/Firestore/Storage emulators. The new isolated startup check
  verifies that availability/discovery load no PDF/ZIP codec, then generates a
  real PDF and ZIP using the deferred modules. Existing document authorization,
  payment/refund, human review and work-hour tests continue to pass.
- Node syntax validation passed. No dependency or lockfile changed.
- `apps/flutter` remains byte-for-byte identical to Aman's `79d17af` tree
  `22b670f27d9bb85384c371583263b878b7e91603`. No native build/device result is claimed.
- Published only `getAvailability` in the existing asia-south1 codebase. Other
  endpoint implementations and Hosting/native binaries were not republished.
- Reapplied the documented `operations.cjs configure-api-access` gateway step.
  Read-back confirms availability is ACTIVE with min 0 / max 5 / 256 MiB, and
  the other three checked runtimes also retain min 0. Public availability returns
  200 with all nine 4 AM-10 PM windows; six protected operations reject anonymous
  requests with 401. Event-trigger IAM protection, separate WashKrew LIVE merchant,
  no-credit-card-checkout and hidden/nonrequired training remain unchanged. No
  production user, approval, booking, charge/refund, token or push was created.
  Safe results: [checks.json](../output/slot-startup-2026-10-30/checks.json).
- Added `.p8`/`.p12` ignore patterns to help prevent accidental private-key
  staging. This does not replace keeping the actual key outside the repository
  and checking the staged diff. No key file was added or requested in Git.

## Client and Mac handoff

Aman's client already has a 45-second in-memory request/result cache and starts
the next three days' prefetch after C10 parking. Earlier preload for a known
saved/selected society can overlap real work with navigation without changing
the design. Actual account/context invalidation, retry/resume behavior and
device timings must be measured before claiming the desired user experience.
Do not prefetch all societies or rely on stale capacity for payment/assignment.

[AMAN-CLAUDE-SLOTS-AND-PUSH-2026-10-30.md](AMAN-CLAUDE-SLOTS-AND-PUSH-2026-10-30.md)
contains the forwardable Mac task. It also clarifies that the APNs `.p8` stays
private and outside Git. Aman configures Firebase from his Mac, then commits
only tested source changes and a secret-free result/configuration note.
