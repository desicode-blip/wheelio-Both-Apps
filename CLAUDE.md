# WashKrew - Claude continuation

Read and follow **AGENTS.md** in this directory. It is the current common policy
for every coding agent and supersedes older historical handoff instructions.

Start with:

**Current iPhone build/test handoff (29 October):** read
`docs/AMAN-IOS-BUILD-AND-TEST-2026-10-29.md` and its PDF
`output/pdf/WashKrew-Aman-iOS-Build-and-Test-2026-10-29.pdf` first. Guide Aman
one role/action at a time and use `docs/IOS-ACCEPTANCE-RESULTS-TEMPLATE.md` for
actual native results. `docs/FULL-WORKFLOW-2026-10-29.md` records the latest
Windows/web evidence and simulated-payment limits. Older guides are detail/history;
the current LIVE merchant, upload-only Aadhaar and hidden training policy win.

For the exact order of Captain -> Admin -> Captain -> Customer and the live wash,
first read `docs/AMAN-CLAUDE-TEST-FLOW-2026-10-28.md` (short PDF in `output/pdf/`).
Guide Aman one action at a time, then use the detailed acceptance guide below.

1. `docs/DESIGN-AUDIT-2026-10-28.md` - owner design lock **af036f0**, visual
   comparison, removed alternate apps and known testing limits.
2. `docs/AMAN-IPHONE-ACCEPTANCE-2026-10-28.md` and its PDF in `output/pdf/` - guide
   Aman through both apps on his iPhone, record actual results, reproduce failures.
3. `docs/MAC-HANDOFF.md` - Flutter/Xcode/CocoaPods setup and current workspaces.
4. `docs/COMPLETION-2026-10-28.md` and `docs/LIVE-PAYMENTS-2026-10-28.md` - current
   LIVE merchant, hidden training, human approvals and operational limits.
5. `docs/BACKEND-HOOKUP.md` before connecting a new backend service.

Only build `apps/flutter/customer` and `apps/flutter/captain`. The old independent
SwiftUI, Next.js/React and legacy Flutter apps were removed at the owner's request;
do not recover them as the build target. Open the current Flutter apps' respective
`ios/Runner.xcworkspace` files. Keep bundle IDs and Apple team. Fix functionality
inside the designed screens; do not redesign. Root pnpm commands now target Flutter.

Training/quiz/refresher are hidden, not required and grant no fake completion.
Human `/admin/` approval is mandatory for working. Payments are LIVE on the separate
WashKrew merchant; no direct credit-card checkout, UPI-linked credit remains allowed.
Never assume that an older report's test-mode/training-required statement is current.

Do not claim a source, emulator or design-gallery check proves physical iPhone
camera, GPS, APNs, payment app switching, KYC or real charge/refund acceptance. Keep
private information out of reports. Commit changes; push only when Aman asks.
