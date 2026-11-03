# Current production bundles with the paid-booking AI toggle

3 November 2026. Customer 1.0.4 (8) / Captain 1.0.5 (9) supersede the earlier
popup/consent bundles. Both built from clean source **62cfabf30a3c04f070f294ea9ada8273e7bb2dd7**.
The checkout popup is removed; the Customer toggles AI after payment. Captain
ON offers Check with AI / Send without AI; OFF sends directly to Customer review.

| Bundle | Bytes | SHA-256 |
| --- | --- | --- |
| WashKrew-Customer-1.0.4-8.aab | 52698940 | `d4e646612f35dfd71dcf7f3e8d8be37b7bfd4e6ea84e83f5af87bd67cabb5c43` |
| WashKrew-Captain-1.0.5-9.aab | 54248965 | `ea6cfa673f557179a67c63ccdde46b56da6ba30da42eaa1a833b9b45f6432f2b` |

Both bundles passed official bundletool validation, existing upload-certificate
signature verification, exact package/version/API 36, all three complete ABIs,
64-bit ELF LOAD alignment, PAGE_ALIGNMENT_16K, non-debug/backup settings and R8
mapping checks. Exact mappings and JSON provenance accompany them under
`build/store/android/`. Forward the generated handoff ZIP separately from Git:
`build/store/WashKrew-Android-Store-Toggle-2026-11-03.zip`.

Backend evidence: all five relevant functions ACTIVE, minInstances 0, anonymous
HTTP 401. Downloaded deployed source matches all six tested toggle/service/photo/
authorization modules. The CLI's new-function invoker-policy error was recovered
using the existing approved HTTP gateway setup; organization restrictions and
application authentication remain intact. No production account, paid booking,
real photo inference or person approval was created as a QA fixture.

208 backend tests and 184 Flutter tests passed (Customer 79, Captain 40, shared UI
9, shared Firebase 56), and all four package analyses passed. Tests cover owner/
payment/stage gates, stale ON replay, OFF before/after dispatch and OFF/ON during
inference, cached results/rate limits, direct evidence submission and Customer
approval/earnings. Native iOS source checks pass; actual Xcode export/physical
acceptance remains a Mac task. These AABs were not uploaded to Play or installed
on a phone during this task.

The source and guides are committed locally for the next requested staging push.
Public policies, store screenshots/disclosures/rating and private reviewer access
remain separate submission gates. See AI-PHOTO-TOGGLE-2026-11-03.md,
STORE-RELEASE-2026-11-03.md and AMAN-CLAUDE-STORE-PUBLISH-2026-11-03.md.
