# WashKrew - physical iPhone acceptance record - 3 November 2026

Dated copy of IOS-ACCEPTANCE-RESULTS-TEMPLATE.md. No native case below is
pre-approved or pre-marked PASS. Read AMAN-IOS-HANDOFF-2026-11-02.md and
WALLET-CANCELLATION-2026-10-31.md for current build/role order. New financial rules
supersede historical cash-refund examples; old bookings retain saved terms.
Keep personal/financial/identity data and private evidence outside Git/shared reports.

- Date / tester: 3 Nov 2026 / Aman (guided by Claude)
- Source commit (`git rev-parse HEAD`): `ad6f7ba` on the Mac = staging `c140087` merged with Mac-only Podfile.lock commit `abcdb27` (no app-code difference)
- Customer version / build: 1.0.4 (5), Release, built 16:15 IST, installed and confirmed on the phone
- Captain version / build: 1.0.5 (6), Release, built 16:11 IST, installed and confirmed on the phone
- iPhone model / iOS:
- macOS / Xcode / Flutter / CocoaPods: macOS 26.5.1 / Xcode 26.6 (iOS SDK 26.5) / Flutter 3.38.6 / CocoaPods 1.17.0
- Second device / role, if used:
- Observed gateway mode and merchant (no keys):
- One-phone/two-phone limitations:

Use NOT RUN, BLOCKED, FAIL or PASS. For each non-pass state identify the next
action. For PASS, record the actual observed behavior and safe evidence.

| Case | Status | Expected / observed / safe evidence / next action |
| --- | --- | --- |
| Customer signed build + cold launch | NOT RUN | |
| Captain signed build + cold launch | NOT RUN | |
| Approved designs + Aman's retained UI changes through 79d17af | NOT RUN | |
| Customer SMS/account/session recovery | NOT RUN | |
| Captain SMS/account/session recovery | NOT RUN | |
| Aadhaar camera/gallery/cancel/retake | NOT RUN | |
| Selfie + payout + application submission | NOT RUN | |
| Training hidden; unapproved work blocked | NOT RUN | |
| Authorized admin receives/reviews/decides | NOT RUN | |
| Approval, map centre/radius, hours and Online persist | NOT RUN | |
| Nearby building search and saved parking pin | NOT RUN | |
| Whole-window Captain hours and full-capacity slots | NOT RUN | |
| Customer capacity/all-day/time summary | NOT RUN | |
| Vehicle/place/note/media persistence | NOT RUN | |
| Checkout methods, cancellation and retry | NOT RUN | |
| Authorized actual LIVE capture + app switch | NOT RUN | |
| Lost payment callback / same-order recovery | NOT RUN | |
| Real offer accepted / both roles agree | NOT RUN | |
| Area offer broadcast, one-tap first claim, truthful expiry | NOT RUN | |
| Arrival / fresh identity / failure recovery | NOT RUN | |
| Four before uploads + required gate | NOT RUN | |
| Realtime Washing + foreground GPS/stale state | NOT RUN | |
| Four after uploads + advisory/retry handling | NOT RUN | |
| Reopen at partial/full After photos without another selfie | NOT RUN | |
| Submitted/completed wash never restarts arrival/washing | NOT RUN | |
| Customer all-angle approval/rating/history | NOT RUN | |
| Correct single Captain earning / unpaid vs paid | NOT RUN | |
| Actual receipt download on iPhone | NOT RUN | |
| Permissions/network/background/reopen | NOT RUN | |
| APNs delivery/inbox/tap on both apps | NOT RUN | |
| Signed paid-team APNs entitlement + Background App Refresh; native login/fallback result | NOT RUN | Entitlement, team and background modes verified in the signed builds (see below). Background App Refresh on the iPhone and the login result still to be observed. |
| Customer: two delete confirmations, no deletion OTP, cancel/pending/retry | NOT RUN | |
| Captain: two delete confirmations, no deletion OTP, cancel/pending/retry | NOT RUN | |
| Delete one role only; other role's account/data remains usable | NOT RUN | |
| Same phone re-registers as fresh Customer; no deleted marker blocks place/booking | NOT RUN | |
| Same phone re-registers as fresh Captain; name required, KYC/approval/hours cleared | NOT RUN | |
| Cached profiles/photos and delayed callbacks cannot restore deleted private data | NOT RUN | |
| Open jobs/pending payment/funded-wallet deletion safeguards | NOT RUN | |
| Separately authorized cancellation/refund | NOT RUN | |
| New policy: 100% cash-plus-credit value to wallet within five minutes | NOT RUN | |
| Near-term wash: five-minute grace still returns 100% wallet value | NOT RUN | |
| After grace, at least two hours before window: 50% wallet once | NOT RUN | |
| After grace, inside two hours: zero credit, exact amount disclosed | NOT RUN | |
| Server-confirmed window and actual quoted credit deadline agree | NOT RUN | |
| Service failure / human-upheld report: full wallet value, no fee | NOT RUN | |
| Stale cancellation quote requires renewed confirmation | NOT RUN | |
| Exact paise, mixed payment, full-wallet booking and reuse | NOT RUN | |
| Home wallet, captured top-up once, shortfall top-up and wallet checkout | NOT RUN | |
| All supported UPI/debit/netbanking/provider-wallet groups | NOT RUN | |
| Direct credit-card / EMI / pay-later checkout hidden | NOT RUN | |
| Existing delayed live refund: provider processed + bank credit | NOT RUN | |

## Failures and fixes

Record role, screen, exact safe error code, reproduction steps, narrow fix commit
and retest result. Missing team/provider/content access is BLOCKED, not PASS.

## Final disposition

- Passed cases:
- Failed cases:
- Blocked / not-run cases:
- Actual charge/refund outcome (safe status only):
- Payout status (ledger approval is not transfer):
- Remaining owner/Apple/provider action:
- Source commits produced on Mac:

## Build and install evidence (Mac, 3 Nov 16:07–16:16 IST)

- `flutter doctor -v`: Xcode OK; Flutter shows a channel note only (3.38.6). Android toolchain not needed.
- `dart apps/flutter/tool/ios.dart check`: exit 0. `dart apps/flutter/tool/ios_test.dart`: exit 0.
- `run-ios.sh --prepare`: exit 0 (known CocoaPods base-config and FirebaseCore deprecation warnings only). Podfile.locks unchanged.
- `run-ios.sh` (via the Mac phone helper): both apps built and installed on the first attempt.
- Signed apps: TeamIdentifier 28JNT7H8KA; application-identifier `28JNT7H8KA.com.amanmaheshwari.wheelio.customer` / `.captain`;
  aps-environment development (matches the team development profiles, valid to 29 Oct 2027);
  UIBackgroundModes fetch + remote-notification in both.
- Xcode capability panel not opened by Claude (background control can't open the project editor); the same
  entitlements and Info.plist values were read from both projects and from the signed apps.
