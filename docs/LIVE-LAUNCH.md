# WashKrew launch status — 25 October 2026

The live payment integration is connected. Customer checkout deliberately remains in test mode while the external merchant review and real operational setup finish. A successful technical setup is not a completed real-money acceptance test.

## Completed

- Published the WashKrew-branded Customer `/app/`, Captain `/captain/` and prelaunch landing page at `https://wheelio-apps.web.app/`.
- Completed merchant mobile verification and submitted that website with SMS-OTP login instructions. No production QA account or fixed OTP was created for the reviewer.
- Razorpay shows the website **Under review**, with an expected update in **24–48 hours**. Trustkeyper's existing website remains approved.
- Matched the existing live key pair from the owner's private credential document to the selected merchant and verified authentication through a read-only Razorpay request. No secret value was printed or committed; no key was regenerated.
- Saved the live pair in new versions of Wheelio's `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` and redeployed the seven payment functions. The original test pair remains in `RAZORPAY_TEST_KEY_ID` / `RAZORPAY_TEST_KEY_SECRET`.
- Created enabled live webhook `Ts0o1UGO3CUsRm` for `payment.captured`, `order.paid`, `refund.processed`, using the existing private `RAZORPAY_LIVE_WEBHOOK_SECRET` and `razorpayLiveWebhook` endpoint.
- Both live and test credentials authenticate. The config still says `paymentMode: test`; test checkout and historical test refunds select the archived test provider. Capacity, offers, wallets and earnings remain separated by payment mode.
- Trustkeyper's project secrets, primary website, merchant brand, existing webhooks and Route linked-account settings were not modified.
- Both signed webhook setup checks pass (`200` with the correct signature, `401` with an invalid one). All 25 protected app callables reject anonymous access. Cloud Functions metadata confirms all seven payment functions are active with the new live credential versions. The provider's read-only webhook inventory confirms the live subscription and the original test subscription are enabled for the intended events.
- Updated the two server notification handlers to use WashKrew branding. Both published app startup screens and the Customer's server catalog render without console warnings or errors; the test-payment banner remains visible.

## Remaining launch gates

| Gate | Actual status / next action |
| --- | --- |
| Merchant website approval | Razorpay review pending. Confirm **Approved** in the signed-in dashboard before enabling real checkout; resolve any merchant-category or website clarification requested there. |
| Live commercial settings | The existing catalog and payout amounts are test configuration. The owner must review the live prices, payouts, cancellation policy and served societies. Do not invent or silently approve those values. |
| Live captains | Read-only Firestore check found **0 approved live-mode captains**. Actual applicants need identity/bank review, society approval and live-mode onboarding. Do not manufacture capacity with QA accounts. |
| iPhone acceptance | Build/sign/install on the owner's Mac; test camera allow/deny/re-enable, media, real SMS, Razorpay app switching, assignment, private photos and foreground GPS on hardware. Windows checks do not replace these tests. |
| Apple push | Apple capability/provisioning and APNs key setup plus physical foreground/background notification acceptance remain pending. The private inbox works independently. |
| Live payment acceptance | After the above gates, perform an explicitly authorized live checkout and refund acceptance. No live payment, refund or payout was executed in this setup. |

Android remains deferred under the repository instructions. Payout transfers, KYC decisions and dispute resolutions remain reviewed operations.

## Verification boundary

The merged source passed four Flutter analyses, 57 backend/rules/payment/notification emulator tests, 8 Customer tests, 5 shared native-login/checkout tests and both release web builds on 25 October. Those tests cover payment-mode switching without stranding old test refunds. Credential installation and deployed gateway/signature checks create no customer booking, charge or provider refund. Source credentials and the owner's private PDFs remain outside Git.
