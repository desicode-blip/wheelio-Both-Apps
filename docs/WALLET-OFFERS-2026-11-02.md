# Wallet top-ups and immediate Captain offers — 2 November 2026

The owner reported a completed live payment followed by a delayed Captain alert
and a misleading **Job went to someone else** state. The owner also explicitly
authorized a Home wallet entry, balance/top-up screen, and wallet/Razorpay payment
choices. These are scoped UI exceptions; existing unrelated af036f0 designs stay.

## Reported behavior and correction

A read-only inspection of the dedicated Customer's latest booking found a captured
payment, cancellation and **no assigned Captain**. Its offer was withdrawn. Offer
documents are renewed in place, so their latest creation time does not establish
the first-alert latency. The app independently used the authored Job missed title
after timeout, which incorrectly implied another Captain accepted.

- Payment settlement now reads eligible Captains and commits their coarse offers
  in the **same transaction** as the captured booking and capacity reservation.
  It does not wait for another cold dispatch trigger, a five-minute scheduler,
  or a 60-second heartbeat. Existing Firestore listeners receive the new offers.
- All eligible online, approved Captains whose area, mode and
  entire saved work period match can receive the offer. Captains already holding
  overlapping capacity cannot be promised another job. Exact parking, plate,
  Customer identity and media remain private until a Captain wins assignment.
- The claim transaction rechecks eligibility and capacity, writes one Captain,
  and marks other offers withdrawn with the actual assigned reason. Retry by
  the same winning Captain is idempotent and does not increment active jobs twice.
- Captain root tabs react to incoming offers immediately, rather than depending
  only on the Home view's logic. Existing live alerts update renewed expiry times.
  Expired, cancelled and actually taken offers have distinct truthful copy in the
  existing missed-state layout. No timeout invents an assignment.
- Offer and Captain-profile snapshots may arrive in either order. The client now
  caches offer records independently and re-evaluates them when the profile's
  payment mode arrives. It no longer drops an initial live offer while temporarily
  assuming test mode. Two focused delivery-order/renewal tests and all three
  outcome widget cases passed; Captain static analysis remains clean.
- No extra paid warm instance is enabled. Network, payment provider and Firebase
  startup still exist; no absolute zero-latency guarantee is made.

## Wallet and top-up contract

- Home shows the current wallet balance beside Notifications, opening **Your
  wallet**. Existing design components/tokens are used. Balance remains the
  authenticated, mode-separated server `wallets/{uid}_{test|live}` snapshot.
- Review offers **Pay by wallet** or **Pay via Razorpay**. Wallet must cover the
  entire wash price; insufficient funds open the top-up screen with the shortfall
  (minimum provider charge ₹1). Gateway choice pays the full price without silently
  using wallet credit. Existing free-wash booking remains available. After checkout
  login the user returns to Review to make this explicit payment choice.
- Top-ups accept integer paise, ₹1–₹10,000 per request (technical request guard),
  through the existing separate WashKrew merchant and existing native/web Razorpay
  checkout. All allowed non-credit methods remain available. Credit equals its
  INR amount, for WashKrew washes only, with no transfer/withdrawal action.
- `createWalletTopup` prepares an idempotent server record/provider order.
  `verifyWalletTopup` verifies the signature and fetches payment; `checkWalletTopup`
  reconciles lost/dismissed callbacks. Existing signed webhooks and scheduler also
  reconcile top-ups. The **captured provider record**, amount, currency, merchant,
  mode, ownership and funding policy must match before atomic balance credit.
- Replayed callbacks/webhooks cannot double credit. Unpaid/dismissed/failed SDK
  results do not add credit. Only one unexpired pending top-up is created per
  Customer. The wallet shows recent top-ups with check/continue controls so an
  interrupted payment can resume with its original provider order.
- Top-up records are separate from wash bookings and never dispatch Captains.
  Historical booking/refund records keep their original provider/mode. Prohibited
  card/borrowing funding receives no spendable credit and uses the existing
  idempotent source-refund operations. Captures after Customer role deletion are
  also returned to source rather than issuing credit to a removed account.
  Account deletion is blocked while a top-up is pending or previously funded live
  credit remains, so purchased credit is not silently discarded. Existing Captain
  role deletion remains independent of Customer wallet access.
- Existing new-booking cancellation rules are unchanged: full/half/zero wallet
  credit by the saved five-minute/two-hour policy; service failure is full credit.
  Used wallet value is not restored twice.

No private key, phone number, UID, precise location, KYC or raw payment payload
belongs in this report or Git. Test payment captures use only the isolated
`demo-wheelio` project and fake provider. Live UI tests must not click a final
financial confirmation or spend the user's credit without a deliberate user action.

## Release / acceptance record

Customer **1.0.1 (2)** from `ebd79f9` was uploaded and published to its existing
internal track on 2 November at **12:48 IST**. The connected phone updated from
Play at **13:02:27 IST**, preserving login and matching the registered Play signing
certificate. The owner subsequently completed a booking and payment himself;
the agent did not submit that charge. Post-fix end-to-end timing was not measured
because the owner was operating the phone during that attempt.

This later wallet/offer update targets Customer **1.0.2 (3)** and Captain **1.0.1
(2)**. Automated checks, publication and native results will be recorded below.

### Local verification

- Full Auth/Firestore/Storage emulator suite: **188 passed, 0 failed**. This
  includes atomic fan-out to two area Captains without societies, concurrent
  first-acceptance wins, idempotent winning claim, expiry without assignment,
  renewal, full-wallet/insufficient-wallet choices, verified top-ups, duplicated
  callback/webhook races, lost-callback reconciliation, blocked funding, source
  refunds and Customer deletion safeguards.
- Customer: **72 tests passed**. Captain: **22 passed**, including truthful
  expired/cancelled/taken screens. Shared Firebase: **33 passed**. Customer,
  Captain and shared Firebase static analysis passed.
- Final wallet screen and checkout controls were rendered at phone widths using
  actual shared fonts/components. The local render fixture initializes no Firebase
  or real payment SDK. Additional final widget checks passed; raw images stay in
  ignored `.cache/wallet-offers-ui/`.
- Deployment preflight found the existing 62 ACTIVE functions plus exactly the
  three authorized top-up callables, with **no function deletion** proposed. It
  recorded hashes of all six affected shared backend modules for deployed-source
  comparison. No application identifiers, signing key or minimum instances changed.

### Published backend and web

All **65 Functions** are ACTIVE. Their exact deployed source generations match
all six release modules. The documented gateway configuration verified all **58
HTTP controllers**; the seven non-HTTP Functions retain IAM checks. Anonymous
booking, Online, admin and all three wallet calls reject access with **401**.
The first CLI deployment reported invoker-IAM errors for the three new callables;
their source deployment succeeded, and the documented gateway configuration then
completed successfully. Organization policy was preserved. Minimum instances
remain **0**, maximum **5**.

Firestore rules and the Customer/recent-top-up index are deployed; the index is
READY. Both release web builds are published on default Hosting and all four
Customer/Captain JavaScript/bootstrap artifacts match their local builds. The
separate washkrew.com marketing Hosting site was not changed.

### Play and connected Android — 2 November

The upload-signed bundles from `844c77c` were published only to the existing
WashKrew internal tracks:

| App | Version | Play release time (IST) | Device update time (IST) |
| --- | --- | --- | --- |
| Customer | **1.0.2 (3)** | **14:15** | **14:27:13** |
| Captain | **1.0.1 (2)** | **14:21** | **18:17:50** |

Both Play pages report **Available to internal testers**. Android package
read-back confirms `com.android.vending`, target SDK 36 and those exact versions.
Both installed base APK signatures passed verification and match the respective
Play deployment certificate recorded in `PLAY-INTERNAL-2026-11-01.md`. App data,
login and Captain approval/coverage were preserved. Captain reopened Online with
the existing 10 km work area and no society selection. No TrustKeyper app,
release, signing or tester setup changed.

Native Customer checks observed the top-right Home wallet button, current balance,
wallet amount field and recent-top-up state. A **₹1** top-up opened live Razorpay
within a **5.6-second observation window** after the tap; this is an upper bound
from manual observations, not a general timing guarantee. Checkout showed UPI,
debit cards, netbanking and wallets, with no credit-card, EMI or pay-later group.
Its UPI subpage showed multiple installed apps and an Others choice.

The owner completed that **₹1 payment himself on the phone**. Read-only backend
inspection verified a captured 100-paise payment, 100 paise credited, its matching
single top-up payment record, and a 100-paise wallet balance. Home updated to ₹1;
the wallet screen also showed ₹1 and **Added to wallet**. The agent did not enter
a UPI PIN, submit the financial confirmation or fabricate credit.

The existing booking flow reached Check and pay with separate **Pay by wallet**
and **Pay via Razorpay** actions. Further shortfall/retry and live offer checks
are being recorded; a new paid wash and a physical first-acceptance race have not
yet been established by this native session. Two-Captain fan-out, first-winner
atomicity and timeout/cancellation messages are covered by the isolated tests
above. Windows checks do not establish Xcode or physical iPhone acceptance.

### Owner's continued native check and additional corrections

The owner continued operating the phone during the shortfall check. He completed
the **₹148** shortfall top-up and then booked the **₹149** wash using the wallet.
Read-only inspection verified both captured top-ups, exactly **14,900 paise**
credited in total, and then the actual captured wash assigned to his approved
Captain. These financial actions and acceptance were performed by the owner.

The new booking exposed a remaining background case: the online Captain's stale
foreground heartbeat excluded him at settlement, and the next heartbeat produced
the offer about **71.6 seconds** after confirmation. He accepted it about five
seconds after that offer was created. This is a measured remaining defect, not
evidence that the first release removed every source of delay.

The follow-up preserves the designs and corrects three behavior paths:

- An explicitly Online, approved Captain still receives coarse offers while the
  OS pauses background Dart timers. Authenticated Accept rechecks approval,
  Online, area, mode, work hours, offer expiry and capacity, and records presence
  atomically instead of requiring another heartbeat first. First-winner atomicity
  and privacy remain unchanged.
- Captain startup/resume refreshes presence immediately. Repeated profile echoes
  do not cause request loops; concurrent resume/timer refreshes share a request;
  failed refreshes retry on the next signal and account switches clear state.
- Accept shows the existing loading state on the first tap and blocks duplicate
  Accept/Reject actions until the result. Successful live acceptance goes Home
  without the artificial 400 ms wait. It never displays success before the server.

The owner's selfie attempts were actually reaching the private comparison service
and returning `retake`; the approved reference existed and passed basic quality.
A private in-memory diagnostic found no face at 960–1600 px detection resolution,
but one usable face at 320/640 px. No raw selfie or embedding was saved in Git or
written to diagnostic logs. YuNet now detects at at most **640 px** and maps its
landmarks back to the original image for SFace alignment. Confidence, the original
80 px minimum face size, single-face requirement and match threshold are unchanged.
Five local model tests, including real public matching/different-person fixtures
and a high-resolution capture, passed. This is not a KYC or job verification
override; the current real selfie still requires a fresh server result.

This follow-up targets Captain **1.0.2 (3)**; its final deployment, Play and device
results will be appended after verification. Customer remains **1.0.2 (3)**.

### Native selfie passed; photo capture / submission follow-up

After the private photo-service correction, the owner took a fresh selfie and
reported **Before photos opened**. Read-only server inspection confirmed
`identityStatus: verified`. It was the fifth actual attempt; no rate-limit reset,
human-review override, fake photo or manual verification write was used.
All **189 backend tests**, **26 Captain tests**, five model tests and deployed
private model/thumbnail checks passed for the preceding correction. Its 65-Function
deployment succeeded, followed by the documented HTTP gateway configuration.

The owner then completed four Before and four After captures himself. The stored
photo review was `checked`, completing in about **27.5 seconds**, but the wash
remained `washing`: server photo analysis alone is not submission to the Customer.
The owner reported slow shutter/upload transitions and an unavailable message.
That message's exact network cause is not established by the successful server
review record. The previous Check photos control lacked a pending state and could
send repeated requests while that review was still running.

The additional correction keeps the authored screens and controls:

- Guided capture keeps one camera open between the four sides. A real captured,
  locally quality-checked frame advances the next side without waiting on upload.
  Uploads run independently, scoped to account, job, stage and side. Existing
  uploading/done/failed photo-slot states show their actual result; a failed upload
  retains the capture and can retry without fabricating server evidence.
- Next/Check photos wait for all relevant uploads and server registration. Failed
  uploads cannot start or finish a wash. Server quality, assignment, stage,
  generation and private-access validation remain authoritative.
- Check photos and Send anyway show pending feedback and prevent duplicate taps.
  Lost review callbacks reconcile the current server evidence fingerprint using
  the same authenticated callable's read-only status mode, without running AI a
  second time or interpreting `checking` as success. Submitted jobs can retry the
  final response without being rejected solely because they are no longer washing.
- Server reads and independent thumbnail requests run concurrently. AI findings
  and provider outages still use the existing review/retake or explicit Send anyway
  decision; neither automatically approves a wash. Only successful server finish
  changes `washing` to `photosReady`, which updates the Customer's existing
  **Check the wash** view through its Firestore listener.

New isolated tests cover concurrent capture uploads, upload barriers/retries,
one-camera side advancement, single pending photo-check/finish actions, lost
responses and the Customer screen transition. No staged evidence, completion,
approval, payout or extra charge was submitted by the agent.

Final local checks for this photo follow-up: **30 Captain tests**, **35 shared
Firebase tests**, **six targeted backend photo/lifecycle tests** and the new
Customer live-screen transition test passed. Captain/shared static analysis
passed. The preceding full backend run remains **189 passed**; the additional
status-recovery regression ran in the targeted suite afterward. The queued bytes
are retained in app memory until upload; no durable, app-terminated offline resend
is claimed. Existing already-uploaded evidence is restored from Firebase.

### Final publication — 2 November, 19:13 IST

The final Captain **1.0.2 (3)** bundle includes both follow-ups from source
`294ac01` (including `7fb9967`). It built successfully at **19:09 IST** and passed
JAR signature verification with the existing upload key. The merged manifest
confirms the unchanged Captain package, minimum SDK 24 and target SDK 36.
Bundle SHA256:
`270055f08c96f0db002f8754e3890188deb787d0deb31d1f97bb48852443f4c6`.

It was uploaded to the existing Captain internal track in Sumit's Chrome profile
and published as **1.0.2 - photo flow 294ac01**. Play confirms **Available to
internal testers**, **Released on 2 Nov 19:13**. Its only warning is the existing
missing deobfuscation mapping for this non-shrunk internal bundle. Supported
device counts did not change. No Customer release, unrelated app, signing key,
tester list or production track was changed by this upload.

All 65 ACTIVE Functions' exact source generations match the six shared release
modules, including the background-offer/claim correction. The final photo-check
Function's two additional photo-review modules also match the source. All **58**
HTTP gateways are configured, seven triggers/scheduled functions retain IAM
checks, and seven anonymous access probes, including photo review, return **401**.
Scale-to-zero is preserved. The final Captain web build is also published; all
four Customer/Captain JavaScript/bootstrap artifacts match the deployed files.
The separate marketing site was not changed.

The owner can update through the existing invitation:
https://play.google.com/apps/internaltest/4700497850061297130

This publication record does **not** claim that Captain 1.0.2 (3) has already been
installed on the phone or that its final shutter speed, alert latency and complete
native photo submission have passed. The earlier selfie, top-up and booking
results remain actual owner/device evidence. After updating, the owner should
check capture → Check photos → resolve/acknowledge actual photo advice → successful
submission → Customer Check the wash. Do not stage a wash or approve evidence
merely to obtain a passing result.

### Reopening an active job — Captain 1.0.3 (4)

The owner reported reopening at the selfie sequence despite having uploaded
Before and After evidence, then receiving arrival/location validation errors
when attempting identity verification again. Home/Jobs and plan notifications
previously opened Go to vehicle unconditionally. The arrival control then sent
the Captain toward the identity screen even for an already washing job.

The corrected client selects the existing screen from confirmed server state:
arrival → actual unheard owner recording → identity → Before photos → washing →
After photos when any After evidence is registered → submitted job. Startup
waits for both the account profile and server-confirmed orders; a cache-only
empty result cannot consume the one-time restoration. Home, Jobs and assigned-job
notifications use the same resolver. An obsolete selfie route redirects to the
current saved phase before opening the camera. Existing backend location,
assignment, private-photo, identity and evidence checks remain authoritative.

All **36 Captain tests** and **35 shared Firebase tests** pass, with clean static
analysis for both packages. Six new regressions exercise the phase matrix,
partial/full photo restoration, account isolation, repeated cold reopen,
profile-first/orders-first startup and stale selfie routing. These are isolated
fixtures, not manual writes to the owner's active job. No UI layout is changed.
This restoration uses already-uploaded server evidence; unsent captures still
do not have durable app-termination persistence. Native reopening and publication
of version 1.0.3 (4) are pending until recorded below.
