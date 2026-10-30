# WashKrew
## Aman + Claude: current iPhone acceptance guide

**30 October 2026 | staging | Customer + Captain + private admin**

Use this guide instead of the 28/29 October PDFs. The current functional source
includes **cedd9ab**, following Aman's **79d17af**. Pull current staging and record
the full resulting commit. Keep Aman's camera, location, background-save and
paid-team changes. Keep the approved designs; do not rebuild old af036f0 as the app.

### Give Claude this instruction

"Read this entire PDF, AGENTS.md, CLAUDE.md and the latest reports. Preserve my
local work and build both current Flutter iPhone apps from staging. Guide me
through this PDF one role and one action at a time. Explain the expected result
and wait for my observation. Record PASS, FAIL, BLOCKED or NOT RUN with safe
evidence. Preserve the existing UI. Reproduce functionality failures before a
narrow fix and retest. I enter passwords, SMS codes, bank details and UPI PINs;
I decide real approvals and payments. Do not create production test fixtures,
change global payment mode, invent success or put private files in Git. Ajay's
side handles Firebase APNs upload after my private key handoff."

### The role sequence

**CAPTAIN signs up -> ADMIN reviews -> CAPTAIN goes Online -> CUSTOMER books
-> CAPTAIN accepts and washes -> CUSTOMER approves/rates -> CAPTAIN sees earnings.**

| Open | Address or app |
| --- | --- |
| Customer | Native WashKrew app; [Customer web](https://wheelio-apps.web.app/app/) |
| Captain | Native Captain app; [Captain web](https://wheelio-apps.web.app/captain/) |
| Private admin | [https://wheelio-apps.web.app/admin/](https://wheelio-apps.web.app/admin/) |

**Current verification:** 138 backend/rules tests, 70 Flutter tests, four analyses
and both release web builds passed. Functions/configuration and hosted artifacts
were verified. Those results do not establish Xcode signing, camera/GPS, APNs,
native payment switching or physical acceptance. Record actual device evidence.
Production checkout is **LIVE**. A normal build is not a payment sandbox.

<!-- pagebreak -->

## 2. Pull and build both apps on the Mac

Use Flutter **3.38.6**, compatible Xcode/iOS SDK and CocoaPods. Connect, unlock and
trust the iPhone; complete Developer Mode and Apple sign-in as the human. Keep
the existing paid Apple team **28JNT7H8KA** (Sumit Mandal). The earlier personal
team is historical and must not be restored.

```sh
git status --short
git fetch origin staging
git switch staging
git pull --ff-only origin staging
git rev-parse HEAD
flutter doctor -v
bash apps/flutter/tool/run-ios.sh --prepare
open apps/flutter/customer/ios/Runner.xcworkspace
open apps/flutter/captain/ios/Runner.xcworkspace
```

If local work exists or pull cannot fast-forward, preserve and inspect it first.
Do not hard-reset, overwrite work or force-push. There are exactly two current
apps, both Flutter. Open **Runner.xcworkspace**, including Pods, for each app.

| App | Keep bundle ID |
| --- | --- |
| Customer | com.amanmaheshwari.wheelio.customer |
| Captain | com.amanmaheshwari.wheelio.captain |

In Runner -> Signing & Capabilities, verify the paid team and automatic signing.
Keep existing push entitlements, camera, Photos, microphone and location purpose
strings. Do not recreate Firebase apps, bundle IDs, native projects or keys.

```sh
bash apps/flutter/tool/run-ios.sh
# If several physical iPhones are connected:
bash apps/flutter/tool/run-ios.sh --device IPHONE_ID
```

The tool resolves locked Dart dependencies, prepares Pods, builds and installs
both Release apps. Use no --demo option. Merchant secrets and Firebase owner CLI
login are not needed for the normal client build. Check the actual errors before
changing a dependency; preserve Aman's native source and lockfiles. Launch both
apps after disconnecting Xcode. Record versions, build numbers and device/iOS.

**Reinstall/rebuild the Customer app.** The new cancellation terms require the
updated client acknowledgment; an older binary must not silently accept them.

<!-- pagebreak -->

## 3. CAPTAIN -> ADMIN -> CAPTAIN ONLINE

### 1. Arrange real consenting roles

Use **two different real mobile numbers**, one per role. A Captain cannot accept
their own Customer booking. Both apps can coexist on one iPhone. For a second
view, keep Captain on the phone and Customer web on the Mac; separately test
native Customer too. One phone cannot prove simultaneous foreground behavior.

### 2. Open Captain and submit genuine documents

Complete language/welcome and real SMS login. Aman enters the OTP in the app.
Check wrong code, edit number and permitted resend recovery once. A new account
must be unapproved and unable to take jobs.

On Aadhaar, use **Upload Aadhaar photo**, then camera/gallery/cancel. Cancel once,
retake if needed and verify the actual upload survives reopen. There must be no
Open DigiLocker action. Complete selfie and genuine payout information. Keep the
current guided camera UI. Failed uploads cannot count as saved or approved.

Set requested society and real work hours/breaks within **4 AM-10 PM**. Reopen and
check exact minutes. Submit through the existing rules flow. Expected: **Under
review**. Training videos, quiz and refresher entries stay hidden and not required.

### 3. Open private admin on the Mac

[https://wheelio-apps.web.app/admin/](https://wheelio-apps.web.app/admin/)

Allowed Google reviewers: **amanmaheshwari900@gmail.com**, **ajay@trustkeyper.com**,
**ajaybhatnagar1712@gmail.com**, **info@trustkeyper.com**. An unrelated account must
not review or approve. The human inspects the uploaded private evidence and
requested societies and decides whether to request corrections or approve.
Claude guides; it does not approve a person as a test or edit the database.

Check a genuine correction/resubmission if needed. Only eligible approved
societies should be assigned. Do not fabricate documents or self-review around
an enforced restriction; use another authorized reviewer when appropriate.

### 4. Return to Captain

Confirm approval appears. Go Online and keep the app foreground and connected.
Verify approved coverage, saved overlapping hours/breaks and no restriction or
conflicting active job. Approval alone does not create capacity; Online, current
heartbeat, coverage, time, eligibility and LIVE payment mode must also match.

<!-- pagebreak -->

## 4. CUSTOMER -> availability -> real payment

### 5. Customer login, vehicle and place

Use the second number: Profile -> Log in -> real OTP -> name. Check session/name
persistence, empty states, vehicle/plate and optional photos. Save the actual
served society, tower, floor and parking. Check the current Locate me control,
permission denial/retry, map selection and reopen. Optional text/voice/video
notes must persist; a failed upload must not look saved.

### 6. Match real capacity before paying

Choose the same active society and a day/time overlapping the approved Online
Captain's exact saved hours. Customer windows cover **4 AM-10 PM**. Check the
existing all-day/flexible/time controls and the final time summary. A saved break
must remove incompatible capacity. A different society/offline Captain should
not create false availability. Server checks at payment and assignment remain
authoritative even when a cached list was shown.

Measure cold first opening and a repeat opening on the actual phone. Record the
time to real available/unavailable slots and the network condition. Startup
preload/cache improvements are included; no paid warm minimum is enabled and no
zero-latency promise is made. If capacity is absent, diagnose eligibility rather
than removing its guard or placing an unfulfillable payment.

### 7. Review and checkout

Check total, wallet credit used, cash due, place and time before continuing.
Read the **five-minute cancellation terms** on the existing Review card. Use the
existing credit toggle to test with/without available credit; do not invent a
wallet balance or bypass account ownership.

Razorpay must show unrestricted supported **UPI apps**, **debit cards**,
**netbanking** and **provider wallets**. Google Pay is not the only UPI choice.
Direct credit cards, EMI, cardless EMI and pay-later stay hidden. Credit-linked
UPI remains allowed by the owner's decision. Device/app/provider eligibility may
affect individual options; record what the live chooser actually exposes.

Cancel checkout once: no paid booking or duplicate debit. Retry the same booking.
Only the human authorizes a real charge and enters bank/UPI details. Record the
authorized amount and actual capture; no agent makes a charge as a test. Return
from the payment app and reopen to verify server recovery without duplicate pay.
Fully covered wallet bookings must not open Razorpay or charge cash.

<!-- pagebreak -->

## 5. CAPTAIN accepts -> wash -> CUSTOMER approval

### 8. Offer and arrival

After payment confirmation, Captain must receive the genuine matching offer.
Accept it and confirm both apps refer to the same booking/time/place. A second
Captain cannot claim an already assigned job. Check offer expiry/offline recovery
without forcing an acceptance. Customer must show actual assignment/status.

Use arrival/navigation controls with the real vehicle location. Check foreground
GPS updates in Customer and a clear stale/unavailable state when tracking stops;
do not expect continuous iOS background tracking beyond implemented permissions.
Test an actual fresh selfie session; old uploads, failed verification or denied
camera cannot grant entry. Photo checks are advisory and do not replace human KYC.

### 9. Before photos, Washing, after photos

Take/upload all **four before photos** in the existing angle order. Cancel and
retake once. Missing/unuploaded photos must block starting. Start wash and verify
the Customer's real-time status changes to Washing. Reopen either app during the
job and confirm the current server state, with no second job or lost photos.

Take/upload all **four after photos**, verify angles and failed-network recovery,
then submit completion. Check quality guidance and retry handling. No local timer
or placeholder must manufacture evidence, successful completion or approval.

### 10. Customer review, rating and history

Open Customer's completed wash and inspect all required before/after angles.
The human chooses whether to approve. Exercise genuine issue reporting if needed;
do not file a false dispute solely to test. Dispute outcomes remain human ops.

After approval, submit a rating once. Reopen history and download the actual
receipt on the iPhone. Verify the booking amount and status agree in both roles.
Captain should have **one** approved earning; duplicate taps/callbacks must not
double it. An earning in the ledger is not a completed bank payout. Only actual
human payout processing plus confirmed provider/bank evidence establishes payment.

### Recovery evidence

Record the failing role/screen, exact safe error, steps, source commit, expected
and observed behavior. Keep identity images, private locations, phone numbers,
payment IDs and financial screenshots outside Git/shared test reports. Retest
only the affected path and required related checks after a narrow code fix.

<!-- pagebreak -->

## 6. Cancellation and wallet acceptance

These rules apply to **new bookings** that saved refundThenCredit. Existing
bookings keep their original saved terms and merchant/mode. Do not change an old
order to test the new policy. The five-minute window begins at the first server
booking confirmation, not when checkout opens. Washing closes self-cancellation.

| Case | Expected result |
| --- | --- |
| INR 149 cash, within 5 minutes | Refund INR 149 to the original method; fee zero. |
| INR 149 cash, later, before washing | Fee INR 74.50; WashKrew wallet gets INR 74.50; no bank refund. |
| INR 150 total: INR 100 cash + INR 50 wallet, within 5 minutes | Original cash refund INR 100 and restore INR 50 wallet; fee zero. |
| Same mixed booking, later | Fee INR 75 and wallet return INR 75 total; do not add the old INR 50 again. |
| INR 150 entirely wallet, later | Fee INR 75 and wallet return INR 75; no cash refund. |
| Automatic no-capacity/no-show/service failure | Full cash refund plus restoration of used credit; Customer late fee does not apply. |

### 11. Quote and timing boundary

Use separate **human-authorized** bookings only when sufficient real capacity
and merchant refund funds exist. Open Cancel and check exact cash return, wallet
return and fee before confirming. If five minutes passes while the sheet is
open, a stale confirmation must do nothing, refresh the quote and require a new
human confirmation. Repeated taps/reopen must not add money twice.

Do not report "refunded" solely because a refund was queued. Check actual provider
processed status and separately confirm original-method credit with the human.
An unavailable provider/balance must remain pending/delayed and recover safely.
Do not reduce a promised full refund to fit the merchant balance.

### 12. Reuse real returned credit

Home should show exact paise. Apply credit on the next Review screen: INR 74.50
credit against INR 149 leaves INR 74.50 cash. Excess credit stays available. A
fully covered booking creates no external charge. If partial credit would leave
less than Razorpay's INR 1 cash minimum, the tiny unused credit remains in wallet.

No dedicated wallet-history/withdrawal screen was invented. Existing Home,
Review, Cancel and result controls implement this flow. A new activity page
requires Aman's design and a separate decision; wallet withdrawal is not enabled.

<!-- pagebreak -->

## 7. Device recovery and notifications

### 13. Permissions, restart and poor network

Check camera, Photos, microphone and GPS first grant/deny/retry on both roles.
Let the human change OS permissions. Cancel media selection without advancing.
Test rotation/keyboard on existing layouts, narrow iPhone widths and large text.
Do not redesign screens to hide a failing native handler.

Interrupt an upload/save, restore connection and retry. Reopen after a successful
save. Background/foreground while paying, receiving an offer and washing: server
state must recover without duplicate booking, money, photo, rating or earnings.
Try duplicate taps at the normal controls. Never disable server role/ownership,
payment, capacity, identity or photo gates to make a test pass.

### 14. APNs is blocked until the correct key is configured

Aman's only key task: privately provide the original Apple APNs **.p8**, its Key
ID, paid team **28JNT7H8KA**, and allowed environment/topic details for **both**
bundle IDs. Keep the file outside Git and public chat. Ajay's side uploads it to
Firebase after receipt. Do not ask Aman to upload/configure Firebase, regenerate
unrelated existing keys or send Apple passwords. The key-only prompt is
`docs/AMAN-CLAUDE-APNS-KEY-ONLY-2026-10-30.md`.

After Ajay confirms configuration, test both native apps separately: foreground
inbox, background/locked-screen notification and tap into the correct current
booking. Test normal human-authorized booking events, not fake production users
or artificial approval. Record actual delivery. A registered FCM token, enabled
entitlement or a durable inbox item alone does not prove APNs delivery.

### 15. Remaining account and content checks

Verify profile, work hours, saved parking and sign-out/relogin. An unrelated
reviewer account must not access admin data. Only test account deletion on a
consenting disposable account with no outstanding work/money, at the end. Deleting
Customer must preserve the separate Captain role and vice versa.

Support tickets use real backend state; approved support contact details and
legal entity/terms/privacy content are still owner inputs. Missing approved
content is **BLOCKED**, not a working-link PASS. Training remains hidden. No
DigiLocker, WhatsApp Business, masked-call or voice-OTP acceptance is claimed.

<!-- pagebreak -->

## 8. Known findings and honest completion record

### Read-only live audit on 30 October

Two existing INR 149 WashKrew LIVE UPI captures matched Firebase booking amounts
and provider orders. One INR 149 refund is provider **processed** and matches
Firebase. Another INR 149 original-policy refund remains **delayed/retrying**;
the provider returned HTTP 400 BAD_REQUEST_ERROR and no refund record yet.
These historical bookings do not prove the new five-minute/wallet policy or
other payment methods. Actual bank-credit confirmation remains a human check.

The merchant dashboard showed **INR 141.96 current balance, INR 0 reserve and
INR 0 refund credits**, a **INR 7.04 shortfall** against the INR 149 refund. This
is a funding blocker consistent with Razorpay's documented balance requirement;
the generic API error alone does not rule out other rejection causes. Check
current funds and provider status again after funding, before further tests.
Only the human can authorize a reserve top-up from the registered settlement
account. The backend must keep the full amount owed and its original merchant.
Do not submit an extra manual refund alongside an automatic retry.

### What remains before launch acceptance

| Owner / environment | Required evidence or input |
| --- | --- |
| Aman on Mac/iPhone | Both signed builds; camera/Photos/GPS, complete role sequence, payment chooser/app switch, receipts, actual new-policy early/late/mixed-wallet cases. |
| Aman -> Ajay | Private paid-team APNs key/details; Ajay configures Firebase, then both apps need real delivery tests. |
| Merchant owner | Resolve the outstanding full refund and keep enough refund/reserve balance. Actual bank credit, separate-method charges and payout transfers need human evidence. |
| Aman / business owner | Approved operating legal entity, support phone/email/hours, terms/privacy URL and commercial/service coverage inputs. |
| Apple account owner | Any paid-team/device access or company seller enrollment required by Apple. |

### Record each result

Copy `docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md` to a dated private/local result.
For each case record **NOT RUN, BLOCKED, FAIL or PASS**, source commit, app
version/build, iPhone/iOS, expected/observed result and safe evidence. Do not
pre-mark PASS. Keep private evidence and keys outside Git. Record any narrow fix
commit and actual retest. Report ledger approval separately from bank payment.

Send Ajay the safe results and exact blockers after testing. A staging push and
a web deployment do not install a native update or establish App Store approval.
