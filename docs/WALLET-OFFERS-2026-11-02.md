# Wallet top-ups and immediate Captain offers — 2 November 2026

The owner reported a completed live payment followed by a delayed Captain alert
and a misleading **Job went to someone else** state. The owner also explicitly
authorized a Home wallet entry, balance/top-up screen, and wallet/Razorpay payment
choices. These are scoped UI exceptions; existing unrelated af036f0 designs stay.

## Reported behavior and correction

A read-only inspection of the dedicated Customer's latest booking found a captured
payment, cancellation and **no assigned Captain**. Its offer was withdrawn. Offer
documents are renewed in place, so their latest creation time does not establish
the first-alert latency. The app independently used the authored Job missed title
after timeout, which incorrectly implied another Captain accepted.

- Payment settlement now reads eligible Captains and commits their coarse offers
  in the **same transaction** as the captured booking and capacity reservation.
  It does not wait for another cold dispatch trigger, a five-minute scheduler,
  or a 60-second heartbeat. Existing Firestore listeners receive the new offers.
- All eligible online, approved Captains whose area, mode, fresh heartbeat and
  entire saved work period match can receive the offer. Captains already holding
  overlapping capacity cannot be promised another job. Exact parking, plate,
  Customer identity and media remain private until a Captain wins assignment.
- The claim transaction rechecks eligibility and capacity, writes one Captain,
  and marks other offers withdrawn with the actual assigned reason. Retry by
  the same winning Captain is idempotent and does not increment active jobs twice.
- Captain root tabs react to incoming offers immediately, rather than depending
  only on the Home view's logic. Existing live alerts update renewed expiry times.
  Expired, cancelled and actually taken offers have distinct truthful copy in the
  existing missed-state layout. No timeout invents an assignment.
- Offer and Captain-profile snapshots may arrive in either order. The client now
  caches offer records independently and re-evaluates them when the profile's
  payment mode arrives. It no longer drops an initial live offer while temporarily
  assuming test mode. Two focused delivery-order/renewal tests and all three
  outcome widget cases passed; Captain static analysis remains clean.
- No extra paid warm instance is enabled. Network, payment provider and Firebase
  startup still exist; no absolute zero-latency guarantee is made.

## Wallet and top-up contract

- Home shows the current wallet balance beside Notifications, opening **Your
  wallet**. Existing design components/tokens are used. Balance remains the
  authenticated, mode-separated server `wallets/{uid}_{test|live}` snapshot.
- Review offers **Pay by wallet** or **Pay via Razorpay**. Wallet must cover the
  entire wash price; insufficient funds open the top-up screen with the shortfall
  (minimum provider charge ₹1). Gateway choice pays the full price without silently
  using wallet credit. Existing free-wash booking remains available. After checkout
  login the user returns to Review to make this explicit payment choice.
- Top-ups accept integer paise, ₹1–₹10,000 per request (technical request guard),
  through the existing separate WashKrew merchant and existing native/web Razorpay
  checkout. All allowed non-credit methods remain available. Credit equals its
  INR amount, for WashKrew washes only, with no transfer/withdrawal action.
- `createWalletTopup` prepares an idempotent server record/provider order.
  `verifyWalletTopup` verifies the signature and fetches payment; `checkWalletTopup`
  reconciles lost/dismissed callbacks. Existing signed webhooks and scheduler also
  reconcile top-ups. The **captured provider record**, amount, currency, merchant,
  mode, ownership and funding policy must match before atomic balance credit.
- Replayed callbacks/webhooks cannot double credit. Unpaid/dismissed/failed SDK
  results do not add credit. Only one unexpired pending top-up is created per
  Customer. The wallet shows recent top-ups with check/continue controls so an
  interrupted payment can resume with its original provider order.
- Top-up records are separate from wash bookings and never dispatch Captains.
  Historical booking/refund records keep their original provider/mode. Prohibited
  card/borrowing funding receives no spendable credit and uses the existing
  idempotent source-refund operations. Captures after Customer role deletion are
  also returned to source rather than issuing credit to a removed account.
  Account deletion is blocked while a top-up is pending or previously funded live
  credit remains, so purchased credit is not silently discarded. Existing Captain
  role deletion remains independent of Customer wallet access.
- Existing new-booking cancellation rules are unchanged: full/half/zero wallet
  credit by the saved five-minute/two-hour policy; service failure is full credit.
  Used wallet value is not restored twice.

No private key, phone number, UID, precise location, KYC or raw payment payload
belongs in this report or Git. Test payment captures use only the isolated
`demo-wheelio` project and fake provider. Live UI tests must not click a final
financial confirmation or spend the user's credit without a deliberate user action.

## Release / acceptance record

Customer **1.0.1 (2)** from `ebd79f9` was uploaded and published to its existing
internal track on 2 November at **12:48 IST**. The connected phone updated from
Play at **13:02:27 IST**, preserving login and matching the registered Play signing
certificate. The owner subsequently completed a booking and payment himself;
the agent did not submit that charge. Post-fix end-to-end timing was not measured
because the owner was operating the phone during that attempt.

This later wallet/offer update targets Customer **1.0.2 (3)** and Captain **1.0.1
(2)**. Automated checks, publication and native results will be recorded below.

### Local verification

- Full Auth/Firestore/Storage emulator suite: **188 passed, 0 failed**. This
  includes atomic fan-out to two area Captains without societies, concurrent
  first-acceptance wins, idempotent winning claim, expiry without assignment,
  renewal, full-wallet/insufficient-wallet choices, verified top-ups, duplicated
  callback/webhook races, lost-callback reconciliation, blocked funding, source
  refunds and Customer deletion safeguards.
- Customer: **72 tests passed**. Captain: **20 passed**, including truthful
  expired/cancelled/taken screens. Shared Firebase: **33 passed**. Customer,
  Captain and shared Firebase static analysis passed.
- Final wallet screen and checkout controls were rendered at phone widths using
  actual shared fonts/components. The local render fixture initializes no Firebase
  or real payment SDK. Additional final widget checks passed; raw images stay in
  ignored `.cache/wallet-offers-ui/`.
- Deployment preflight found the existing 62 ACTIVE functions plus exactly the
  three authorized top-up callables, with **no function deletion** proposed. It
  recorded hashes of all six affected shared backend modules for deployed-source
  comparison. No application identifiers, signing key or minimum instances changed.

Publication and device acceptance for this later release are pending at this
source commit. Do not infer their completion from the earlier 1.0.1 (2) install.
