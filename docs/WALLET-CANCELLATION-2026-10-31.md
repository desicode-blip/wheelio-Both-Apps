# Wallet cancellation and two-hour cutoff - 31 October 2026

This is the current owner-confirmed policy for **new bookings**. It supersedes
the 30 October cancellation examples in older reports and iPhone PDFs. Source
starts from staging **f786dfa**, retaining Aman's UI/native work through 79d17af.
Record the actual source commit after pulling; a native installation must be
rebuilt to receive the changes.

## Confirmed rules

| Event | Wallet credit | Amount retained | Bank refund |
| --- | ---: | ---: | --- |
| Customer cancels within five minutes of first server booking confirmation | 100% of cash plus wallet used | Zero | None |
| After five minutes, at least two hours before the confirmed wash window starts | 50% of cash plus wallet used | 50% | None |
| After five minutes, less than two hours before that window | Zero | 100% | None |
| WashKrew cannot provide the wash / no Captain / no-show | Full eligible value | Zero fee | None |
| A human review upholds a wash problem | Full eligible value | Zero fee | None |

The owner explicitly confirmed that **five-minute grace takes priority**, even
for a booking less than two hours away. Exactly five minutes remains full credit;
exactly two hours before the window remains half credit. Once the Captain starts
washing, Customer self-cancellation stays closed. Service failures and human
review do not use the Customer late-cancellation penalty.

For INR 149: early credit is INR 149; the middle band returns INR 74.50 and
retains INR 74.50; the last band returns zero and retains INR 149. A booking
worth INR 150 paid with INR 100 through Razorpay and INR 50 wallet returns INR
150, INR 75 or zero respectively. Used wallet credit is never restored again
on top of that total. Odd paise round the half-credit return down by at most
one paise; the retained remainder balances to the total.

Credit is usable for future bookings. It is not a bank transfer or withdrawal.
Existing promotional free-wash entitlements are restored rather than converted
to money or multiplied. No new free wash is awarded by cancelling.

## Timing, authorization and accounting

The new snapshot is `walletByTime`, with `creditMinutes:5`, `cutoffMinutes:120`,
`lateCreditBps:5000`, `serviceFailure:wallet`. The first successful server
confirmation supplies `bookedAt`; duplicate captures cannot reset grace. The
two-hour cutoff uses the **server-confirmed wash-window start**, including the
current reserved window for flexible/multiple-window choices. It does not use
the phone clock, the Captain's changing ETA or the later actual washing time.
A legitimate server window move changes the applicable cutoff. A booking's
saved financial policy is never replaced with the latest global policy.

Creation requires acknowledged matching terms. Owner-only `getCancellationQuote`
returns exact wallet credit, retained fee, phase and server deadlines. The same
quote is recomputed at a single server timestamp inside cancellation's Firestore
transaction. If crossing grace/cutoff changes the amounts, the old confirmation
does nothing; the existing sheet refreshes and requires another confirmation.

Booking cancellation, mode-specific wallet return, reserved capacity release,
offer withdrawal and Captain active-job count update commit together. Repeated
or concurrent calls cannot return value twice. The same wallet balance pays for
the next booking. Paise survive preview, checkout, server storage and display.
Fully covered bookings need no Razorpay order; partial credit leaves at least
INR 1 cash when an external payment is needed, preserving any tiny unused credit.

Service failures return full wallet value through the same transaction paths:
capacity lost at capture, late capture of an unbookable checkout, expired/no-show
bookings, and human-upheld problems. If an unpaid checkout was already cancelled
and reserved credit restored, later capture returns **only the newly captured
cash** as credit. It cannot restore the same used credit twice. Human-upheld
problems still void the earning; only an explicit human bonus adds free washes.
An existing cash-refund record prevents a second wallet award for that obligation.

## Existing UI used

| Existing authored area | Connected behavior |
| --- | --- |
| Review card (C13) | Discloses 100% / 50% / zero-credit terms before payment; existing credit toggle applies the balance. |
| Cancel sheet (C29) | Shows actual server amount, fee, credit deadline and no-bank-refund copy; existing confirmation/retry/error controls remain. Zero credit uses the existing caution tone. |
| Cancelled result | Uses the existing full-state layout for full, half and zero returns. No fictional bank-refund tracking action appears. |
| Home / booking history | Existing balance and history values distinguish wallet credit from money sent to a bank. |
| No-Captain/no-show state | Existing card shows actual full wallet return; existing secondary action goes Home. |
| Dispute decision | Existing key/value row shows wallet return; Book again replaces a free-wash promise when no bonus was awarded. |
| Help / booked / delayed / inbox copy | Uses the applicable wallet terms and does not invent a bank refund when an order update is still arriving. |
| Existing receipt | Existing final two rows show actual wallet return and fee for wallet outcomes; historical cash-refund receipt rows remain. |

No screen, navigation tab, new wallet-history page, withdrawal control, palette,
asset, typography system or layout component was invented. The existing controls
support the requested flow, so no missing UI required owner design approval.
Shared authored layouts/tokens/fonts/brand, both native projects and Captain
source remain unchanged. Captain job state and cancellation notices are updated
by the server. This is a targeted functional/copy audit, not a new whole-app
pixel-equality or physical-iPhone claim.

Local fixture renders under `output/wallet-by-time-2026-10-31/screens/` show the
actual existing widgets at 390 x 844 with the shipped Roboto and icon fonts.
The Review render is scrolled to the policy row. Cancel-sheet underlays are
isolated test launchers, not a production screen. These images use fictional
widget data and test futures, never a real account, payment, approval or KYC.

## Historical and gateway obligations

Existing orders retain their original merchant, mode and saved terms. The
previously identified INR 149 source-refund obligation is **not** converted to
wallet credit by this update. Original-method refund workers/reconciliation stay
enabled. Also, captured prohibited credit-card/borrowing funding is returned to
its source rather than turned into spendable credit that bypasses the funding
ban. Amount/order/currency/signature checks still apply before any credit award.

Normal new-policy cancellations/service failures do not need Razorpay refund
balance. This does not remove historical source refunds, prohibited-funding
refunds or bank/network reversals. See
[Razorpay's refund model](https://razorpay.com/docs/payments/refunds/) for the
separate gateway process. Do not start an extra manual refund alongside a retry.

## Verification and publication

The full backend/rules suite passes **152 tests**, zero failures/skips, against
demo-wheelio Auth/Firestore/Storage emulators only. New tests cover inclusive
boundaries, near-term grace, cash/mixed/all-wallet accounting, stale confirmations,
concurrent calls, authorization, capacity/offer/Captain release, reuse on a next
booking, full service-failure recovery, late capture after credit was restored,
human-upheld review, funding rejection and historical obligations.

The Flutter suite passes **79 tests** (Customer 48, Captain 10, shared Firebase
21). Four analyses pass. Nine targeted UI cases additionally exercise and render
the new live outcomes with existing controls. No production fixture or real
charge/refund was created for these checks. The existing STANDARD / FIRESTORE_NATIVE
database in asia-south1 was reverified; no database was created or migrated.

Final release build, publication and selected safe read-back are recorded in
[checks.json](../output/wallet-by-time-2026-10-31/checks.json). All 13 affected
Functions are ACTIVE. The final Hosting release is `c97cfe740dc17d24`, published
31 October at **18:22 IST**; all 135 user-managed files match the final release
build. Firebase's two platform-generated initialization files are recorded
separately. Future policy was activated after that verified publication and
read back as the exact owner-confirmed snapshot above. Unauthenticated booking,
cancellation, claim and reviewer calls return 401; public availability returns
the nine windows from 4 AM to 10 PM. Min instances stay zero, max stays five;
organization policy and application authentication remain intact. The separate
website is preserved.

A manual guest check of the published Customer app opened the existing Help
screen and expanded both cancellation and no-Captain questions. The rendered
copy matches the active 100% / 50% / zero rules, near-term five-minute grace,
future-booking credit and full service-failure credit. This check did not create
a production booking or establish a new real-money or native acceptance result.

## iPhone acceptance next

Use the 30 October guide for Mac build commands, paid team **28JNT7H8KA**, bundle
IDs and role order. Use **this document's financial cases** instead of the older
PDF's original-method cancellation examples. Rebuild Customer from current
source: old native clients cannot acknowledge the new terms. Do not globally
switch payments to test or seed fake production Captains to test a native build.

On the phone, verify the current term display, actual full/half/zero wallet
outcomes, deadline reconfirmation, service-failure return, exact Home balance,
credit toggle and next-booking payment. Real charges are human-authorized only.
Record PASS/FAIL/BLOCKED using the updated acceptance template. Xcode signing,
physical camera/GPS, payment-app switching, APNs and approved business content
remain their existing acceptance/input gates; these tests do not close them.
