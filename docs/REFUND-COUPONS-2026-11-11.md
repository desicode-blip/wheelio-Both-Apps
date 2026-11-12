# WashKrew refund coupons and vehicle prices

Customer **1.0.6 (11)** and Captain **1.0.7 (12)** are the coupon release.
The earlier wallet builds are superseded. Both apps retain their existing
design and native identifiers. Read the [Mac build handoff](AMAN-IOS-HANDOFF-2026-11-02.md)
for signing and device setup.

## Customer and Captain flow

- Pay the current server price through WashKrew Razorpay. UPI, debit cards,
  netbanking and supported Razorpay wallets remain available. WashKrew has no
  wallet or top-ups in this release.
- Cancel through the existing booking screen. The server quotes the saved
  rules, and the private admin queue shows the request after confirmation.
  Within five minutes inclusive, the coupon is the paid booking value less
  the actual Razorpay fee, even if the wash is less than two hours away.
  Later, at least two hours before the window, it is 50% of the paid value
  less the actual fee, with a minimum of zero. Later cancellations receive
  zero. A service failure or upheld wash report qualifies for full paid
  value less the actual fee. A ₹100 wash with a ₹2 fee gives ₹98 or ₹48
  under the first two rules.
- An authorized reviewer checks the captured payment and issues one private
  coupon. Find it under Coupons and apply it at Check and pay. Razorpay
  collects any shortfall. For a cheaper wash the app asks the Customer to
  confirm the loss of the unused value. Only the amount applied to the wash
  is eligible for any later coupon. Unpaid or prohibited checkout releases
  the reservation at its original expiry. A cash shortfall below ₹1 cannot
  be collected and the coupon stays available.
- Successful jobs earn the agreed price minus the actual fee on any new
  Razorpay payment and minus WashKrew's 3% of the agreed price. The server
  rounds that commission to the nearest paise. Coupon-only payment has no
  new gateway fee. The existing human payout process records the actual
  transfers.
- Old bank refund obligations and booking price/earning snapshots continue
  under their saved rules. Live prepaid credits convert to owner-bound
  coupons on account load, preserving amount and expiry. An old free-wash
  entitlement becomes a one-year coupon for the highest current active
  vehicle price. New refund coupons expire one year after issue.

## Admin and release

On 11 November, the coupon Functions, Firestore rules and indexes, and
the private admin portal were deployed. All 27 updated Functions are
active with zero minimum instances. Both indexes are ready, anonymous
requests were rejected, and Hosting version `bc1ec121aa6ffc34` serves the
verified admin assets. The live coupon switch and matching public policy
pages are pending the Customer app rollout.

Use [the private admin portal](https://wheelio-apps.web.app/admin/) with an
approved Google account. Refresh Google verification before a decision.
The refund review requires a note and confirmation. Enter vehicle prices
to two decimal places and provide a reason. Price changes are audited and
apply to new bookings.

Deploy the verified coupon Functions and Firestore rules/indexes using the
existing `wheelio` codebase and `wheelio-apps` project. Enable authenticated
HTTP gateways using `node backend/firebase/operations.cjs configure-api-access`.
After verifying the Functions and indexes and making the updated Customer
app available to its users, activate with
`node backend/firebase/operations.cjs configure-refund-coupons <deployment-start-ISO>`.
Older Customer versions cannot create bookings under the new policy.
Deploy the matching private admin and generated policy pages with the
cutover. Use the existing Hosting targets and preserve the current prices.

Run the end-to-end flow with emulator/test data before production
activation. On devices, verify Razorpay return, a partial coupon, a
cheaper wash confirmation, a refund request visible to admin, customer
coupon delivery, and an approved earning. Use a controlled test environment
for these checks. The native iPhone build and signing are verified on Mac.
