# Current-source cleanup - 3 November 2026

Owner request: keep the latest website and Android/iOS apps with their supporting
files, remove unused material, and push staging for Aman's Mac/iPhone retest.
Baseline: **fd6026cecd04f255b3bb3dca78ba91872bff0187**. The fetched remote contained
no newer change; its latest website/footer work is already included.

## Retained source

- Current Flutter Customer/Captain, both Android/iOS projects and all shared
  packages/assets, compatible locks, native build tools and automated tests.
- Latest `apps/website`, default landing, private human-review admin, Firebase
  backend/rules/indexes/operations and private photo-check service.
- Brand masters, canonical `designs/` exports, screen index and current design-QA
  references/tooling. Browser adapters/previews are part of the same source and
  remain useful to QA; no separate legacy app is restored or built.
- Current build/operations/policy documents, native acceptance template and
  [one current Claude build/retest prompt](AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md).

## Removed and consolidated

Removed **215 tracked files**, about **16.46 MB** before documentation consolidation:

- `Wheelio-designs/`: all 127 project files were byte-identical to `designs/` and
  its screen index matched `docs/screen-index.csv`. Keep one canonical export.
- Unused root `rename.bundle` (about 12.5 MB), retired Supabase functions/schema/
  seed and obsolete Neon/Supabase contracts/templates. This removes source files
  only, not any actual cloud database or historical financial obligation.
- Superseded Mac/APNs request/payment-funding/web handoffs, historical PDFs and
  old generated acceptance outputs that no longer guide current builds.
  Git history retains those records; no history rewrite or force-push is used.
- README, Claude instructions, Flutter/backend/operations/Mac status docs now
  describe current native apps and actual policies instead of conflicting old
  instructions. The obsolete port-3000 launcher now previews the current website.

No app widget layout, typography, color, asset, runtime Dart behavior, current
backend code, website public file or native project setting is changed by cleanup.
Three Dart files have documentation-comment updates only. Demo/reference and
paused training code stay because the current app/QA still references them; a
hidden supported path is not an unused alternate implementation.

## Verification and handoff

Cleanup verification passed:

- All **567 protected current source/assets** match the pre-cleanup baseline;
  the three Dart edits change comments only. Native projects/settings, authored
  UI, current backend runtime code and website public files are unchanged.
- Static analysis is clean for Customer, Captain and both shared packages.
- Portable iOS preflight/tooling regressions pass for both apps. This does not
  execute Xcode, CocoaPods or a physical iPhone.
- All retained local Markdown links resolve; Hosting/launcher JSON parses, and
  all local website HTML/CSS asset targets exist. The current native build
  helper, workspaces and versioned dependency locks remain intact.
- The working source tree contains **646 tracked files**, down from 859,
  including the two new current cleanup/retest documents. Removed history stays
  recoverable through ordinary Git; publication uses a normal staging push.

Runtime suites were not needlessly repeated for comment/document/unused-file
deletion: the preceding functional release passed 196 backend and 172 Flutter
tests and was deployed; see
[its report](ACCOUNT-DELETION-2026-11-03.md).
Source versions remain Customer **1.0.3 (4)** and Captain **1.0.4 (5)**.
No new payment authorization, device install, website deployment or database
operation is part of cleanup. Aman's Mac/iPhone results remain to be recorded.
