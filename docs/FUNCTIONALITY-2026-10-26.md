# Functionality handoff — 26 October 2026

The subsequent [27 October software handoff](READINESS-2026-10-27.md) records Maps/Routes, training/quiz/speech, actual private image checks, final verification and the current Mac/content/provider gates. Use it with this baseline record.

Baseline: staging `c1ad2b2`, including the Customer/Captain design restorations and Mac-resolved native changes. The remote was fetched again on 26 October with no newer commits. All application work is in Flutter. Layout, palette, typography, navigation chrome and assets follow staging; no generic replacement screen or payment banner was restored. Dynamic text and existing controls now reflect actual data.

## Connected functionality

| Area | Behavior |
| --- | --- |
| Accounts | Same-UID phone changes through Firebase verification; recent verification for approved Captain payout changes; private persisted profile photos. Customer deletion checks recent login/open work, removes private account material and blocks cached-token writes with a tombstone. |
| Booking | Private saved parking places reuse the existing address screen. Selected UPI/card instruments reach checkout while retaining the server order/amount/verifier. |
| Wash | Existing atomic assignment and four-photo gates retained. Actual private Customer audio/video plays in existing players. Captain must finish the note once. Cancelled camera capture stops navigation; job-scoped evidence restores after reopening. |
| Vehicle help | Captain's request reaches the Customer's existing three answers. “Not here” invokes the actual cancellation policy. Arrival never counts as a received gate pass. |
| Tracking/deadlines | Optional foreground GPS through the existing directions control; background sharing stops. Configured coordinates/boundaries drive matching and radius filters. Server slot-over checks, unassigned expiry, midnight no-show cancellation and review-deadline approval. No simulated GPS or driving ETA. |
| Approval/refunds | Failed approval/report/rating stays on the form. Rating tags persist. Finish/report callbacks can retry safely. Refund status reflects the provider and the original payment method; an unaccepted refund is not described as with the bank. |
| Reports | Three private problem photos, priority damage review, held earnings and private Captain voice response. Human decisions can uphold/reject, restore entitlements once, queue actual cash refunds and grant an explicit bonus. |
| Downloads | Owner-scoped receipt PDF/evidence ZIP with ten-minute single-use URLs. Only permitted files for that order and stored events are included; no invented call log. |
| Money | Actual earnings, held jobs and recorded transfers fill the existing screens. Operator recording requires an explicit verified reference and approved unpaid earning IDs; it initiates no transfer. Bank/UPI details await human verification. |
| Inbox | Per-role read/unread/delete, mute/categories/quiet hours/sound persist. Private push respects settings; existing app routes and foreground banners handle updates. |
| Work | Server time/area/radius filters cannot expand approved societies. Draft preferences do not permit going online. Explicit configured daily limits are enforced. No commercial penalty or level progression is invented. |

`backend/firebase/operator.cjs` uses the existing owner Firebase CLI login and Google IAM. `check-access` is read-only. `resolve-dispute FILE.json` and `record-payout FILE.json` prepare an action; `--confirm` applies the human decision. Keep private case inputs in ignored `.cache/`, never Git. See `design.test.mjs` for input fields. Refund execution stays with the existing provider worker.

## Verification

- 77 backend/rules/payment/refund/geography/document/notification tests passed in isolated `demo-wheelio` emulators, including deletion, ownership and retry checks. A final focused deletion test also passed after extending cleanup to unused download links/support throttle state and anonymizing retained payout records.
- 8 Customer recovery/policy tests and 14 shared phone-login/checkout tests passed: 99 automated tests in total. All four final analyzers are clean. The iOS preparation tool's portable configuration, argument and dependency checks also passed; they are not an Xcode build.
- Disposable local Customer and Captain accounts both signed in and showed the same assigned booking. Vehicle help reached the Customer's answer screen and the answer was saved.
- Authenticated Functions/Storage HTTP checks exercised arrival, four private before uploads, start, four private after uploads and finish. The Customer photo-review screen updated. The receipt endpoint returned a valid PDF; reusing its URL returned 403. The PDF was rendered and visually inspected.
- An invalid tiny PNG in the local fixture was replaced with explicitly synthetic valid evidence. Decode failures now show a normal retry message.
- No production QA Captain, fixed OTP, real payment, payout transfer or live-mode change was created. Actual Razorpay test-payment/refund acceptance from 21–22 October is separately recorded in [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md); this pass's offline local payment fixture is not a new merchant acceptance claim.

## Pending inputs and acceptance

The owner explicitly deferred DigiLocker, WhatsApp Business, masked calling, approved training videos, legal pages and the support number. Existing controls remain guarded. Training's six-second stand-in runs only in demo mode; submission is not proof of training.

Other unfinished P0 items remain in [P0-BACKEND-FOR-DESIGN.md](P0-BACKEND-FOR-DESIGN.md): Google Maps/driving ETA and verified society geofences; voice-call OTP; photo-library/live-location design decisions; face comparison and approved image-quality/AI decisions; confirmed intro-call availability; approved level/probation/penalty/trip-fee policies. Intro rescheduling creates a real operations request without promising an unconfirmed time. Filters fail clearly without actual coordinates.

Live merchant approval, commercial review and approved live Captains remain gates in [LIVE-LAUNCH.md](LIVE-LAUNCH.md). Windows checks do not prove Xcode compilation, physical camera permissions, UPI switching, real GPS or APNs. Use [MAC-HANDOFF.md](MAC-HANDOFF.md) on the owner's Mac.

## Release status

Published Customer `/app/`, Captain `/captain/`, Functions and Storage rules to `wheelio-apps` on 26 October after refreshing the existing owner login. Firestore rules/indexes were also checked/deployed. All twelve new functions are ACTIVE. The first Functions deployment reported invoker-IAM errors under the existing domain restriction; the repository's `configure-api-access` gateway operation completed successfully without changing that organization policy, and Hosting/Storage release then completed separately.

Post-release checks verified all 35 protected callables return Firebase UNAUTHENTICATED responses, the document endpoint rejects an invalid token, and both merchant webhooks reject invalid signatures. Both hosted JavaScript hashes match the checked local release artifacts. Customer catalog and Captain startup render without console warnings/errors. Native project files, design assets and color tokens have no changes in this pass. Payment mode remains **test**. This is not a completed live launch.
