# Direct Razorpay checkout and payment preparation — 2 November 2026

The owner requested one payment-method choice in Razorpay and a faster transition
from Pay. This explicitly permits skipping the live C17 payment-method sheet.
The authored Review and C18 layouts, typography, palette and controls remain.
Demo/reference C17 is retained; other Customer/Captain designs are unchanged.

## Cause and implementation

Read-only production request logs around the reported attempt showed approximately
30 seconds between booking creation and Razorpay preparation. A recording and
four photos were uploaded/registered serially during that interval. The app also
reconfirmed an already confirmed address, used separate booking/checkout callables,
and called the entire preparation phase **Confirming payment** before checkout
had even opened. Selecting a method in C17 only reordered Razorpay's groups, so
the user still had to select the actual payment instrument there.

- Live **Continue to pay** opens the gateway flow directly. Returning from checkout
  OTP/name refreshes Review for one frame, then proceeds without the old 450 ms
  sheet timer. Review can apply a newly loaded wallet balance before preparing
  the expected server amount. Change method reopens Razorpay.
- With no attachments, `createCheckout` accepts the existing booking payload,
  invokes the same server booking transaction, then prepares the provider order
  in one callable. Old booking-ID clients remain supported.
- Selected photos/recordings upload concurrently with each other and with
  Razorpay order preparation. **Every selected upload must finish before opening
  the SDK**. A failure does not silently discard evidence or claim a payment.
  Wallet-only/free-wash checkout waits for uploads before calling settlement,
  because a zero-cash checkout settles immediately rather than opening Razorpay.
  A captured retry skips rewriting locked attachments and reads server status.
- A confirmed `loc_` location is reused. The booking transaction still resolves
  the server record, checks the parking pin, current capacity, work periods,
  expected amount, cancellation terms and wallet reservation. Older locations
  still go through confirmation. No client flag grants service coverage.
- On Review, Android preloads Razorpay resources through its official SDK; web
  preloads `checkout.js`. Preloading opens no checkout and creates no order.
  Failed web loading clears its cache so Pay can retry. iOS keeps its existing
  native SDK path; no unsupported iOS preload API is invented.
- C18 shows actual **Opening secure payment**, **Saving your photos and notes**
  or **Confirming payment** stages. Its layout remains authored. Live checkout
  has no fake delay, minimum spinner time or extra paid warm instance.
- Repeated taps share the in-flight operation. Callback verification, lost-callback
  reconciliation, server-only capture, wallet/capacity atomicity and the ban on
  credit-card checkout / EMI / paylater are preserved. All supported UPI apps,
  debit cards, netbanking and provider wallets remain in Razorpay.

There is no promise of an instantaneous gateway on every connection: real media
uploads, Firebase scale-from-zero and Razorpay/network response times still apply.
Attachments remain before payment rather than weakening the evidence lock.

Official Android preload reference:
https://razorpay.com/docs/payments/payment-gateway/android-integration/standard/integration-steps/

## Verification and release record

- Full isolated backend suite: **178 passed** (including combined checkout,
  idempotent provider/wallet reservation, ownership/price validation and wallet-only
  settlement). No live charge/refund is used by these tests.
- Shared Firebase package: **33 passed**. Controlled asynchronous tests establish
  parallel preparation/uploads, the upload barrier, capture reconciliation and
  verification only after the SDK result. Wallet-only settlement stays after the
  attachment barrier. They initialize no real provider.
- Customer suite: **68 passed**; final checkout/router focused suite: **11 passed**.
  The live path bypasses C17, repeated taps do not add duplicate payment routes,
  and actual stage text appears in the existing state widget.
- Customer and shared Firebase static analysis passed.

## Published artifacts and remaining device gate

- The backward-compatible `createCheckout` update is deployed and ACTIVE. The
  exact deployed source generation's `service.mjs` matches the local source.
  Minimum instances remain **0**, maximum **5**. Documented gateway configuration
  completed for all 55 HTTP controllers. The actual checkout endpoint rejects
  an anonymous request with HTTP **401 / UNAUTHENTICATED**.
- Default Firebase Hosting was published after both release web builds, then
  republished with the final Customer wallet/attachment guard. The published
  `/app/main.dart.js` and `/app/flutter_bootstrap.js` exactly match the final
  local build. The separate washkrew.com website was not changed.
- The final upload-signed Customer arm64 release bundle built successfully.
  Merged Android manifest confirms package
  `com.amanmaheshwari.wheelio.customer`, version **1.0.1 (2)**. Local JAR verification
  returned exit 0 / `jar verified`; the existing private upload key remains outside
  Git. Artifact: `apps/flutter/customer/build/app/outputs/bundle/release/app-release.aab`.
  SHA256: `0f3b6cbf201fb6a8cc84f2e5efcb02b2d75ab894b013d5b68d4e4133243e8a59`.
- **BLOCKED — Play upload/install and live gateway timing:** the phone was
  reauthorized, and its currently installed Customer copy was read back as Play
  version 1.0.0 (1). Computer Use then stopped because its browser safety check
  could not determine Chrome's current URL. No further UI input was attempted.
  The new bundle has not been uploaded to Play or installed on the phone, and
  no post-fix on-device gateway timing or live charge is claimed.

To continue, restore the signed-in Sumit Play Console window with its address bar
visible, upload this bundle only to **WashKrew Customer's internal test track**,
and update the existing app from Play. Preserve its signing identity and app data.
Keep TrustKeyper, TrustKeyper Staging and Captain releases untouched. Check Pay
opens Razorpay with one actual method choice, attachments finish before payment,
and dismiss/retry uses the same booking. A real charge needs a deliberate user
payment, not an automated test capture. Slow attachments/network and bank response
times remain real limits; no absolute post-fix latency has been measured yet.

Captain does not need a release for this Customer-only checkout change. Windows
compilation does not establish Xcode or physical iPhone success. No live booking,
wallet credit, payment, refund or approval was fabricated during this work.
