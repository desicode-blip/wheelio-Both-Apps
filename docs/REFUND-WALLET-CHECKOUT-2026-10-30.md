# Five-minute refunds, wallet credit and payment choice - 30 October 2026

## Owner decisions and original finding

The owner confirmed full original-method cash refund within five minutes, with
used wallet credit restored. After five minutes the fee is **50% of the total
booking value**, including any credit used; the remaining 50% goes to the
WashKrew wallet for another booking. EMI/paylater remain hidden. Credit-linked
UPI is still allowed; the ban is on direct credit-card checkout.

A cancellation sheet, cancellation result, refund tracking, Home credit balance
and Review credit toggle already existed. The live configuration had no wallet
cancellation policy and therefore used the standard original-method refund
path; old design/sample code described a 15-minute free-wash/late-credit rule.
Neither matched the newly confirmed rule. No historical order is retroactively
relabeled. The new policy is a separate snapshot on new bookings.

The separate WashKrew live keys authenticated successfully in a read-only check.
The merchant's public checkout methods response enabled UPI, cards, 44 bank
entries and Airtel Money, Mobikwik, Ola Money and PayZapp wallets. This confirms
advertised merchant capability, not a real charge/refund acceptance result.

## Money and timing

| Customer cancellation | Cash back to original payment method | Wallet return | Fee |
| --- | ---: | ---: | ---: |
| ₹149 cash booking, within five minutes | ₹149 | ₹0 | ₹0 |
| ₹149 cash booking, later | ₹0 | ₹74.50 | ₹74.50 |
| ₹150 booking paid ₹100 cash + ₹50 credit, within five minutes | ₹100 | ₹50 | ₹0 |
| The same mixed booking, later | ₹0 | ₹75 | ₹75 |
| ₹150 fully paid with credit, later | ₹0 | ₹75 | ₹75 |

The window starts at the first successful server booking confirmation (`bookedAt`),
so time spent completing checkout does not consume it. Exactly five minutes is
inside the window; one millisecond later uses the late rule. Duplicate capture
callbacks cannot reset the stored confirmation time. Cancellations still close
when washing begins. Automatic no-capacity/no-show/service-failure cancellations
retain full cash refund plus reserved-credit restoration, without the Customer
cancellation fee. Existing promotional free-wash entitlements are restored rather
than converted into money; no new free wash is awarded by the new policy.

The fee and wallet return sum to the total paid value in integer paise. For an
indivisible paise, wallet return rounds down by at most one paise and the fee is
the remainder. Cash plus credit is not restored in addition to the late return.
Cancellation state, returned balance, capacity release and withdrawn offers are
one Firestore transaction. Repeated/concurrent cancellation returns once. Test
and live wallets remain separate. Provider refunds keep their original merchant,
mode, idempotency and status-recovery path; a queued refund is not shown as bank
credit already received.

## Confirmation and current UI

The existing Review key/value card displays the current policy before paying;
the server requires matching accepted terms before creating a booking under the
new policy. Old clients must update rather than silently acquire an undisclosed
cancellation fee. The existing cancel sheet loads an authenticated owner-only
`getCancellationQuote` and displays exact cash return, wallet return and fee in
its existing banner. Confirm submits the server quote fingerprint. If time or
terms change, the transaction does nothing, refreshes the quote and requires
another explicit confirmation. No automatic fee acceptance or local timer grants
an entitlement. Quote failures can retry through the existing button/error area.

Home already shows credit and Review already applies it using the existing toggle.
Paise are now preserved in balances, previews, payment amounts and refund/results
instead of truncating to whole rupees. A ₹74.50 balance takes ₹74.50 off a ₹149
booking, so Razorpay collects only ₹74.50. Excess balance stays available; a fully
covered booking needs no Razorpay charge. If a partial balance would leave less
than Razorpay's ₹1 minimum, that small credit remainder stays in the wallet.

The existing layouts, styles, assets and controls are reused. New policy copy,
amounts and payment-method data fill those controls; no replacement screen was
drawn. Sample/reference states retain their saved original terms. A separate
wallet activity/withdrawal screen is **not** present: a dedicated activity page
would need Aman's design. Withdrawals were not requested or implemented.

## Razorpay choice

The prior default Google Pay selection preselected UPI and created an app-filtered
block. Runtime checkout now opens the method chooser, exposes unrestricted UPI
apps plus debit-only cards, netbanking and provider wallets, and merely reorders
groups for the selected preference. It never limits all UPI to one app. Credit
cards and EMI/cardless EMI/paylater remain hidden, and server funding checks now
accept provider wallets while still rejecting direct credit cards/unknown card
types and borrowing methods. The stricter historical `no-credit-cards` policy
is unchanged.

For new orders, `checkoutPresentation: allNonCredit` selects documented runtime
configuration instead of pinning the older saved layout. Old configuration IDs,
merchant credentials and existing order snapshots remain intact. Existing
payment-sheet rows are reused for Netbanking and Other wallets. The current
iOS query schemes already cover the supported UPI app families; no native
project/team, dependency or signing identifier is changed.

References: [Razorpay runtime configuration](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/configure-payment-methods/),
[instrument filters](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/configure-payment-methods/understand-configuration),
[iOS UPI setup](https://razorpay.com/docs/payments/payment-gateway/ios-integration/standard/integration-steps/).

## Verification boundaries

Backend tests use isolated demo-wheelio data and explicit provider adapters;
widget tests use isolated quote/request outcomes and the actual shipped Roboto
fonts. No test Captain, booking, wallet credit, live charge/refund or approval is
created in production. No new service, app sample button or timer is introduced.

Computer Use stopped dashboard inspection because it could not confidently
identify the current browser URL. No further Windows app input was attempted
after that stop. The saved Razorpay dashboard layout has not been inspected or
changed in this follow-up. Source/emulator checks and read-only merchant APIs
do not establish physical iPhone payment switching or real bank/refund delivery.
The owner will open the signed-in dashboard; any later inspection needs a valid
browser observation. Aman still provides the APNs key separately.

## Completed checks and publication

- **138 backend/rules tests passed**, zero failures/skips, using only the
  demo-wheelio Auth/Firestore/Storage emulators. New cases cover boundary
  confirmation, disclosure before booking, cash/mixed/wallet-only returns,
  duplicate cancellation, capacity/Captain release, service-failure restoration,
  historical snapshots and permitted provider-wallet capture. The simulated
  Captain heartbeat was refreshed before dispatch after the seven-minute test
  checkout; no real eligibility/offer deadline was extended or weakened.
- **70 Flutter tests passed** (Customer 39, Captain 10, shared Firebase 21), and
  all four analyses passed. The eight new money/quote/widget cases cover paise,
  partial/full credit and ₹1 minimum, the existing credit toggle and policy row,
  six method-choice rows, explicit reconfirmation and retry, and a wallet-only
  service-failure result that avoids fictitious bank-refund tracking.
- Both clean **release web builds passed**. The served Customer/Captain bundles
  and admin module match their verified local SHA-256 values. Hosting release
  version `4fe56de24040da76` published 30 October 2026 at 12:42:15 UTC.
- Published the eleven affected/new Functions, including payment capture/
  reconciliation paths and `getCancellationQuote`. The first creation's final
  invoker-IAM step failed under the existing project restriction; the documented
  `operations.cjs configure-api-access` step completed afterward. Live read-back
  confirms all eleven functions ACTIVE, min **0**, max **5**, 256 MiB, and the
  quote HTTP gateway configured as intended. Application authentication remains
  mandatory: unsigned quote, cancellation, booking/checkout, claim and reviewer
  calls return **401**. Organization sharing policy was preserved.
- After checking that the new Customer build was actually served, applied only
  the new future-booking cancellation policy and checkout-presentation field
  through the narrow owner commands. Read-back confirms LIVE / WashKrew /
  `no-credit-card-checkout`, `refundThenCredit` / five minutes / 5000 basis points,
  `allNonCredit`, archived checkout ID preserved, training hidden/nonrequired.
  No existing booking, balance, approval, price, society, merchant key or refund
  record was rewritten. No real charge/refund was created as a test.
- Public availability still returns all nine **4 AM-10 PM** windows. Captain
  source, native projects, shared widget layouts, design tokens, fonts and brand
  assets remain unchanged. Shared formatter and Customer data/controller/copy
  changes implement the monetary behavior; this is not a new pixel-audit claim.

Safe results, runtime/release metadata and hashes:
[checks.json](../output/refund-wallet-2026-10-30/checks.json).
The saved merchant dashboard layout was not changed; new checkouts select
documented runtime configuration instead of pinning it. Physical iPhone method
switching and an actual live charge/refund remain acceptance checks. The source
must reach staging and be rebuilt on the Mac before Aman's installed app receives
the changes. The older PDF is superseded for these financial terms by this report
and the updated Markdown iPhone guide.
