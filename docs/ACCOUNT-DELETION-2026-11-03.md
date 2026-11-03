# Account deletion and iPhone verification follow-up

**Later same-day correction:** [ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md](ACCOUNT-LIFECYCLE-RECOVERY-2026-11-03.md)
records the missing runtime Storage delete permission, interrupted-cleanup recovery
and fresh signup/cache isolation. The initial tests below did not establish those
paths; use the later report and current source versions for acceptance.

3 November 2026. Owner request: fix deletion in both apps, replace the extra
deletion OTP with two clear decisions, and investigate iPhone phone-auth fallback.
All unrelated authored designs stay unchanged.

## Corrected behavior

- Customer 1.0.3 (4) and Captain 1.0.4 (5) retain the existing destructive dialog.
  The first decision is **Yes, continue**; the second is **Delete account** after
  an irreversible-action explanation. **Keep my account** cancels before work
  starts. No phone-change screen or new SMS is used for deletion.
- One pending action blocks duplicate submissions. A server error remains in the
  final dialog for retry rather than closing or being mislabeled as an open wash.
- `deleteOwnAccount` derives its target only from the authenticated, phone-verified
  caller. The former five-minute authentication-age requirement is removed for
  deletion; Firebase Admin performs the final Auth removal. Phone changes, login
  and sensitive payout verification keep their existing safeguards.
- Only the selected app role is removed. The shared Auth identity is deleted only
  when no other role remains. Current-role private profile/KYC/identity files and
  settings are removed; retained transactional records are detached/anonymized,
  preserving the other party's accounting/evidence. The dialog discloses that
  payment records are retained separately; it does not promise all records vanish.
- Existing open-wash/dispute, pending wallet-payment and funded-live-wallet guards
  remain. This change does not silently forfeit funded balances or settle debts.
- Closed booking history is cleaned in bounded groups and checkpointed. A failed
  cleanup can retry without repeating the entire history. Completed role deletion
  is idempotent. The server deadline is 120 seconds, the client deadline 180
  seconds; minimum instances remain zero.
- A lost callable reply is considered complete only if a fresh authenticated
  server read proves this role's completion. Pending, missing, unreadable or
  another role's marker is never proof. No second delete is issued automatically.

Firebase's [Admin user-management API](https://firebase.google.com/docs/auth/admin/manage-users)
supports server-side deletion. The fresh SMS requirement was our own deletion
policy, not a requirement to call this trusted Admin API. Authentication and
authorization still remain server-enforced.

## Automated evidence

All **196 backend tests pass** against isolated Auth/Firestore/Storage emulators.
All **172 Flutter tests pass**: Customer 74, Captain 37, shared Firebase 52 and
shared UI 9. Static analysis is clean for all four packages. The portable iOS
configuration check and tooling regressions pass
for both apps; this is source/tooling evidence, not an Xcode build.
Tests use isolated emulators and injected client fixtures. No real user, Captain,
identity document or financial record was deleted as a test.

An initial heavily concurrent run hit an emulator transaction-closed error in
the existing wallet callback race test; a clean full rerun passed all 196 tests.
No wallet/payment behavior was changed to mask that transient test failure.

Focused cases cover both actual profile screens, two distinct confirmations,
rapid duplicate taps, loading, no OTP, retryable errors, old authentication age,
verified ownership, role isolation, idempotent completion, interrupted private
file removal, large-history checkpoints and transport-response reconciliation.

## What Aman needs to check on his Mac/iPhone

Read [AMAN-IOS-HANDOFF-2026-11-02.md](AMAN-IOS-HANDOFF-2026-11-02.md), rebuild both
apps and record actual results in
[IOS-ACCEPTANCE-RESULTS-TEMPLATE.md](IOS-ACCEPTANCE-RESULTS-TEMPLATE.md). Existing
installed apps will not acquire the new dialog from a backend deployment alone.
Use consenting spare test accounts. Check Keep my account at both decisions,
then deliberate deletion, no extra OTP, retry on a genuine network error and
isolation when one number has both roles. Do not delete an active funded account
or stage identity/payment activity to produce a test pass.

The supplied Apple screenshot matches key **Y5432Q73U8**, paid team **28JNT7H8KA**
and both app topics. It was already configured privately in Firebase for both
environments/apps on 1 November; see
[APPLE-PUSH-SETUP-2026-11-01.md](APPLE-PUSH-SETUP-2026-11-01.md). No new key is
needed from Aman. The screenshot alone does not prove provisioning or delivery
on his installed builds.

Ask Aman/Claude for the actual commit, both installed versions, iPhone/iOS,
paid-team signed `application-identifier` and `aps-environment` entitlements,
enabled Push Notifications/Background fetch/Remote notifications and iPhone
Background App Refresh. If phone login still opens a challenge, return redacted
Firebase Auth/APNs error codes and whether an APNs token became available, never
the token or private key. Firebase documents the
[silent-push prerequisites and secure fallback](https://firebase.google.com/docs/auth/ios/phone-auth).
Do not disable verification for real SMS or promise the fallback can never occur.

Windows tests do not establish Xcode compilation, signing, APNs delivery or
physical iPhone acceptance. Those checks remain with Aman.

## Deployment evidence

The verified implementation is commit **38403d6** on local `staging`.
`deleteOwnAccount` was successfully updated in Firebase project `wheelio-apps`,
region `asia-south1`, at **3 November 2026 06:19:34 UTC** (11:49:34 IST).

Post-deployment checks at 06:20:50 UTC establish:

- Function ACTIVE, timeout 120 seconds, minimum instances 0, maximum instances 5.
- The exact deployed source archive matches local `service.mjs`,
  `runtime-policy.mjs`, `account-access.mjs` and `index.mjs` (UTF-8, normalized
  line endings). Source generation: `1793686719742313`.
- The runtime has the existing custom role containing only
  `firebaseauth.users.delete`, bound to the actual function service account.
- The documented callable gateway is configured. A request without Firebase
  authentication returns HTTP **401 / UNAUTHENTICATED**. Organization restricted
  sharing and application authorization remain enforced.

Only this deletion function was deployed. No Customer/Captain web deployment,
Play release, real account deletion or iPhone installation was performed. The
source change is committed locally; it has not been pushed by this task.
Physical iPhone acceptance remains with Aman after the updated source is shared
and both apps are rebuilt.
