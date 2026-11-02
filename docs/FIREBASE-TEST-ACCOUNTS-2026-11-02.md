# Owner-authorized Firebase test logins — 2 November 2026

The owner explicitly requested fixed-code Firebase logins for the two roles and
supplied two previously unused Indian mobile numbers reserved for this test.
The first supplied number belongs to Customer and the second to Captain.
This is a specific authorization for those two accounts, not permission to add
test logins for other numbers or disable real-number app verification.

## Configuration and credential handling

Two dedicated Auth users and two **Phone numbers for testing** entries are saved
in `wheelio-apps`. Each uses a separately generated six-digit code. Auth users
carry an informational `washkrewTestAccount: true` claim; it grants no approval,
reviewer access, wallet balance or special application behavior. Distinct UIDs
preserve the existing Customer/Captain self-booking restriction.

Only `signIn.phoneNumber.testPhoneNumbers` was patched. Authenticated read-back
verified both codes/users and preservation of the other Auth settings. Phone
authentication remains enabled with SMS region allowlist `IN`. No real-SMS
verification flag, provider, security rule or app UI/source was changed.

Firebase rejects adding a test number that already has an Auth user. The initial
setup created the empty Auth users too early; only this operation's two fresh,
never-signed-in users were recreated after the numbers were configured. Existing
accounts were checked for conflicts and left untouched. No real customer or
Captain account was replaced.

The numbers, codes and UIDs stay outside Git in the owner's private local testing
folder. `C:\Users\ajayb\.washkrew\testing\WashKrew-test-logins.txt` contains the
login instructions and fixed codes. Do not copy its contents into public reports,
source, screenshots or Git. Keep access private; these are working credentials.
Rotate/remove the test entries and revoke/disable these dedicated users when the
test period ends. Never convert an arbitrary customer's number to a test login.

## Physical Android evidence

Both maintained apps were installed from their separate Google Play internal
tracks. Android identifies `com.android.vending` as installer for each. Installed
APK signatures match the corresponding Play certificates registered with Firebase
and Maps. See [PLAY-INTERNAL-2026-11-01.md](PLAY-INTERNAL-2026-11-01.md).

- Captain: normal sign-up → name/number → Get code → fixed code → Next → Home
  succeeded at approximately 02:58 IST on 2 November. The app/server show the
  dedicated profile, `approved: false`, `kycStatus: notSubmitted`, `online: false`.
- Customer: normal Profile → Log in → Get code → fixed code → existing name
  screen → Continue → Home succeeded at approximately 03:00 IST. Its saved name
  and Customer-only role were read back from Firebase.
- Neither successful test-number flow sent a real SMS or showed a bot-check
  page. No app-level code, auto-filled credential, bypass screen or demo build was
  added. The test logins use the existing release apps and normal controls.

Customer initially displayed a generic error after its first successful Auth
sign-in on 1 November. Cloud logs confirm valid Auth, HTTP 200 registration and
the saved Customer profile. App Check's existing placeholder warning was explicitly
allowed by the already-disabled enforcement and was not the rejecting operation;
no App Check setting was changed. The saved session restored normally, and the
later repeat login reached the name screen and Home without the error. The first
generic client error's precise cause is **not established** and must not be
reported as a proven source fix. Retest the first-registration transition if it
recurs; do not weaken authentication as a workaround.

## Operational boundaries

These accounts connect to the **live backend and real-payment gateway**. No
payment, order, wallet credit, uploaded KYC, completed training or human approval
was fabricated. App profiles were created through normal registration, not seeded
as approved records. At account creation, Captain still needed its documents,
payout, area and actual human review before eligible work. The private admin portal remains
https://wheelio-apps.web.app/admin/ and requires an authorized reviewer Google
account; a test phone login does not grant reviewer access.

Later on 2 November, the owner completed the Captain's actual human approval and
saved its work area/hours. The agent did not grant approval. The coverage correction
was then verified using this already-approved Captain: native Go online succeeded,
temporary hours edits changed live availability, and the original hours / Offline
state were restored. See
[COVERAGE-ONLINE-FIX-2026-11-02.md](COVERAGE-ONLINE-FIX-2026-11-02.md).

This verifies convenient test-number login, not real-SMS Play Integrity, APNs,
physical iPhone acceptance or a completed live paid wash. Real-number/native OTP
acceptance remains a separate check.

Official reference: [Firebase phone authentication testing](https://firebase.google.com/docs/auth/android/phone-auth#test-with-fictional-phone-numbers).
