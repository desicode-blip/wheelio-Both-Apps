# WashKrew - current Claude instructions

Read **AGENTS.md** first. Preserve the approved Flutter app layouts, assets,
typography and palette. Use only `apps/flutter/customer` and
`apps/flutter/captain`, with their shared Flutter packages. Retired SwiftUI,
React/Next.js, legacy Flutter and Supabase implementations are not build targets.

For Aman's Mac/iPhone, start with:

1. `docs/AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md` - current task prompt.
2. `docs/AMAN-IOS-HANDOFF-2026-11-02.md` - safe pull, prepare, sign/build/install,
   exact role order, current financial rules and native acceptance limits.
3. `docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md` - record actual results.
4. `docs/MAC-HANDOFF.md` - setup/signing troubleshooting.

Run `bash apps/flutter/tool/run-ios.sh --prepare`, then the helper without
`--prepare` to build/install both Release apps on a trusted physical iPhone.
Use paid team **28JNT7H8KA** and existing `.customer` / `.captain` bundle IDs.
Customer source version is **1.0.3 (4)**; Captain is **1.0.4 (5)**. The owner
confirmed the previous Android flow works; no physical iPhone result is pre-passed.

APNs key **Y5432Q73U8** is already configured for both apps/environments in Firebase.
Do not request, generate, revoke or commit a private key just to build the clients.
Check signed APNs entitlements, background modes and Background App Refresh if
native phone login needs Firebase fallback. Never disable real SMS verification.

Deletion now requires **two explicit confirmations, no new deletion OTP**.
Deleting one app role must preserve the other role. Open jobs, pending payments
and funded-wallet safeguards still apply. Use consenting spare test accounts.

Guide Aman one action at a time: Captain registration/documents/area/hours ->
private admin human approval -> Captain Online -> Customer booking/payment ->
Captain accept/arrival/wash/photos/reopen -> Customer review -> wallet/cancellation
and account-deletion checks. Admin: https://wheelio-apps.web.app/admin/.
New bookings use the separate WashKrew LIVE merchant; supported non-credit
methods remain, EMI/paylater stay hidden. Historical obligations keep their terms.
Training/videos/quiz are hidden and cannot block an admin-approved eligible Captain.
Coverage uses the Captain's saved map centre/radius, not manual society assignment.

Aman handles account security checks, genuine document approval, real wash evidence
and payment authorization. Keep secrets, KYC, phone numbers, tokens and exact GPS
out of Git/shared reports. Reproduce failures, make narrow functional fixes without
redesign, and record observed PASS/FAIL/BLOCKED/NOT RUN. Do not invent native passes.

Customer/Captain web acceptance is not required. Keep the private admin, website,
backend, tests, canonical design exports and current build tools. Superseded guides
and duplicate source were removed; do not recover them as competing instructions.
Commit work and push only when the owner requests it.
