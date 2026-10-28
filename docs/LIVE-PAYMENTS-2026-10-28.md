# Live-payment request and credit-card checkout restriction — 28 October 2026

The owner explicitly requested real payments, superseding the earlier instruction
to remain in test mode. The owner then clarified: **block the credit-card checkout
option only**. UPI remains allowed, including a credit card linked inside a UPI
app. Do not silently broaden this into a ban on credit-funded UPI.

## Actual deployment state at this handoff

**Payments remain test mode. The live cutover has not been executed.** Firebase
publishing rejected the expired `ajay@trustkeyper.com` CLI login. A new Firebase
CLI remote sign-in was started, but the owner requested it in the other Ajay
Chrome profile. Computer Use then stopped because it could not verify the
current Windows browser URL confidently enough to enforce policy. Do not claim
this source change is published or that a real payment/refund passed.

The separate WashKrew live keys and signed webhook installed earlier remain in
place. No key was regenerated and no live charge, refund or payout was executed.
Historical orders, refund credentials and the Trustkeyper merchant were not
modified.

## Prepared source changes

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

A **WashKrew No Credit** custom configuration was prepared. A **Debit cards**
custom block was added, its Card Type filter selected, Debit enabled and Credit
disabled, and that filter's **Save** button used. The configuration editor still
has unsaved changes: its unrestricted standard Cards block and Wallets block
were not yet disabled, **Save all changes** was not completed, and it was not
set as default. Therefore this draft must not be treated as the effective gateway
configuration or used for live cutover until the following steps are completed.

## Resume steps

1. Finish Firebase CLI sign-in as `ajay@trustkeyper.com` and redeem the displayed
   authorization code through the CLI. Never paste passwords/codes/keys into chat
   or Git. Check the active owner login before retrying deployment.
2. In the separate WashKrew merchant, finish the prepared configuration. Keep UPI
   and netbanking. Keep the custom debit-only Cards block; disable the unrestricted
   standard Cards block, EMI and other credit-based fallbacks. Save all changes,
   make the restricted configuration default and record its real configuration ID.
   Verify the persisted card filter and checkout preview. Do not edit Trustkeyper.
3. Deploy Functions and the rebuilt default Hosting output, then apply the normal
   `configure-api-access` gateway step. The final Customer explanatory wording was
   changed after the last full web build, so rebuild the Customer output first.
   The marketing Hosting site is separate and must not be overwritten.
4. Run `node backend/firebase/operations.cjs configure-live-no-credit REAL_CONFIG_ID`
   only after the gateway restriction is saved and the backend/frontend are
   deployed. Confirm public configuration reports live/WashKrew and the
   checkout-only credit-card policy. Audit the existing private photo-service
   mode gate for live wash operation; do not claim a complete operational launch
   solely from a payment-mode change.
5. Keep real Captain approval, approved content/operations and physical iPhone
   acceptance gates honest. Source changes do not compile/sign an iPhone app.
   Actual live payment and refund acceptance remains to be performed by the owner.

## Verification completed

- Backend/rules/payment suite: **115 passed**, including credit-funded capture
  cancellation, one full refund, no assignment and merchant-safe recovery.
- Focused clarified policy suite: **4 passed**, including permitting credit-linked
  UPI under `no-credit-card-checkout` while rejecting direct credit cards.
- Focused Captain mode-transition regression: **1 passed**; old orders retain test
  mode and new applicants do not become approved/online automatically.
- Shared Firebase Flutter tests: **17 passed**. Customer tests: **16 passed**.
  Customer/shared analyzers passed. Both full release web builds passed before
  the final explanatory wording change. No physical-device pass is claimed.

Provider references: [checkout configuration](https://razorpay.com/docs/payments/dashboard/account-settings/payment-configuration/),
[instrument filtering](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/configure-payment-methods/understand-configuration/),
[card funding details](https://razorpay.com/docs/api/payments/fetch-card-details-payment),
[UPI credit-card funding](https://razorpay.com/docs/payments/payment-methods/upi/cc-on-upi/).
