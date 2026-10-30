# WashKrew
## Aman: add funds for the pending refund

**30 October 2026 | Separate WashKrew LIVE Razorpay merchant**

### Why this is needed

One **INR 149** refund is waiting. Our last dashboard check showed **INR 141.96
current balance, INR 0 reserve and INR 0 refund credits**: a **INR 7.04 shortfall**.
These figures can change, so check the current balance before paying. The app
already retries the existing refund; adding funds does not require new app code.

### Where to go

1. Open [Razorpay Dashboard](https://dashboard.razorpay.com/) and sign in to the
   **WashKrew merchant account**, not the older Trustkeyper merchant. Keep **Test
   Mode OFF**. On Ajay's laptop this is the signed-in Sumit Chrome profile.

2. Click **Account & Settings** at the bottom left. Under **Payments and refunds**,
   choose **Balances**. Find the **Reserve Balance** box and click **Add Funds**.
   [Direct link to the Balances page](https://dashboard.razorpay.com/app/payments-and-refunds-settings/balances).

3. Use money from the **bank account registered with this Razorpay merchant for
   settlements**. Do not choose an unrelated bank account just because its UPI
   app is on your phone. If you cannot access the registered account, ask its
   holder to make the top-up.

### How to pay

4. Choose **UPI**. Enter an amount you approve that covers the **current refund
   shortfall**, any displayed top-up fee, and the dashboard's minimum. The last
   shortfall was INR 7.04; do not assume that is still the amount needed. Check
   the final debit before continuing. This funds the merchant's refund buffer;
   it is separate from a Customer's WashKrew wallet.

5. Continue with **Add Credits** (or the equivalent button shown). Complete any
   contact fields, then use the UPI ID/QR offered by Razorpay. Select the registered
   settlement bank account and enter the UPI PIN **only in your own payment app**.

6. If UPI is unavailable, choose **Bank Transfer** instead. Copy the account number
   and IFSC shown in this dashboard, verify the beneficiary, and transfer from
   the registered settlement account. Do not use bank details sent in a message.

### After payment

7. Return to **Account & Settings -> Balances** and refresh. Razorpay says reserve
   funds can take **2-3 hours** to appear. A successful bank debit alone does not
   mean the merchant balance has updated. Keep the transfer receipt privately.

8. Tell Ajay: **"Reserve funds added to WashKrew. The updated balance is INR ___.
   Please verify the pending INR 149 refund."** If sharing a screenshot, hide bank
   numbers, payment IDs, personal details and any QR/secret information.

**Do not click Refund manually or make another booking just to fund this refund.**
Ajay will check the existing automatic retry and provider result after funds
reflect. Do not send OTPs, passwords, UPI PINs or API keys. If funds appear but
the refund still fails, tell Ajay; a generic provider error can have other causes.

Source: [Razorpay's official reserve-balance guide](https://razorpay.com/docs/payments/dashboard/account-settings/balances/).
