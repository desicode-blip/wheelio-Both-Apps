# Current project status - 3 November 2026

The current source is the latest washkrew.com website and the two Flutter
Customer/Captain apps for Android/iOS, plus their shared packages, Firebase
backend, private photo service, human-review admin, build tools and tests.
Read [AGENTS.md](../AGENTS.md) before editing; keep approved designs unchanged.

## Implemented and checked

- Phone accounts, private document upload/review, map-radius Captain coverage,
  continuous whole-window work-hour/capacity matching, Online and atomic claims.
- Separate WashKrew LIVE checkout, wallet balances/captured top-ups/spending,
  exact server cancellation quotes and walletByTime/service-failure credit.
- Guided wash capture/uploads, private checks, server progress restoration,
  Customer review/rating and Captain earnings ledger. No automatic bank payout.
- Two-confirmation role-specific deletion without a new deletion OTP; resumable
  cleanup, truthful error handling and preserved open-job/payment/balance guards.
- The latest functional release passed **196 backend tests**, **172 Flutter tests**
  and static/native configuration checks. The deletion backend is deployed;
  [its report](ACCOUNT-DELETION-2026-11-03.md) records exact runtime/source evidence.
- The owner confirmed the prior updated Android apps work. Current source versions
  Customer **1.0.3 (4)** / Captain **1.0.4 (5)** include the newer deletion UI;
  earlier installed Play builds do not automatically receive it.

## Remaining human/device acceptance

Aman must build/install both current apps on his Mac/iPhone and record physical
camera/Photos/GPS/APNs, payment-app switching, role flow and deletion results.
Use [the current handoff](AMAN-IOS-HANDOFF-2026-11-02.md),
[Claude prompt](AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md) and
[results template](IOS-ACCEPTANCE-RESULTS-TEMPLATE.md). APNs credentials are already
configured; signed capabilities/device delivery still require observation.
Native Firebase secure fallback must not be disabled to claim a pass.

Genuine Captain identity/payout reviews, disputes and payout transfers remain
human operations. Aman supplies approved legal/support/commercial content and
store/provider requirements; never invent missing values. Training/quiz/videos
remain hidden/not required. DigiLocker, WhatsApp Business, masked calling and
voice OTP remain deferred, not secretly simulated as working features.
New bookings use wallet cancellation policy; historical source-refund obligations
still require their original provider/funding reconciliation.

Repository cleanup removes duplicate/retired source and stale guides only; it
never deletes deployed databases, merchant setup or live user data. See
[the cleanup record](REPOSITORY-CLEANUP-2026-11-03.md). No new native or payment
acceptance is implied by that cleanup.
