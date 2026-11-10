# Checkout, permissions and wash-report fixes — 10 November 2026

**Later owner direction on 10 November supersedes the wallet-fee proposal below:**
remove the WashKrew wallet/top-ups/checkout and replace refunds with private
admin-issued coupons funded by payments already held. Preserve existing Customer
value during conversion. Coupon deduction and unused-value decisions were asked
explicitly; do not activate an assumed formula. The wallet-fee section below
records the earlier checkpoint and merchant probe, not the new target product.

Starting point: staging `e67a15e` matched origin/staging when fetched. No newer
Aman push was present. Existing authored app layouts/assets/components remain;
changes are handlers, state, relevant copy, camera angle guidance and the existing
wallet/admin surfaces. No unrelated TrustKeyper app is modified.

Current source: **Customer 1.0.5 (10)** and **Captain 1.0.6 (11)**. These replace
the earlier 9/10 source for the next build. Check the consoles before uploading:
an occupied build code needs a higher number. Nothing here submits a store release.

## What changed

- Native phone entry is shared login/signup. The server determines the current
  role after OTP. New Captains enter their name afterward; an old local name is
  never sent during login to overwrite an existing Captain. No phone-number
  enumeration endpoint was added.
- Both native apps request camera, microphone, foreground location and
  notifications sequentially on first launch. Denial does not block onboarding.
  Requests are remembered per installation; existing feature permission/settings
  recovery remains. The system photo picker needs no broad photo-library access.
  No contacts, SMS inbox, background location or tracking permission was added.
- The in-app Captain viewfinder labels Before/After, Front/Back/Left/Right and
  angle count inside the preview. Existing capture/auto-next/upload controls stay.
- Checkout request identities include vehicle, parking, schedule, credit and
  payment choice. A reused retry ID cannot silently purchase a different draft
  or reuse an earlier zero-cash checkout. The server reconciles an older unpaid
  checkout before replacing it, without a separate client round trip. Reservations
  restore once with their original credit expiry. Captured bookings are never
  cancelled by this cleanup. Late captures cannot clear a newer pending checkout.
- SDK cancellation reconciles bank state before releasing an unpaid checkout.
  The Customer returns to booking rather than a trapped confirmation screen.
  Foreground return from a bank/UPI app also checks actual server capture when
  the native callback is lost. Foregrounding or an SDK callback alone grants no
  booking/credit. OS/bank app switching still needs physical Android/iPhone tests.
- Explicit wallet checkout must cover the whole server price, cannot consume a
  free-wash entitlement implicitly and cannot bypass current balance checks.
- New `netGatewayV1` booking snapshots pay Captain wash value minus the actual
  captured Razorpay `fee`. That field already includes GST; `tax` is not deducted
  again. Wallet-funded bookings pay the whole wash value without a second fee.
  Promotional free washes retain their configured subsidy. Historical booking
  and settled earning snapshots are not rewritten. Missing provider fee data is
  retryable confirmation, never a guessed flat/platform deduction. Captain offer,
  earning and payout displays retain paise rather than truncating each amount.
- Reports pin their booking through selection, photos, submit and status. Camera
  or phone uploads are capped at three with replacement; concurrent picks/sends
  are guarded. A descriptive no-show/wrong-vehicle report can be sent without an
  impossible wash photo. Partial upload failure cannot submit an incomplete
  report. A lost submit response retries without overwriting locked evidence.
- The private admin portal has a Wash problem reports section. The existing
  Google reviewer allowlist, fresh session, evidence confirmation, expected
  version and no-self-review rules protect decisions. Reviewers can inspect the
  attached Customer/Captain photos and response, uphold/reject or escalate damage.
  Decisions record an audit entry. Upheld credit is applied once; rejected reports
  approve the stored Captain earnings. This records no bank payout. Existing
  payout IDs prevent already-recorded earnings being transferred a second time.
  App status uses real review outcomes and actual evidence, without fictional
  call deadlines, automatic Captain suspension or a protection-fund promise.

## Wallet fee: owner-confirmed flow, merchant activation pending

The owner confirmed: a Customer pays the usable top-up value **plus** the actual
gateway fee once. For example, if the fee were ₹2, ₹102 paid gives ₹100 credit;
a ₹69 wallet booking pays Captain ₹69 and leaves ₹31. ₹2 is not a configured rate.

This uses Razorpay's per-order Dynamic Convenience Fees, customer share 100%, for
UPI/debit/netbanking/provider wallets. Checkout calculates the method-specific fee
and discloses the full charge before authorisation. Credit cards, EMI/paylater
remain blocked, including server-side source refunds for prohibited funding.
Credit-linked UPI remains allowed. No merchant-wide fee-bearer setting is changed.

The live merchant capability probe on 10 November returned HTTP 400,
`invalid_convenience_fee_config`: Dynamic Convenience Fees are not enabled.
No order was created and no charge was taken by that probe. **Do not invent a
2% fee, silently drop the fee config or claim live fee collection was tested.**

`configure-checkout-fixes` enables the new booking earnings policy and prepares
the wallet fee policy with new top-ups paused until the merchant is ready.
Existing wallet credit, historical top-up reconciliation and direct booking
checkout stay usable. The new app explains the temporary top-up state.

Ask Razorpay support to enable **Dynamic Convenience Fees / dynamic customer fee
bearer via Orders API** on the separate WashKrew merchant, for domestic INR and
the supported non-credit payment methods. After confirmation, the owner operator
runs (using the existing private Firebase CLI owner login):

```powershell
node backend/firebase/operations.cjs enable-wallet-gateway-fees
```

This makes an unpaid ₹1 capability order, verifies all returned rules, then
enables new top-ups. It never charges or grants credit. Test one real authorised
top-up afterward: charged total, actual fee and credited amount must reconcile.
Only captured provider data can grant usable credit, exactly once. Any unexpected
gross/fee/net mismatch fails closed for review. Legacy top-ups keep their saved
math. A prohibited-funding refund includes the full captured total, including fee.

Provider references:
- https://razorpay.com/docs/api/payments/entity
- https://github.com/razorpay/markdown-docs/blob/master/payments/dynamic-convenience-fees/api.md
- https://github.com/razorpay/markdown-docs/blob/master/payments/dynamic-convenience-fees/faqs.md

## Verification and native handoff

The full backend emulator suite passed 226 tests. A further 10 focused financial
checks passed, including replacement checkout and prohibited-funding/fee cases.
The full Flutter suite passed 205 tests before the compatible permission-plugin
pin; it is rerun for the final pin. Final deployment/build evidence is recorded
alongside this handoff before committing. No real approval, customer deletion,
wash evidence, charge or payout is created for these automated checks.

Flutter 3.38.6 uses `permission_handler 12.0.3` with native Android `13.0.1` pinned
to retain AGP 8. The newer plugin requires the AGP 9/API 37 generation and fails
this project's build; do not remove that pin without a deliberate toolchain
migration. The Podfiles enable only the four required iOS permission groups.

On Aman's Mac follow `AMAN-IOS-HANDOFF-2026-11-02.md` and run the normal prepare
helper, which performs `flutter pub get --enforce-lockfile` and `pod install
--repo-update`. Commit Mac-resolved Podfile.lock updates after successful builds.
Keep bundle IDs, Firebase, Apple team and privately configured APNs key. Windows
source/tooling checks and Android bundles do not establish an Xcode archive,
silent iPhone verification or physical payment-return acceptance.

Retest: phone-only existing/new/deleted-role login; first-launch grants/denials;
all eight camera phase/angle combinations; unpaid payment cancel then another
vehicle; insufficient wallet/no free booking; bank/UPI return with one booking;
new direct-payment net Captain earning; report each kind, denied camera/gallery,
partial failure/retry, private reviewer decision, both app updates and one credit.
Keep production bookings/photos truthful. Use emulator fixtures for damage,
dispute outcomes and money races; do not stage real wash evidence or approve
people as a test. Wallet-fee physical acceptance waits for merchant activation.
