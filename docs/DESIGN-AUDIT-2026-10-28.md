# Customer and Captain design audit - 28 October 2026

The owner's design reference is **af036f070aa624310b97b8277bfb6aabf9d8c4cc**
(**af036f0**). Functionality must run in that frontend. No new layout, palette,
type scale, component set, logo or app assets are approved by this audit.

The audit started from staging `17571de`. Fetching origin showed no newer staging
commits at that time. The current working fixes are included in the comparisons;
the reference is exported directly from the pinned commit.

## Findings and changes

1. **Multiple build targets were still present.** Root `pnpm dev`, `build`,
   `preview` and `typecheck` launched the retired Next.js/React app. README and
   agent instructions still described that stack and the old SwiftUI project as
   runnable options. The SwiftUI apps used the same bundle IDs as the current
   Flutter apps, so installing one could replace the other. This is a source of
   ambiguity; it is not proof of which binary Aman previously ran.
2. **The owner explicitly requested removing other apps.** Removed the retired
   `apps/ios` SwiftUI project, `apps/web` Next.js/React frontend, `legacy` Flutter
   customer implementation and empty `apps/android` placeholder: 172 tracked files.
   They remain recoverable in Git. Root commands now target the current Flutter
   apps; old JavaScript workspace dependencies and Cloudflare/database commands
   were removed. Current Customer/Captain, native Runner projects, shared packages,
   Firebase/photo backend, private admin, public website and design exports remain.
   No database, hosted service, real user or merchant record was deleted.
3. **An unused generic Firebase frontend remained in the shared package.** Removed
   its email/password pages, basic request/application dashboards and legacy
   `WashKrewRepository`. Those pages had no configured production entrypoint.
   The actual `LiveBackend`, phone OTP, checkout, assignment, photos, tracking and
   account controllers remain. Firebase initialization failure still fails closed;
   it never silently opens sample bookings. The existing failure view is retained.
4. **One extra payment-rejection screen was introduced after the reference.**
   Restored the reference cancellation/refund composition and actions for this
   state. Actual rejection detail is shown in its existing message region.
   Direct credit-card exclusion and original-merchant refunds remain enforced.
5. **Shared design sources were already unchanged since af036f0.** Palette,
   typography, components, fonts, brand images and authored layouts were compared.
   This audit does not justify replacing them with guessed designs. Backend results
   and the separately approved policy differences below must not be rolled back
   by restoring entire old files.

## Design and policy differences to keep explicit

| Difference from the original sample experience | Current requirement |
| --- | --- |
| Three KYC stages, no training/quiz/refresher links | Owner requested hiding training. Human admin approval is mandatory; no fake training credit. |
| Server booking windows extend to 4 AM-10 PM | Owner requested matching Captain work hours. Availability comes from eligible approved/online Captains and current society/mode/work periods. |
| Debit-card checkout wording and provider methods | Owner excludes direct credit-card checkout, EMI and paylater. UPI-linked credit remains allowed. |
| Real review status/correction notes, no approval skip | Server and human decisions replace sample outcomes in the existing screens. |
| Fresh SMS verification before current-app account deletion | Owner chose current-app-only deletion. The existing phone/code screen is reused. |
| Real images/maps/media, loading and failure data | Existing authored regions display actual data; a missing provider cannot be a fake success. |

No sample slot, price, ETA, application approval, payment result, identity or photo
was written to production for this audit. No payment mode or merchant was changed.

## Reproduce the comparison

Run from the repo root using Flutter 3.38.6 and Python with Pillow/numpy:

```sh
python3 apps/flutter/tool/design_audit.py
```

Set `FLUTTER_BIN` if Flutter is not on PATH. On Windows use the installed Python
executable (`python` instead of `python3` if appropriate). The script:

- Exports the pinned Git reference and copies current non-ignored source into
  disposable folders under `.cache/design-audit/`; it never edits app source.
- Freezes direct `DateTime.now()` calls **only in those render copies** to
  28 October 2026, 09:30. This removes minute/date changes from the sample data.
- Renders at 390 x 844, DPR 1, Flutter's iOS target, with bundled Roboto and
  Material icons. Logo decoding finishes before capture. This is a Windows
  Flutter widget renderer, not a signed iOS build or a native screenshot.
- Opens the 79 Customer and 77 Captain gallery states, plus Customer C12 on
  Tomorrow, asserting that **Any time of the day** is present there.
- Re-enables training **only in the disconnected comparison fixture** to render
  the reference's authored training states. The actual app/server policy stays off;
  the Captain tests separately cover that decision.
- Records capture errors, per-pixel equality and RGB differences over 8/255.
  Only up to four animated timer antialias pixels in the fixed Captain countdown
  region are tolerated; all other image differences fail for manual review.
- Writes PNGs, difference panels and `results.json` under the ignored audit folder.
  The Screens gallery and sample identities remain isolated; Firebase never starts.

## Verification and limits

- **157/157 pixel-exact** with matching fixture state and frozen time: all 79
  Customer gallery states, all 77 Captain gallery states and C12 Tomorrow/all-day.
- Zero capture errors or unreviewed differences. Full per-state results are in
  [DESIGN-AUDIT-RESULTS-2026-10-28.json](DESIGN-AUDIT-RESULTS-2026-10-28.json).
- [C12 all-day comparison](../output/design-audit/customer-C12-tomorrow-af036f0-comparison.png)
  and [W04 comparison with original training fixture](../output/design-audit/captain-W04-af036f0-comparison.png)
  show the two sides. The latter is deliberately the original four-stage fixture;
  actual production training stays hidden, as separately authorized.
- All four Flutter analyses passed. **40 Flutter tests passed**: 17 Customer,
  6 Captain and 17 shared Firebase. This includes the cancellation/refund action
  regression and existing all-day/availability/training-visibility tests.
- Both release web builds passed through the corrected root build command;
  Customer/Captain plugin registries and admin packaging passed its checks.
- Corrected `pnpm preview` served Customer/Captain Flutter, admin and landing
  routes with HTTP 200. Both fresh release builds opened with their designed
  welcome/language screens in the in-app browser; the hosted startup screens were
  also inspected. This was anonymous startup inspection, not another end-to-end
  booking, payment or device acceptance. This task does not publish or push.
- Portable iOS tooling/native source-configuration checks passed for both apps.
  No Xcode project, signing setting, bundle ID or native dependency was changed.
- The updated 14-page Aman/Claude PDF was rendered and checked; it includes the
  admin link, current workspaces and explicit design reference/removal instructions.
- No Cloud Functions/rules behavior was changed, so the previous 121-test backend
  result was not counted as a new run in this frontend cleanup.

The gallery comparison covers authored English sample states and the selected
viewport. It cannot prove all combinations of live server data, long names,
translations, keyboard/safe-area behavior, native permissions, camera, location,
notifications or Razorpay native checkout. Real data can change text and enabled
choices while the layout stays the same. The existing iPhone guide remains the
physical acceptance checklist. If an installed build still differs, record its
source commit, app, screen/state and screenshot before changing the design.

Only build `apps/flutter/customer/ios/Runner.xcworkspace` and
`apps/flutter/captain/ios/Runner.xcworkspace` on the Mac. Do not recover the removed
apps as alternate build targets. Android remains deferred until requested.
