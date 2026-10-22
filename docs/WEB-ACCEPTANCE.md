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

The local services stopped overnight after the eight uploads. On 22 October, a guarded fixture replayed that washing checkpoint through the service controllers with disposable photo objects and a simulated capture. Finish, photo review, approval, rating and earnings were then exercised through the real Flutter UI. That checkpoint is not evidence of a second provider checkout.

## Automated checks on 22 October

All **30** Firestore/Auth/Storage rules and service tests passed on Firebase CLI 15.34.1 with Java 26. New regression cases cover active assigned-Captain location ownership and throttling, cancellation after assignment, and disputed earnings. Customer, Captain and shared Firebase package analyses passed. A Customer regression test also passed for keeping unpaid and unconfirmed bookings visible without treating them as active washes.

## Browser and release checks completed on 22 October

| Check | Observed result |
| --- | --- |
| Finish and private photo review | Finish changed both screens to awaiting review. Customer could select all four before/after angles and load the private images. |
| Approval and rating | Customer approval changed the order and ₹116 earning from awaiting approval to approved. Five-star rating saved once. |
| Refresh and new tab | Customer/Captain stayed signed in after refresh. A fresh Customer tab restored the local account after the emulator bootstrap fix. |
| Repeat booking | Existing vehicle, parking and note were retained. Corrected live copy to call Customer photos optional and removed an unconnected WhatsApp gate-pass promise and sample voice-note fallback. |
| Dismiss and retry | Closing actual Razorpay test checkout left one unpaid booking. Found and fixed its absence from both history tabs; Upcoming now shows Not paid and payment not confirmed. Refresh/reopen retried the same provider order and booking. |
| Failed/delayed payment recovery | The dummy-card attempt was cancelled after stalling at OTP. Alternate test netbanking later captured ₹149. Check payment status independently fetched and verified that capture despite the earlier failed browser callback. Provider showed one failed attempt and one captured payment. No duplicate booking was created. |
| Fresh paid assignment and cancellation | Captain accepted the newly captured booking; Customer changed live to on the way. Customer confirmation cancelled it, Captain lost wash controls and saw Stop work, and the refund trigger attempted the full original-method refund. Razorpay rejected this latest test-netbanking refund with HTTP 400, BAD_REQUEST_ERROR, invalid request sent. The refund record remains retry and Customer honestly shows queued; it is not accepted as refunded. |
| Prior captured payment refund | Independently fetched the actual 21 October ₹149 test capture, restored its booking only in the local replay, accepted/cancelled in the UI and verified the provider refund as processed. Firebase also showed processed, with Captain active-job count zero. |
| Release | Both clean production Flutter web builds passed with emulator routing disabled. Hosting-only deployment succeeded under ajay@trustkeyper.com. Hosted Customer and Captain loaded the existing screens; empty Captain fields had visible labels, and Customer displayed the persistent TEST PAYMENTS strip. The hosted bundles matched the local release hashes, and public availability returned 200 with six unavailable windows (no approved hosted captains). No production QA records were created. |

The Functions, rules and indexes were unchanged by these acceptance fixes, so the 22 October release only deployed Hosting. The existing 21 October backend/gateway checks still apply. Firebase CLI remote OAuth handoff failed; standard local sign-in with `firebase login --reauth --interactive` restored the existing owner login and deployment succeeded.

The latest netbanking test refund needs merchant-side review before live cutover. The provider confirms capture and zero refunded, and rejected the same full-amount idempotent request on retry. The earlier card test refund processed successfully. The request follows the documented refund contract; no conclusion about merchant balance is confirmed without dashboard access. Do not reduce the customer refund or change the idempotency key to bypass this rejection. The local scheduler is not emulated; its normal reconciliation service was invoked explicitly for the completed refund.

Physical-device GPS permission/accuracy and live merchant cutover remain future checks. The location-stream acceptance used explicitly synthetic coordinates; the permission-timeout recovery was checked in the browser. Live keys/webhook registration, commercial review and actual reviewed live captains are still required before live operations. Bank payout execution and dispute/KYC decisions remain human operations. Native work stays deferred.

## Repeat locally

Use the existing emulator defines with the release builder and a separate output folder. Serve Customer and Captain on separate **localhost** ports so their Firebase sessions stay separate. FlutterFire's debug Auth emulator restoration expects `localhost`; using `127.0.0.1` as the browser origin can lose the emulator session on refresh. Emulator builds inject the guarded loopback Auth origin before Flutter initialization, because Auth restoration runs before initializeApp returns. Production builds do not include that injection.

`backend/firebase/emulator-fixtures.mjs` requires both fixed loopback emulator hosts and a hardcoded `demo-wheelio` project. `seed` starts an unapproved applicant; `approve` requires its submitted application. `seed-ready` creates an explicitly approved disposable fixture for booking-only replay, not a real KYC review. `prepare-wash BEFORE.png AFTER.png` replays the washing checkpoint with eight actual local Storage objects and a simulated provider capture. `location` and `location second` send labelled synthetic coordinates. `capture` is an optional simulated provider fallback and is not evidence that real Razorpay checkout passed. Never run fixtures against the hosted project.

Local emulator secret overrides use `.secret.local`, now ignored by Git. Do not commit keys or export Auth tokens into test reports. Stop emulators after testing and remove temporary secret overrides.
