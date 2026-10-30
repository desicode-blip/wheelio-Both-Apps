# WashKrew
**Superseded:** use [the 30 October guide](AMAN-IOS-BUILD-AND-TEST-2026-10-30.md)
and its current PDF. This older guide/PDF remains historical; its build baseline,
test totals, old cancellation examples and visual-count claims are not current
acceptance evidence.

## Aman + Claude: build and test both iPhone apps

**29 October 2026 | GitHub staging | Customer + Captain + private admin**

**30 October payment update:** Read
[REFUND-WALLET-CHECKOUT-2026-10-30.md](REFUND-WALLET-CHECKOUT-2026-10-30.md) before
testing. Its owner-confirmed five-minute original-method refund / later 50% fee
and 50% wallet rule supersedes older cancellation examples in the PDF. Rebuild
the current Customer source: an older installed binary cannot acknowledge the
new terms and must update before creating a new booking. Verify all supported
UPI, debit-card, netbanking and provider-wallet groups; credit cards/EMI/paylater
stay hidden. A completed web deployment does not update a native installation.

Use the latest staging source containing this guide. The verified application
baseline is **42a37a4**; record the actual full commit after pulling. The Customer
and Captain designs stay pinned to **af036f0**, with the approved upload-only
Aadhaar screen. Do not check out the older design commit as the application build.

### Give this PDF to Claude on Aman's Mac

"Read this complete PDF, AGENTS.md and CLAUDE.md. Preserve my local work, pull
staging and build/install the two current Flutter iPhone apps. Guide me through
the numbered roles in this PDF one action at a time: tell me what to tap, what
should happen, and wait for my result. Record PASS, FAIL or BLOCKED with the
source commit. Reproduce failures, fix functionality inside the existing design
and retest. Let me enter SMS/passwords and make real payment and human approval
decisions. Do not invent success, change the design or create production fixtures."

### Which app opens next?

**CAPTAIN -> ADMIN ON MAC -> CAPTAIN ONLINE -> CUSTOMER BOOKS -> CAPTAIN WASHES
-> CUSTOMER APPROVES -> CAPTAIN MONEY.**

| Already checked on Windows/web | Still needs Aman's Mac/iPhone |
| --- | --- |
| 121 backend tests; 52 Flutter tests; four analyses; two release web builds. | Xcode compilation/signing, installation and cold launch of both signed apps. |
| Manual local admin approval, availability, assignment, fresh identity check, eight wash photos, Customer approval/rating and approved earnings. | Native camera/Photos, permissions, GPS, APNs, payment-app switching and receipt delivery. |
| 157 design states: 156 match af036f0; Aadhaar matches the approved upload-only snapshot. | Actual separate WashKrew LIVE charge and original-merchant refund acceptance. |

The local walkthrough used **simulated payment capture** and public photo
fixtures. It is not a real charge, native camera or identity acceptance result.
Production payments are LIVE. Training/video/quiz/refresher screens stay hidden.

<!-- pagebreak -->

## 2. Pull, prepare and build on the Mac

### Source and prerequisites

Use Flutter **3.38.6**, Xcode with the iPhone's iOS SDK, CocoaPods and the existing
Apple team **28JNT7H8KA** (paid "Sumit Mandal" team; was free personal team 8CCQQM7TP3 before 29 Oct). Unlock/connect/trust the iPhone; enable Developer Mode
when requested. Run `flutter doctor -v` and fix actual Xcode/iOS findings.

For an existing checkout, preserve changes shown by the first command. If it is
not clean or the branch diverges, Claude must inspect/preserve the work first.
Do not hard-reset, overwrite local code or force-push.

```sh
git status --short
git fetch origin staging
git switch staging
git pull --ff-only origin staging
git rev-parse HEAD
flutter doctor -v
bash apps/flutter/tool/run-ios.sh --prepare
```

New checkout: clone [the Wheelio repository](https://github.com/desicode-blip/wheelio-Both-Apps.git),
enter its folder, switch to staging and use the same commands above.

### First build: check signing in both workspaces

```sh
open apps/flutter/customer/ios/Runner.xcworkspace
open apps/flutter/captain/ios/Runner.xcworkspace
```

Select Runner -> Signing & Capabilities, automatic signing and the existing
owning team. Verify Push Notifications and Background Modes for remote
notifications/background fetch. Verify the team's APNs key for both iOS apps in
Firebase wheelio-apps. Missing team/APNs access is a named setup blocker; the
human completes Apple sign-in. See [Firebase's iOS messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

| App | Preserve this bundle ID |
| --- | --- |
| Customer | com.amanmaheshwari.wheelio.customer |
| Captain | com.amanmaheshwari.wheelio.captain |

```sh
bash apps/flutter/tool/run-ios.sh
# If several iPhones are connected:
bash apps/flutter/tool/run-ios.sh --device IPHONE_ID
```

The script resolves locked Dart dependencies, installs native pods, builds and
installs both Release apps. No merchant secret or Firebase owner CLI login is
needed. Do not use `--demo`. Launch both apps after disconnecting Xcode.
On pod errors, fix only the identified incompatibility; keep locks/project IDs.
Commit Mac-resolved lock changes after successful builds. Never recreate the apps.

<!-- pagebreak -->

## 3. CAPTAIN -> ADMIN -> CAPTAIN

### 1. Arrange the two roles before booking

Use **two different consenting mobile numbers**: Captain A and Customer B.
The same Firebase account cannot accept its own booking. Customer/Captain login
uses phone OTP; the admin uses an allowed Google email.

Both apps can coexist on one iPhone. For simultaneous observation keep Captain
on the phone and use [Customer web](https://wheelio-apps.web.app/app/) on the Mac.
Also test the newly built native Customer separately. A Git push does not publish
Hosting; record the web and native versions. Two iPhones give better native
GPS/push evidence; one-phone app switching cannot prove simultaneous foreground use.

### 2. OPEN CAPTAIN: sign up and upload documents

Choose language, complete/skip welcome and enter Captain A's real number. Aman
enters the actual SMS OTP in the app. Check wrong-code/edit-number recovery once,
respecting resend limits. The account must start unapproved/offline.

Complete Aadhaar, selfie and payout details using genuine consenting evidence.
On Aadhaar, **Upload Aadhaar photo** must show camera/gallery/cancel. There must
be no Open DigiLocker button. Cancel once without advancing; capture or choose a
clear image, verify the upload, then finish the selfie/payout stages. No training,
videos, quiz, refresher or approval-skip entry should appear.

Save requested society/area and real working periods within **4 AM-10 PM**.
Reopen to verify persistence. Complete the existing rules/submission flow; the
human decides whether to accept the terms. Expected: **Under review** and no work.

### 3. OPEN ADMIN ON MAC: responsible human approval

**Admin: [https://wheelio-apps.web.app/admin/](https://wheelio-apps.web.app/admin/)**

Sign in using an allowed Google account: amanmaheshwari900@gmail.com,
ajay@trustkeyper.com, ajaybhatnagar1712@gmail.com or info@trustkeyper.com.
Open Captain A under **Awaiting review**. The responsible human inspects private
identity/selfie/payout evidence and requested societies. Claude explains the
controls; the human decides and submits. Request genuine corrections before
replacement uploads, then resubmit. If self-review is blocked, another allowed
reviewer must decide. Select eligible requested active societies and approve
with a note only when appropriate. No database edit or sample person substitutes.

### 4. RETURN TO CAPTAIN: confirm approval and Online

Confirm approval arrives in the app. Go Online if still offline. Verify the same
approved society and saved overlapping hours, with no restriction/conflicting
job. Keep Captain foreground and connected. Approval alone does not mean Online
or available. Do not pay until Customer can see real matching capacity.

<!-- pagebreak -->

## 4. CUSTOMER: account, booking and payment

### 5. OPEN CUSTOMER: create the separate account

Use Customer B's number through Profile -> Log in -> real SMS code -> name.
Reopen and confirm the profile/session persists. Empty bookings must stay empty,
not show demo jobs. Check Customer camera/gallery cancel and photo replacement.
Missing approved support/legal content is BLOCKED, not a working-link result.

### 6. Make the real booking draft

Select actual vehicle/service, valid plate, optional photos, the **same served
society**, tower/floor/parking and optional text/voice/video note. Confirm saved
parking and note survive reopening. Optional skipped photos require the existing
confirmation; failed uploads must not count as saved.

Open **When should we come?** Check the original all-day/multiple-window controls
where available. Pick an actually selectable current/future window matching
Captain A. For a wash today, choose a current valid window; future jobs cannot
start early. Check review summary, actual configured price and selected period.

### 7. Check checkout cancellation, then the agreed LIVE payment

The deployed gateway uses the **separate WashKrew LIVE merchant**. Successful
checkout charges real money. This PDF authorizes no amount or transaction.
Aman personally verifies the price/merchant and authorizes any actual payment.

First close checkout without paying; confirm the same unpaid booking remains
available for recovery. Retry that booking rather than creating duplicate orders.
Direct credit-card checkout, EMI and paylater must be excluded. UPI, debit cards
and netbanking are allowed; the owner allows credit cards linked inside UPI apps.

For the agreed live attempt, Aman completes bank/UPI authorization personally.
Check payment-app switching and returning to Customer. A server-confirmed capture
should move that same booking to searching/assignment. If the bank paid while
the app is pending, reopen/check the **existing booking**. Do not immediately
pay again. Preserve its reference privately for operations review.

### Expected before moving to Captain

One Customer booking, one confirmed payment and one capacity reservation.
Failed, cancelled or uncertain checkout must not claim success. Production mode
must not be switched to test for phone testing; old records retain original mode
and merchant. Keep secrets and real banking authorization outside chat/Git.

<!-- pagebreak -->

## 5. CAPTAIN: accept, arrive and start

### 8. OPEN CAPTAIN: accept the intended job

Keep Captain Online/foreground. Inspect the real offer's vehicle, society,
window, service and earning. Accept before its server deadline. Expected: one
assigned job. An expired/rejected/claimed offer must not be accepted again.
Exact private parking and Customer evidence belong to the assigned Captain.

### 9. OPEN CUSTOMER: verify the same assignment

Customer must show Captain A for the same vehicle/society/window. Reopen once;
the active booking must persist. An unavailable route/ETA must be honest rather
than an invented countdown or moving location. Optional foreground tracking uses
actual recent Captain location, with permission.

### 10. RETURN TO CAPTAIN: reach the actual vehicle

Use real Customer notes and parking information. Play uploaded voice/video if
present, and check it is the actual note. At the vehicle, inside the allowed
window, use the arrival action. Premature arrival/start should be refused.
For access/vehicle trouble, use existing help rather than fake arrival.

### 11. Fresh selfie and four before-photos

Open **Quick check -> Open camera** for Captain A's fresh selfie. Check capture
cancel/retry. The session expires after five minutes; begin a new attempt if
needed. A poor/uncertain/different face must not silently pass. Local photo
quality or face similarity never replaces the earlier human KYC decision.

Capture the four correct before sides. Retake one and reopen. A cancelled,
dark/unreadable or failed upload must not fill a completed evidence slot.
Do not start until all four real uploads are registered. Never reuse a stale
selfie or another person's photo to work around a failed check.

### 12. Start wash -> OPEN CUSTOMER to watch

Captain starts only after valid arrival, fresh identity and four before-photos.
Customer should change to Washing/Cleaning for the same order, with the real
start time and photos. These are persisted server states, not sample timers.

Keep Captain foreground while checking recent location/ETA on Customer. Briefly
background/lock/reopen Captain: old location must be shown as stale. Do not
promise continuous background GPS; switching apps on one phone pauses the
foreground-location condition.

<!-- pagebreak -->

## 6. Finish -> Customer approval -> Captain money

### 13. CAPTAIN: finish and upload all four after sides

Complete the wash and existing checklist, then capture four correct after sides.
Cancel/retake once, check upload error recovery and reopen to confirm persistence.
Incomplete evidence must block finish. Tap **Check photos** and inspect real
advisory results. Retake flagged sides using existing controls.

If automatic review is unavailable, the explicit warning must remain visible.
An available send-anyway action requires the Captain's deliberate acknowledgement
and complete evidence. It sends photos to the Customer; it must not approve the
wash or claim a successful AI check.

### 14. CUSTOMER: inspect, approve and rate

Customer should receive Check the wash for that same order. Inspect all four
before/after angles, gallery navigation/zoom and image privacy. Only the Customer
decides whether the result is satisfactory. For a genuine issue use Report a
problem; do not invent a complaint to trigger a refund.

Approve the satisfactory wash, submit a star rating/tags and reopen. Expected:
Done in booking history, saved rating and the same final photos. Approval must
not imply that the Customer's full payment was a Captain bank transfer.

### 15. CAPTAIN: Jobs and Money

Open Captain Jobs/Money. Verify that same completed job and its configured
earning. Before Customer approval it waits; after approval it becomes approved
once. Compare with the offered earning, not the full Customer price. Reopen to
ensure there is no duplicate earning.

**Approved is a ledger state. It is not Paid or a completed bank transfer.**
Actual payout transfers and dispute decisions remain human operations. The app
must not promise a midnight transfer that has not been recorded.

### 16. CUSTOMER: receipt and booking recovery

Open Bookings -> Past -> the completed order -> **Download receipt**. Confirm
a PDF actually reaches the iPhone/Safari/Files and is legible. A server-created
link or an opened button alone is not a download PASS. Reopen the booking and
request a fresh link if needed; links are time-limited and single-use.

The local web run consumed a receipt request, but its browser did not return a
download artifact. This native delivery check is specifically still open.
Also check Book again carries the actual vehicle/place while refreshing price,
capacity and the selected window; it must not reuse a previous payment.

<!-- pagebreak -->

## 7. Native recovery and separate refund check

### 17. Check both installed native apps

| Check | What Aman must actually observe |
| --- | --- |
| Build/session | Signed Release apps cold-launch after disconnecting Xcode; both retain the correct account and active job. Record app/build/commit and iPhone/iOS. |
| Camera/Photos | Deny, cancel, re-enable in Settings and retry; Aadhaar, selfie, vehicle and official wash captures save correctly. No stuck picker or false upload success. |
| Media/location | Microphone permission, voice/video preview/upload/retry, map load/pin and foreground GPS behave correctly. Stale/background data is honest. |
| Notifications | Deny/allow/re-enable, inbox persistence, foreground/background/lock delivery and tap to the correct account/order. Training remains hidden. |
| Network/reopen | Briefly lose network during an upload and reopen an active booking/job. Retry safely, without duplicate bookings, charges, earnings or completed-photo claims. |
| Payment/receipt | Native UPI/bank app switch and lost-callback recovery; real receipt download. Do not substitute a web-only pass. |

### 18. Separate cancellation/refund: only an agreed real attempt

Use a separate booking, agreed amount and displayed terms. Aman personally
authorizes payment/cancellation; a fee or credit policy may apply. Do not promise
a free cancellation or refund amount that the actual order does not support.

Open Track refund if applicable. Verify original payment method/merchant,
amount and real provider state. Pending/Sent/Processed and bank posting are
different. Reopen/check without issuing duplicates. A delayed/rejected refund
stays due for operations review; never mark it processed by hand or send money
to a newly supplied UPI ID. Capture safe reference/status evidence privately.

### Keep these boundaries explicit

WhatsApp Business, DigiLocker, masked calls and voice OTP remain deferred.
WhatsApp controls must explain unavailability rather than show a real sent-message
claim. Approved support/legal/commercial inputs still come from Aman. Do not
simulate those services, a payout, human KYC approval or training completion.
Account deletion is a separate destructive test and is not routine cleanup.

<!-- pagebreak -->

## 8. If something fails, record it and retest

### No selectable slots or no Captain offer

Check in order: different Customer/Captain numbers; correct Firebase project;
genuine approval in current LIVE mode; Captain actually Online; same active
approved society; saved area/hours/date; overlapping 4 AM-10 PM window; no past
period, restriction or conflicting job; current network/heartbeat. Refresh
Customer capacity. Dispatch also requires confirmed payment. Future jobs may
wait for their window. Do not edit timestamps or bypass eligibility to force a pass.

### Build failure

Record the exact command, Flutter/Xcode/CocoaPods/iOS versions and redacted error.
Signing/APNs access belongs to the owning Apple team. Keep bundle IDs, team and
Firebase project. Resolve the specific pod/plugin issue and retest; do not delete
all lockfiles, broadly upgrade packages or restore retired apps. Only the two
Flutter Runner workspaces are current. No Android generation or redesign.

### Claude's result record

Use `docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md` to start a local result record.
For every case record **PASS / FAIL / BLOCKED / NOT RUN**, role, expected/observed
result, device/build/commit, safe evidence and next action. Mark PASS only after
Aman actually observes the result. Do not inherit Windows/web passes as native passes.

| Case | Minimum evidence |
| --- | --- |
| Both builds + design | Signed native cold launch; correct source/build IDs; original screens, hidden training and upload-only Aadhaar. |
| Accounts + approval | Two real SMS accounts; unapproved work blocked; genuine admin decision and persisted Online/hours. |
| Booking + payment | Correct live capacity/summary; one real confirmed payment for one order. |
| Assignment + wash | Same order both roles; accepted job, fresh selfie, four before/four after and realtime status. |
| Approval + money | Customer rating persists; correct single approved Captain earning; payout status remains separate. |
| Recovery + refund | Actual native camera/GPS/APNs/UPI/receipt observations and separately authorized provider refund result. |

Keep phone numbers, OTPs, keys, bank details, IDs, faces, signed links and private
evidence out of shared reports/Git. Preserve sensitive diagnostics privately.
Commit actual fixes, rerun failed cases and push only when Aman asks.

Detailed prior evidence: `docs/FULL-WORKFLOW-2026-10-29.md`. The repository keeps
this Markdown and its PDF together under docs/ and output/pdf/. Git push updates
source; it does not install an iPhone binary or publish Firebase Hosting.
