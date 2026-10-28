# Live-payment request and credit-card checkout restriction — 28 October 2026

The owner explicitly requested real payments, superseding the earlier instruction
to remain in test mode. The owner then clarified: **block the credit-card checkout
option only**. UPI remains allowed, including a credit card linked inside a UPI
app. Do not silently broaden this into a ban on credit-funded UPI.

## Actual deployment state at this handoff

**New bookings now use live payments through the separate WashKrew merchant.**
Firebase CLI authentication as `ajay@trustkeyper.com` succeeded in the connected
Ajay Chrome profile; project access was verified. Functions and default Hosting
were deployed successfully, including the final rebuilt Customer wording. The
normal `configure-api-access` step completed with application authentication and
webhook signatures still enforced. The marketing Hosting site was not overwritten.

The owner-only cutover command succeeded using the actual saved gateway ID.
Public configuration was verified as `paymentMode: live`, `paymentMerchant:
washkrew`, `paymentPolicy: no-credit-card-checkout`, `checkoutConfigId:
config_TtDpJ7HJM4hHb2`. Existing prices, societies, bookingsEnabled and approvals
were preserved. **No actual live charge, refund or payout acceptance was performed.**

The separate WashKrew live keys and signed webhook installed earlier remain in
place. No key was regenerated and no live charge, refund or payout was executed.
Historical orders, refund credentials and the Trustkeyper merchant were not
modified.

## Deployed source changes

- Shared Flutter checkout now filters card instruments to `types: ['debit']`,
  hides credit-card/EMI/pay-later options and turns off unrestricted default
  payment blocks. UPI and netbanking remain available. Both browser and native
  Razorpay use this shared configuration. The Customer's existing card row now
  says **Debit card**; its layout/style was preserved.
- The server snapshots a payment policy and merchant checkout configuration ID
  on each new booking, pins `checkout_config_id` on the provider-created order,
  and returns it to checkout. Funding validation uses fetched provider data,
  including the actual card type, rather than trusting the selected client label.
- `no-credit-card-checkout` permits UPI, debit cards and netbanking, matching the
  owner's clarified instruction. Direct credit cards and unverifiable card types
  cannot create a dispatchable paid booking. A captured unsupported payment is
  cancelled and queued once for a full refund using its original merchant. The
  existing Customer state component explains that outcome and links to refund
  status. These recovery checks supplement gateway filtering; they are not a
  claim that no unsupported payment can ever be captured by Razorpay.
- Historical records without the new policy keep their original reconciliation
  and refund behavior. The stricter `no-credit-cards` policy is separately tested
  but **is not the owner's selected live policy**.
- An unapproved Captain's resubmission adopts the current payment mode while
  remaining unapproved/offline and under human review. It does not relabel old
  bookings or promote test Captains automatically.
- Owner-only `configure-live-no-credit CHECKOUT_CONFIG_ID` verifies separate
  live credentials and the active signed webhook, then atomically updates only
  payment mode, merchant, payment policy and configuration ID. It preserves
  existing prices, approvals, societies and other settings. Do not use a made-up
  configuration ID.

## Razorpay dashboard work

The connected Sumit Chrome session was switched from the old Trustkeyper merchant
to the separate WashKrew merchant `acc_TstvPkGgqw80X4`, showing the WashKrew payment
handle. Cards, netbanking and UPI are activated there.

A **WashKrew No Credit** custom configuration is saved as the merchant's
**Default**, ID `config_TtDpJ7HJM4hHb2`. Its **Debit cards** custom block has
Debit enabled and Credit disabled; the persisted filter was reopened and checked.
UPI and netbanking are enabled. Unrestricted standard Cards, EMI and Wallets are
disabled. The default confirmation and **Save all changes** were completed, and
the saved configuration list displayed **Default**. No Trustkeyper configuration
was edited. The dashboard preview was not taken through a live transaction.

## Remaining acceptance and operations

1. Production read-only aggregation found **0 approved test Captains and 0
   approved live Captains**. Real applicants must complete genuine training and
   human identity/payout/society review in `/admin/`; no fabricated capacity or
   approval was added. Unapproved resubmission adopts current live mode.
2. Private photo settings remain `enabled: true`, `aiEnabled: true`,
   `paymentMode: test`. Payment cutover did not silently authorize live biometric
   or image-processing acceptance. Complete consenting physical camera/selfie/
   photo tests, operational review and approved processing policies, then have
   the owner explicitly activate the photo service for live mode. The current
   live identity step will explain the missing mode setup; do not fake it or
   bypass the flow to claim device acceptance.
3. Aman still needs to provide approved training, legal/support content and
   commercial/coverage confirmation. Placeholder designs cannot award training.
4. Build/sign/install on the Mac and test actual SMS, camera permission recovery,
   Razorpay/UPI app switching, assignment, private photos, foreground GPS and APNs.
   Source/web checks do not prove native compilation or device success.
5. The owner must perform actual live debit/UPI checkout and refund acceptance
   after operational readiness. No real financial transaction was executed here.

## Verification completed

- Backend/rules/payment suite: **115 passed**, including credit-funded capture
  cancellation, one full refund, no assignment and merchant-safe recovery.
- Focused clarified policy suite: **4 passed**, including permitting credit-linked
  UPI under `no-credit-card-checkout` while rejecting direct credit cards.
- Focused Captain mode-transition regression: **1 passed**; old orders retain test
  mode and new applicants do not become approved/online automatically.
- Shared Firebase Flutter tests: **17 passed**. Customer tests: **16 passed**.
  Customer/shared analyzers passed. Both full release web builds passed, and the
  final Customer explanatory wording was rebuilt successfully before publishing.
- Production verification: `/app/`, `/captain/`, `/admin/` and its module return
  200; the three admin callables, createBooking and verifyPayment reject anonymous
  calls with 401/UNAUTHENTICATED. Private Captain evidence and an invalid live
  webhook signature return 401. Live catalog/merchant/policy/configuration ID
  matched the intended cutover. No physical-device or live transaction pass is claimed.

Provider references: [checkout configuration](https://razorpay.com/docs/payments/dashboard/account-settings/payment-configuration/),
[instrument filtering](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/configure-payment-methods/understand-configuration/),
[card funding details](https://razorpay.com/docs/api/payments/fetch-card-details-payment),
[UPI credit-card funding](https://razorpay.com/docs/payments/payment-methods/upi/cc-on-upi/).
