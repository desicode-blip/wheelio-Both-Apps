# Remaining checks and existing live records - 30 October 2026

## Software and publication baseline

Current tested application source is **cedd9ab**, on top of Aman's **79d17af**
and the startup/preload follow-ups. Read
[the policy/implementation report](REFUND-WALLET-CHECKOUT-2026-10-30.md) for
138 backend/rules tests, 70 Flutter tests, four analyses, both release web builds,
Functions publication, authenticated quote/cancel gates and Hosting hashes.
This follow-up changes only safe evidence and documentation; no app UI, asset,
font, native project, dependency, public business input or production record is
changed. The native configuration check passed for both source trees again.

The current handoff is [the 30 October guide](AMAN-IOS-BUILD-AND-TEST-2026-10-30.md)
and [its eight-page PDF](../output/pdf/WashKrew-Aman-iPhone-Acceptance-2026-10-30.pdf).
It supersedes earlier PDFs, preserves Aman's UI/native work and paid team
**28JNT7H8KA**, and adds current cancellation/credit/payment-choice acceptance.
All physical cases remain NOT RUN until actual device evidence is recorded.

## Existing live payment/refund match

Read-only owner Firestore queries selected financial/status fields, not KYC,
customer names, phone numbers or private media. The separate WashKrew live keys
were read from Secret Manager into memory; they and raw provider IDs were never
written to the report. Provider checks used **GET only**. No booking, payment,
refund, Captain approval, balance adjustment or production fixture was created.
Reference hashes in the safe JSON do not expose booking/payment IDs.

| Existing record | Read-back evidence |
| --- | --- |
| INR 149 UPI booking, created 29 October | Original capture and provider order/amount match. Provider now says refunded; exactly one INR 149 refund is processed. Stored refund ID/amount/status agree with Firebase. |
| INR 149 UPI booking, created 30 October | Original capture and provider order/amount match. Booking cancelled under its saved full-refund policy. Firebase shows delayed/retry; provider has no refund yet. Last rejection is HTTP 400 BAD_REQUEST_ERROR. |

These bookings predate the new refundThenCredit policy and keep `kind:refund`.
They are not proof of new five-minute or wallet acceptance, other payment methods,
bank credit, completed real washes or physical iPhone success.

The aggregate read-back found two Captains: one approved and Online in live mode,
one not submitted. This does not independently prove heartbeat freshness,
time/coverage matching or full live job completion. Three societies are active.
No real Captain was approved as a test.

Safe selected evidence: [live-record-audit.json](../output/remaining-checks-2026-10-30/live-record-audit.json).

## Outstanding refund: merchant funding

The signed-in separate WashKrew LIVE Razorpay dashboard is accessible again.
Under Account & Settings -> Balances, it showed:

| Read-only observation | INR |
| --- | ---: |
| Current balance | 141.96 |
| Reserve balance | 0.00 |
| Refund credits, under Credits | 0.00 |
| Existing full refund owed | 149.00 |
| Current shortfall | 7.04 |

Razorpay [documents](https://razorpay.com/docs/payments/dashboard/account-settings/balances/)
that available balance funds refunds and that reserve balance covers shortfalls.
Its [refund FAQ](https://razorpay.com/docs/payments/refunds/faqs/) says insufficient
balance can be resolved with further receipts or adding funds. Fees/taxes on an
original capture are not returned. The shortfall is therefore an operational
blocker consistent with the rejection; the generic 400 response does not prove
that funding is its only possible cause.

The owner confirmed **Aman will add reserve funds**; this is a plan, not evidence
that funding is complete. Use [Aman's short funding guide](AMAN-RAZORPAY-ADD-FUNDS-2026-10-30.md)
and [its one-page PDF](../output/pdf/WashKrew-Aman-Add-Refund-Funds-2026-10-30.pdf).
The top-up uses the registered settlement bank account. No bank/UPI authorization, manual
refund or withdrawal was initiated. The existing scheduled idempotent retry
remains in place. Do not start a second manual refund, reduce the amount owed,
retroactively apply the new 50% rule or replace this old cash obligation with
wallet credit. After balance reflects, read the existing payment/refund and
Firebase again; close only when provider processed status matches. Actual bank
credit still needs confirmation from the payee.

## Checkout dashboard inspection

Inspected the saved default **WashKrew No Credit** configuration
`config_TtDpJ7HJM4hHb2`: the existing custom Debit cards block is present,
UPI/netbanking are on, and general Cards/EMI are off. No dashboard configuration
was edited or saved. That historical ID stays intact on old bookings. Current
new orders use `checkoutPresentation:allNonCredit`, no saved-layout ID and the
explicit runtime UPI/debit/netbanking/provider-wallet groups. Runtime integration
is covered by tests; the actual current iPhone chooser and method-specific bank
completion are still acceptance checks. Available methods may vary with device,
installed apps, amount and provider eligibility.

## Remaining external and physical gates

1. **Merchant funding / pending refund:** add funds as above; verify recovery and
   human bank credit. The outstanding obligation is not marked resolved.
2. **Apple push key:** no `.p8` was found in Downloads, Documents or the usual
   transfer folder. Aman privately provides the paid-team key/Key ID and both
   app/environment permissions; Ajay's side configures Firebase. Do not upload
   it to Git or ask Aman to configure Firebase. Then verify real APNs delivery
   in each signed app, including notification taps and background/locked states.
3. **Mac/iPhone:** build/sign/install both apps and run the ordered guide. Check
   camera/Photos/GPS, exact hours/breaks, offers, wash photos/tracking, receipt,
   payment app switching and new early/late/mixed/full-wallet cases. Rebuild the
   older Customer binary so it can acknowledge the new terms.
4. **Approved business content:** server `support`/`legal` configuration is still
   absent. Aman supplies the operating legal entity, approved support phone,
   email/hours, terms/privacy page and any outstanding commercial/service inputs.
   Do not infer approval from a website's placeholder copy or merchant profile.
5. **Human operations:** real KYC approvals, dispute decisions, bank payout
   transfers and any Apple company-seller enrollment remain human decisions.

Paid minimum instances remain **off**; the owner-selected startup optimizations
do not add an idle monthly baseline. Actual first-slot timing is a device/network
measurement, not a guaranteed latency. Training remains hidden/not required.
Deferred DigiLocker/WhatsApp Business/masked calls/voice OTP stay deferred.

The app is ready for the current Mac build and ordered acceptance; it is not
certified as fully launch-accepted while these gates remain open.
