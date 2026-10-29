# WashKrew - physical iPhone acceptance record

Copy this to a local dated result file before testing. No native case below is
pre-approved or pre-marked PASS. Read AMAN-IOS-BUILD-AND-TEST-2026-10-29.md first.
Keep personal/financial/identity data and private evidence outside Git/shared reports.

- Date / tester:
- Source commit (`git rev-parse HEAD`):
- Customer version / build:
- Captain version / build:
- iPhone model / iOS:
- macOS / Xcode / Flutter / CocoaPods:
- Customer helper web version, if used:
- Observed gateway mode and merchant (no keys):
- One-phone/two-phone limitations:

Use NOT RUN, BLOCKED, FAIL or PASS. For each non-pass state identify the next
action. For PASS, record the actual observed behavior and safe evidence.

| Case | Status | Expected / observed / safe evidence / next action |
| --- | --- | --- |
| Customer signed build + cold launch | NOT RUN | |
| Captain signed build + cold launch | NOT RUN | |
| Both designs match af036f0 + approved W05 | NOT RUN | |
| Customer SMS/account/session recovery | NOT RUN | |
| Captain SMS/account/session recovery | NOT RUN | |
| Aadhaar camera/gallery/cancel/retake | NOT RUN | |
| Selfie + payout + application submission | NOT RUN | |
| Training hidden; unapproved work blocked | NOT RUN | |
| Authorized admin receives/reviews/decides | NOT RUN | |
| Approval, society/hours and Online persist | NOT RUN | |
| Customer capacity/all-day/time summary | NOT RUN | |
| Vehicle/place/note/media persistence | NOT RUN | |
| Checkout methods, cancellation and retry | NOT RUN | |
| Authorized actual LIVE capture + app switch | NOT RUN | |
| Lost payment callback / same-order recovery | NOT RUN | |
| Real offer accepted / both roles agree | NOT RUN | |
| Arrival / fresh identity / failure recovery | NOT RUN | |
| Four before uploads + required gate | NOT RUN | |
| Realtime Washing + foreground GPS/stale state | NOT RUN | |
| Four after uploads + advisory/retry handling | NOT RUN | |
| Customer all-angle approval/rating/history | NOT RUN | |
| Correct single Captain earning / unpaid vs paid | NOT RUN | |
| Actual receipt download on iPhone | NOT RUN | |
| Permissions/network/background/reopen | NOT RUN | |
| APNs delivery/inbox/tap on both apps | NOT RUN | |
| Separately authorized cancellation/refund | NOT RUN | |

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
