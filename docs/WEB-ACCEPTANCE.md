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

All **39** Firestore/Auth/Storage rules, service and payment-adapter tests passed on Firebase CLI 15.34.1 with Java 26. Coverage includes assigned-Captain location ownership/throttling, cancellation, disputed earnings, shared-merchant webhook isolation, provider-error redaction, refund retry/backoff, lost-response recovery and webhook/worker races. Customer, Captain and shared Firebase package analyses passed. All **4 Customer tests** passed for unpaid-booking recovery and verified refund-state copy; Customer analysis passed again after the refund UI change.

## Browser and release checks completed on 22 October

| Check | Observed result |
| --- | --- |
| Finish and private photo review | Finish changed both screens to awaiting review. Customer could select all four before/after angles and load the private images. |
| Approval and rating | Customer approval changed the order and ₹116 earning from awaiting approval to approved. Five-star rating saved once. |
| Refresh and new tab | Customer/Captain stayed signed in after refresh. A fresh Customer tab restored the local account after the emulator bootstrap fix. |
| Repeat booking | Existing vehicle, parking and note were retained. Corrected live copy to call Customer photos optional and removed an unconnected WhatsApp gate-pass promise and sample voice-note fallback. |
| Dismiss and retry | Closing actual Razorpay test checkout left one unpaid booking. Found and fixed its absence from both history tabs; Upcoming now shows Not paid and payment not confirmed. Refresh/reopen retried the same provider order and booking. |
| Failed/delayed payment recovery | The dummy-card attempt was cancelled after stalling at OTP. Alternate test netbanking later captured ₹149. Check payment status independently fetched and verified that capture despite the earlier failed browser callback. Provider showed one failed attempt and one captured payment. No duplicate booking was created. |
| Fresh paid assignment and cancellation | Captain accepted the newly captured booking; Customer changed live to on the way. Customer confirmation cancelled it, Captain lost wash controls and saw Stop work. The full original-method refund initially received Razorpay HTTP 400, BAD_REQUEST_ERROR, invalid request sent. After the recovery work below, that same full ₹149 refund processed successfully. |
| Prior captured payment refund | Independently fetched the actual 21 October ₹149 test capture, restored its booking only in the local replay, accepted/cancelled in the UI and verified the provider refund as processed. Firebase also showed processed, with Captain active-job count zero. |
| Dispute and earnings hold | Customer reported a problem on the disposable completed-wash replay. Customer changed to Problem under review, an open support ticket was stored, and Captain earnings changed from Approved to On hold without reload. No dispute outcome or bank transfer was invented. |
| Release | Both clean production Flutter web builds passed with emulator routing disabled. Hosting and the four changed payment/refund Functions deployed under ajay@trustkeyper.com; the shared-merchant webhook follow-up was also deployed. The required HTTP gateway configuration was reapplied. Hosted Customer and Captain loaded with no captured console errors; Captain name/mobile labels were visible, and Customer displayed TEST PAYMENTS. Both hosted bundles matched local release hashes. Availability returned 200 with six unavailable windows; all 17 protected operations rejected anonymous calls with 401. A correctly signed no-op webhook returned 200 and an invalid signature returned 401. No production QA records were created. |

Firestore/Storage rules and indexes were unchanged by these acceptance fixes. Firebase CLI remote OAuth handoff failed; standard local sign-in with `firebase login --reauth --interactive` restored the existing owner login and deployment succeeded.

## Refund recovery completed on 22 October

The connected Sumit Chrome profile opened the existing Paravent merchant used by Trustkeyper. Its existing test key matched WashKrew's configured key; no merchant credentials were replaced. The dashboard independently showed the ₹149 netbanking capture and its ₹3.52 fee. One explicitly labelled, disposable **₹100 virtual test payment** was captured in this same merchant, separate from any customer booking and never included in Hosting. Retrying the original full ₹149 refund with the unchanged receipt/idempotency key then succeeded. This sequence points to insufficient virtual test balance as the earlier rejection cause; Razorpay's generic error itself did not identify the cause. The dashboard's resulting current balance was ₹93.14.

Provider GET, merchant payment details and the Customer screen all confirmed the latest refund **processed**, reference `rfnd_TqxL1ppLE0N4XD`, amount **14900 paise**, receipt `wh_de5280e666430cda018f7bb039b5eb6c`. Captain active-job count was zero. The ₹100 virtual payment remains test balance, not a customer booking or real charge. Both the earlier card refund and the latest netbanking refund are now processed.

The backend now persists bounded provider diagnostics, schedules retries from five minutes up to one hour, recovers an already-created refund by receipt before retrying, and fences stale workers so they cannot overwrite a processed result. Customer distinguishes queued, sent, delayed, review and processed states. **Check refund status** fetched the existing pending refund and changed Customer to processed; repeated customer checks cannot initiate a refund POST or bypass its retry schedule. Failed/mismatched provider refunds remain due for operations review. No raw provider error, secret, lower refund amount or replacement idempotency key was used. The local scheduler is not emulated; its normal reconciliation service was invoked explicitly for the completed refund.

WashKrew's separate test webhook `TqxUD6pRECMQMK` is enabled for `payment.captured`, `order.paid` and `refund.processed`, preserving Trustkeyper's existing webhook. The handler independently fetches payment/refund data and acknowledges unrelated shared-merchant payments without creating WashKrew records. A signed replay referencing the separate virtual test payment returned 200, and its payment-order document remained absent in the hosted project before and after. The dashboard confirmed a secret was supplied and exactly those three events were selected. Live-mode webhook setup remains part of live cutover.

During earlier merchant identification, Razorpay's **View test API keys** control unexpectedly generated an unused test key in **Existing Account 1**, an unrelated merchant. Its secret was never copied, stored or connected to Wheelio. The UI exposed regeneration, not revocation; no other merchant key was regenerated to undo it. The owner was informed during testing.

Physical-device GPS permission/accuracy and live merchant cutover remain future checks. The location-stream acceptance used explicitly synthetic coordinates; the permission-timeout recovery was checked in the browser. Live keys/webhook registration, commercial review and actual reviewed live captains are still required before live operations. Bank payout execution and dispute/KYC decisions remain human operations. Native work stays deferred.

## Repeat locally

Use the existing emulator defines with the release builder and a separate output folder. Serve Customer and Captain on separate **localhost** ports so their Firebase sessions stay separate. FlutterFire's debug Auth emulator restoration expects `localhost`; using `127.0.0.1` as the browser origin can lose the emulator session on refresh. Emulator builds inject the guarded loopback Auth origin before Flutter initialization, because Auth restoration runs before initializeApp returns. Production builds do not include that injection.

`backend/firebase/emulator-fixtures.mjs` requires both fixed loopback emulator hosts and a hardcoded `demo-wheelio` project. `seed` starts an unapproved applicant; `approve` requires its submitted application. `seed-ready` creates an explicitly approved disposable fixture for booking-only replay, not a real KYC review. `prepare-wash BEFORE.png AFTER.png` replays the washing checkpoint with eight actual local Storage objects and a simulated provider capture. `location` and `location second` send labelled synthetic coordinates. `capture` is an optional simulated provider fallback and is not evidence that real Razorpay checkout passed. Never run fixtures against the hosted project.

Local emulator secret overrides use `.secret.local`, now ignored by Git. Do not commit keys or export Auth tokens into test reports. The final disposable QA state was exported locally, the local services stopped and the temporary secret override removed. Stop emulators after subsequent testing and remove temporary secret overrides.
