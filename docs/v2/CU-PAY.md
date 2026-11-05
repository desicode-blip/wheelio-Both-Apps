# CU-PAY — Checkout and Razorpay

Feature map: [FEATURES.md](FEATURES.md). Screens: C17–C19.

## 6 Nov 2026 — Faster Razorpay, and no block after closing it

- **Why (Aman):** Razorpay took long to open; after closing one payment, a new one was blocked.
- **Causes found:**
  1. Closing Razorpay was shown as "Waiting for your bank" (only *Check again* / *Call
     support*). The booking stayed *waiting for payment* on the server, and the server
     refuses any new booking while one is waiting ("Finish or cancel your pending payment
     before starting another booking").
  2. Before Razorpay opens the app makes server calls in a row: confirm the parking place,
     create the booking, prepare the Razorpay order, and waits for the photos to upload.
     Cold Cloud Functions add seconds to each. iOS cannot preload Razorpay.
- **What changed for the user:**
  - Closing Razorpay now shows **Payment not completed — You closed the payment. No money
    was taken.** with **Pay now** and **Back to Check and pay**.
  - **Pay now** reuses the same booking (photos already saved, Razorpay order already made),
    so Razorpay opens almost at once.
  - If the details changed, or another unpaid booking is waiting, the app releases the
    unpaid one (only after the server confirms it was not paid) and books afresh — no block.
  - The parking place is confirmed while Check and pay is open, not after Pay.
- **Files changed:** `customer/lib/data/store.dart`, `customer/lib/screens/auth_pay.dart`,
  `packages/washkrew_firebase/lib/src/checkout_flow.dart` (+ test).
- **Backend needed (Ajay):**
  - Set `minInstances: 1` on `createCheckout`, `checkPayment`, `verifyPayment` and
    `checkServiceAddress` (live) to remove cold starts — the biggest remaining delay.
  - Released unpaid bookings are cancelled with reason `customerCancelled`; consider a
    `checkoutAbandoned` reason and hiding them from the Bookings list.
- **How to test on the phone:** Pay now → close Razorpay → "Payment not completed" → Pay now
  (opens fast). Close again → Back → change the time → Pay now (no "pending payment" error).
- **Status:** built; tests pass. iPhone check pending.
