# CU-REVIEW — Check and pay

Feature map: [FEATURES.md](FEATURES.md). Screen: C13.

## 6 Nov 2026 — Simpler Check and pay (C13)

- **Why (Aman):** the page repeated the vehicle, the wallet (twice) and a long cancellation
  paragraph, with two competing pay buttons.
- **Screens:** C13 redesigned.
- **What changed for the user:**
  - Removed the vehicle card at the top (plate · type · wash · place).
  - One card with icon rows: **When**, **Wash**, **Notes**; then the money: *Wash price*,
    *From wallet* (only when used), **To pay**.
  - Wallet shown once: **Use wallet balance ₹X** with a toggle. The *To pay* line and the
    button change with it.
  - One primary button: **Pay now · ₹amount** (or *Book with free wash*).
  - Cancellation paragraph removed. A small **Cancellation policy** link opens it on tap.
  - Free wash: a single "Use my free wash" toggle card (unchanged behaviour).
  - Removed the "held safely" banner to keep the page short.
- **Wallet rules today (live server):** the server accepts either the whole price from the
  wallet or the whole price through Razorpay — not a mix.
  - Wallet covers the price: toggle starts ON → *Pay now · ₹0* books from the wallet.
  - Wallet is less than the price: toggle starts OFF → *Pay now · ₹full* via Razorpay.
    Turning it ON shows "Add ₹X to pay the full amount from your wallet" and the button
    becomes **Top up ₹X and pay**.
  - When Ajay enables part-payment (below), turning it ON makes the button *Pay now · ₹rest*.
- **Files changed:** `customer/lib/screens/booking.dart` (ReviewScreen), tests
  `payment_recovery_test.dart`, `wallet_by_time_test.dart`, `wallet_cancellation_test.dart`,
  `wallet_screen_test.dart`.
- **Backend needed (Ajay):** to pay part from the wallet and the rest by Razorpay, allow
  `paymentChoice: 'razorpay'` with `useCredit: true` in `createBooking` (today
  `service.mjs` rejects it: "Choose wallet to use credit, or pay the full amount through
  Razorpay"), charge only the remainder, and set `config/operations.walletSplitPayments = true`
  (the app reads it from `liveConfig`). Nothing else needed.
- **How to test on the phone:** book a wash → Check and pay: icon rows, one wallet toggle,
  one Pay now button; tap *Cancellation policy* to read it.
- **Status:** built; Customer tests pass. iPhone check pending.

## 12 Nov 2026 — coupons up front (Aman)

- **No typing a code.** The customer's refund coupons (Ajay's `coupons` collection:
  active, not expired, value left) show on Check and pay as cards: amount, "valid until",
  and a small **Apply** button.
- **Applied:** the card animates to green with a tick that pops in at its top-right
  corner, says "Applied to this wash", and offers **Remove**. One coupon per wash;
  applying uses Ajay's `store.applyCoupon` (`previewRefundCoupon`), Remove clears the
  draft coupon fields as before. The forfeit warning and the "Use this coupon once?"
  confirmation are unchanged.
- **3 or more coupons:** one **Discount coupons · N available · up to ₹X off** button
  opens a sheet on the same screen with every coupon; applying closes it, and the
  applied coupon shows on the page with "See all N coupons".
- **Removed:** the code field, "Apply coupon" and the "Your coupons" link (the
  Coupons screen stays reachable from Home).
- **Cancellation policy:** a quiet grey line with an info icon, no underline, at the
  bottom right above the footer line; tapping still opens the policy.
- **Review tools on, no real coupons:** three sample coupons show the look only; the
  price is not changed.
- **Files:** `customer/lib/screens/coupon_picker.dart` (new), `booking.dart`
  (ReviewScreen), `store.dart` (`refundCouponDocs`); tests `coupons_screen_test.dart`,
  `wallet_cancellation_test.dart`, `wallet_by_time_test.dart`.
- **Also fixed:** the "booking works with these times" message now writes each end
  with its own AM/PM ("10 AM–12 PM").
- **Backend:** none — uses Ajay's existing coupon query and callable.
