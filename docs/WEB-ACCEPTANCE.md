# Web acceptance — 21–22 October 2026

The release under test is Flutter Customer and Captain using Firebase controllers, not `?demo=true`. Native platform work is deferred. The deployed project remains in test-payment mode.

## Browser checks completed on 21 October

The owner confirmed real Customer SMS delivery and verification, then authorized saving the existing name. The hosted Profile page showed the saved name and Sign out.

Disposable Customer and Captain accounts were then used against `demo-wheelio` on local Firebase Auth, Firestore, Storage and Functions emulators. Razorpay's actual test credentials and documented dummy card were used for checkout. No real charge was made and no QA captain was added to the hosted project.

| Check | Observed result |
| --- | --- |
| Customer and Captain OTP sign-in | Both emulator accounts verified successfully. |
| Captain application uploads | Three private dummy documents uploaded; submission reached operator review. |
| Application recovery | Found and fixed lost upload indicators after refresh; all three restored without uploading again. |
| Capacity | No slots before Captain approval; available slots after local approval. |
| Booking and Razorpay | Customer submitted vehicle, optional photo, parking, notes and slot. Actual Razorpay test checkout completed; server verified capture at ₹149. |
| Assignment | Captain received a coarse expiring offer; acceptance unlocked exact parking and note. Customer updated automatically. |
| Location stream | Two explicitly synthetic Hyderabad points passed through the location service and appeared on Customer without reload; stale coordinates were labelled last known. |
| Location permission recovery | An unanswered browser permission request originally blocked Captain controls. After the fix, a clear timeout appeared and washing remained usable. Physical device GPS permission was not granted in this test. |
| Arrival and washing | Customer showed arrival, then washing from server snapshots. Start stayed disabled until four before photos existed. |
| Wash evidence | Four before and four distinct after dummy photos uploaded and registered. Server state contained eight evidence entries. |

The local test services stopped overnight before Finish/approval/earnings acceptance. Remaining browser checks are being replayed on 22 October; do not infer these are accepted from the earlier upload checks.

## Automated checks on 22 October

All **30** Firestore/Auth/Storage rules and service tests passed on Firebase CLI 15.34.1 with Java 26. New regression cases cover active assigned-Captain location ownership and throttling, cancellation after assignment, and disputed earnings. Customer, Captain and shared Firebase package analyses passed.

## Remaining checks

- Finish wash, customer photo comparison, approval/rating and Captain earnings in the browser.
- Checkout dismissal/retry and provider refund acceptance in test mode.
- Final release builds, Hosting deployment and hosted smoke checks for the fixes.

Merchant live keys/webhook registration, commercial review and actual reviewed live captains remain separate live-launch requirements. Bank payout execution and dispute/KYC decisions remain human operations.

## Repeat locally

Use the existing emulator defines with the release builder and a separate output folder. Serve Customer and Captain on separate **localhost** ports so their Firebase sessions stay separate. FlutterFire's debug Auth emulator restoration expects `localhost`; using `127.0.0.1` as the browser origin can lose the emulator session on refresh.

`backend/firebase/emulator-fixtures.mjs` requires both fixed loopback emulator hosts and a hardcoded `demo-wheelio` project. `seed` starts an unapproved applicant; `approve` requires its submitted application. `seed-ready` creates an explicitly approved disposable fixture for booking-only replay, not a real KYC review. `location` and `location second` send labelled synthetic coordinates. `capture` is an optional simulated provider fallback and is not evidence that real Razorpay checkout passed. Never run fixtures against the hosted project.

Local emulator secret overrides use `.secret.local`, now ignored by Git. Do not commit keys or export Auth tokens into test reports. Stop emulators after testing and remove temporary secret overrides.
