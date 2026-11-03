# WashKrew - physical iPhone acceptance record

Copy this to a local dated result file before testing. No native case below is
pre-approved or pre-marked PASS. Read AMAN-IOS-HANDOFF-2026-11-02.md and
WALLET-CANCELLATION-2026-10-31.md for current build/role order. New financial rules
supersede historical cash-refund examples; old bookings retain saved terms.
Keep personal/financial/identity data and private evidence outside Git/shared reports.

- Date / tester:
- Source commit (`git rev-parse HEAD`):
- Customer version / build:
- Captain version / build:
- iPhone model / iOS:
- macOS / Xcode / Flutter / CocoaPods:
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
| Signed paid-team APNs entitlement + Background App Refresh; native login/fallback result | NOT RUN | |
| Customer: two delete confirmations, no deletion OTP, cancel/pending/retry | NOT RUN | |
| Captain: two delete confirmations, no deletion OTP, cancel/pending/retry | NOT RUN | |
| Delete one role only; other role's account/data remains usable | NOT RUN | |
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
