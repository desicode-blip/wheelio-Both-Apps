# WashKrew
## Aman + Claude: which app to open next

**28 October 2026 | staging | Application code: b89e005 and later**

Give this guide to Claude on Aman's Mac. It is the short execution order;
`docs/AMAN-IPHONE-ACCEPTANCE-2026-10-28.md` and its 14-page PDF contain the detailed
acceptance cases. Pull latest staging, including the commit containing this guide.

### Message Aman can paste into Claude

"Read AGENTS.md, CLAUDE.md, docs/AMAN-CLAUDE-TEST-FLOW-2026-10-28.md and
docs/AMAN-IPHONE-ACCEPTANCE-2026-10-28.md. Build and install the current Flutter
Customer and Captain apps on my connected iPhone. Then guide me through the
exact app/admin switching order in this flow. Give me one action at a time, say
what should happen, and wait for my observed result. Record PASS, FAIL or BLOCKED
with the source commit. Reproduce failures and fix functionality inside the
af036f0 design; do not redesign. Training stays hidden. Tell me before any real
payment, cancellation, account deletion or human approval so I can perform it.
Never fake a payment, Captain approval, photo, location or test result."

### First: build both current apps

Preserve any local Mac changes before pulling. If the pull diverges, inspect it;
do not hard-reset or force-push. From the existing repository root:

```sh
git status --short
git switch staging
git pull --ff-only origin staging
git rev-parse HEAD
flutter doctor -v
bash apps/flutter/tool/run-ios.sh --prepare
bash apps/flutter/tool/run-ios.sh
```

Use Flutter 3.38.6, Xcode, CocoaPods, a trusted unlocked iPhone and the owning
Apple signing team. Claude resolves actual build errors narrowly and records
the result. The workspaces are `apps/flutter/customer/ios/Runner.xcworkspace`
and `apps/flutter/captain/ios/Runner.xcworkspace`. Preserve bundle IDs and team
`8CCQQM7TP3`. Do not restore removed apps, use --demo or run old Next.js commands.
No merchant secrets or Firebase owner login is needed to compile the apps.

### People and screens to have ready

Use two different consenting mobile numbers: **Captain A** and **Customer B**.
Using the same number for both prevents self-assignment and invalidates this test.
Use a real service location, vehicle and approved work period.

With two phones: Captain on one, Customer on the other, admin on the Mac.
With one iPhone: first check both installed native apps, then keep Captain on
the phone and use Customer on the Mac for the main simultaneous flow:
https://wheelio-apps.web.app/app/ . Test native Customer separately too. The web
helper is the currently deployed version; a Git push does not publish Hosting.
Record both versions. One phone cannot prove simultaneous foreground native GPS
and native Customer use; keep those results BLOCKED until properly observed.

<!-- pagebreak -->

## 2. Prepare Captain, approve, then prepare Customer

**Order: Captain -> Admin -> Captain -> Customer. Do not pay before this works.**

### 1. OPEN CAPTAIN - create the working account

Choose the language, finish/skip welcome and sign up using Captain A's number.
Aman enters the real SMS OTP in the app. Captain must begin offline/unapproved.
Complete the **three** existing KYC stages: Aadhaar, selfie, Bank or UPI. Capture
genuine consenting evidence and verify cancel/retake. Training/video/quiz and
refresher UI must be hidden, including the Me/Profile entry.

Continue through the existing rules/submission flow; Aman personally decides
whether to accept its terms. Save the requested society/area and actual work
periods within 4 AM-10 PM. Reopen and verify those values persist. Submit the
application. Expected: **Under review**, no genuine Online or job access.

### 2. OPEN ADMIN ON MAC - human document review

Admin portal: https://wheelio-apps.web.app/admin/

Sign in with an approved Google account, for example Aman's
`amanmaheshwari900@gmail.com`. Other approved reviewers are
`ajay@trustkeyper.com`, `ajaybhatnagar1712@gmail.com` and `info@trustkeyper.com`.
Phone OTP alone does not grant admin access.

Open the submitted Captain under **Awaiting review**. The responsible human
checks private identity/payout details, eligibility and requested societies.
Claude explains controls; the human makes and submits the approval decision.
If self-review is blocked, another approved reviewer must do it. For a genuinely
needed correction, request it first, return to Captain, correct and resubmit.
Once acceptable, select the requested active societies and approve with a note.
No fake applicant, automatic approval or database edit may replace this step.

### 3. RETURN TO CAPTAIN - confirm approval and go online

Confirm Firebase delivers approval. Go online if still offline; the server must
accept it. Reopen work settings: same approved society, correct day and overlapping
working period, no conflicting active job. Keep Captain open/connected for offers.
Approval alone is not proof that the Captain is currently available.

### 4. OPEN CUSTOMER - create the separate account and booking draft

Use Customer B's different number: Profile -> Log in -> real OTP -> name.
Reopen and check persistence. Select the actual vehicle/service, plate, optional
photos, same served society, parking pin/floor/slot and optional note.

Open **When should we come?** Choose an actually available window. Check
**Any time of the day** / multiple windows when available. For a same-session
wash, choose a valid current window; future work cannot start early. Review the
real price and all booking details. Expected: available capacity from the approved
Captain, not sample availability. If no slots appear, use page 4 before paying.

<!-- pagebreak -->

## 3. Payment, assignment and wash: exact switching order

**Payments are LIVE on the separate WashKrew merchant. Aman authorizes real money.**

### 5. CUSTOMER - pay, then keep the same booking

Inspect checkout: UPI, debit cards and netbanking are permitted. Direct credit
card/EMI/paylater checkout must be excluded; a credit card linked inside UPI is
allowed by the owner. First cancel checkout without paying and check safe retry.
For the agreed live attempt, Aman verifies the displayed amount and completes
UPI/bank authorization personally. No additional charge is authorized by this PDF.

Expected: server-confirmed payment for one booking, followed by searching or
assignment. If the bank paid but the app is pending, check/reopen that same
booking. Do not immediately pay again or create a replacement order.

### 6. CAPTAIN - receive and accept the real offer

Keep Captain online in the foreground (use Customer on the Mac if only one
iPhone is available). Inspect the real vehicle, society, time and offered earning.
Accept the intended offer before it expires. Expected: one assigned job; no
sample timer, second Captain or unrelated account can claim the same job.

### 7. CUSTOMER - confirm the assignment

Open that booking. Confirm the Captain and vehicle/society/window agree with
Captain's active job. Reopen once: the same order must persist. Optional recent
foreground GPS/ETA should be actual data, not an invented moving marker.

### 8. CAPTAIN - arrive, identity check and before photos

At the actual vehicle, inside the allowed window, use the arrival action. Follow
any real access/help and Customer note steps. Open **Quick check -> Open camera**
for the approved Captain's fresh selfie; retry if its five-minute session expires.
Capture all four before sides into the correct boxes. Verify cancel/retake/upload
recovery. Failed uploads cannot count as complete. Only then start the wash.

### 9. CUSTOMER - watch the same wash

Expected: the same booking changes to **Washing**. Compare real status and recent
position/ETA while Captain stays open. Briefly background/reopen Captain: stale
location must be honest. One-phone app switching does not prove background GPS.

### 10. CAPTAIN - finish, capture after photos and send

After the real wash, capture all four after sides. Check/retake flagged sides
using existing controls. AI review is advisory; a result or send action cannot
approve the wash. Send complete evidence. Expected: waiting for Customer review,
with earnings awaiting approval. Reopen once to confirm evidence persists.

### 11. CUSTOMER -> CAPTAIN - approve, rate, then verify earnings

Customer inspects private before/after photos and personally approves a
satisfactory result, then rates. For a genuine concern, use Report a problem;
do not invent a complaint. Open Captain Jobs/Money: verify the same completed job
and correct approved ledger earning. A ledger entry is not a bank payout.
Record the same order reference privately and the observed states from both apps.

<!-- pagebreak -->

## 4. Recovery checks and what Claude should report

### No slots or no offer: check in this order

1. Different real Customer/Captain numbers; same correct Firebase project.
2. Genuine human Captain approval in the current live mode; Captain actually Online.
3. Same approved served society/area, saved location/work profile and chosen date.
4. Overlapping work periods, 4 AM-10 PM, no past window, restriction or conflicting job.
5. Current network/heartbeat; keep Captain foreground and refresh Customer availability.
6. Payment must be confirmed before dispatch. A future booking may wait for its window.

Record the actual cause. Never fix capacity by fake approval, invented coverage,
changing production payment mode, editing timestamps or bypassing identity checks.

### Separate refund check - only if Aman authorizes it

Use a separate agreed booking, price and displayed cancellation terms. Cancellation
after assignment may have a fee; do not promise a free cancellation. Aman pays and
cancels personally. Customer opens **Track refund**; verify the original method,
correct amount and real provider state. Reopen/check again without duplicate refund.
Queued, Sent and Processed are different; bank posting can follow provider processing.
If delayed/rejected, preserve the original reference for operations review. Do not
mark it refunded by hand or send money to a newly entered UPI ID.

### Native checks on BOTH installed apps

Follow section 12 of the full acceptance guide: cold launch, SMS/session restore,
camera/photo denial/cancel/retake/re-enable, microphone/media, map/GPS, network
recovery and APNs notification/tap tests. Native Customer payment-app switching
needs its own observed check. Missing hardware/provisioning is BLOCKED.

Training remains hidden. Approved support/legal content and deferred external
services remain known inputs. Do not fake them, bank payouts or dispute decisions,
or delete accounts as routine test cleanup.

### Results Claude must leave for Aman

Record **PASS / FAIL / BLOCKED**, app/build/commit, iPhone/iOS, expected/observed
state and next action. Keep OTPs, keys, bank details, IDs, faces and private
evidence out of Git/shared reports.

| Case | Evidence needed before calling it PASS |
| --- | --- |
| Build + design | Both signed apps cold-launch; af036f0 layout retained, training hidden. |
| Account + admin | Two separate SMS accounts; genuine review; unapproved work blocked. |
| Availability + pay | Correct approved work capacity; one actual server-confirmed payment. |
| Assignment + wash | Same order both roles; real accepted job, fresh capture and eight photos. |
| Approval + earnings | Customer decision persists; correct single ledger earning, no payout claim. |
| Refund + native | Actual provider refund result; separately observed camera/GPS/APNs/UPI cases. |

Claude should stop on a named failure, preserve evidence, fix the smallest cause
inside the existing Flutter frontend and rerun that case. Never mark an unobserved
device or real transaction as PASS. Commit fixes; push only when Aman asks.
