# GPS search and native OTP — 1 November 2026

## Owner's requested search behavior

After the Customer grants GPS permission, the existing Society or building field
shows nearby housing/building suggestions. Typing updates the selectable rows
below that field. The existing header, field, result-row components, typography,
colours, manual-address route and parking flow are preserved. Google Maps text
attribution appears beneath Google's results as required by its provider policy.
The disconnected design gallery retains its authored sample screens.

Nearby Search uses the housing categories within 5 km, ranked by distance. Typed
Autocomplete uses an optional 15 km GPS bias and India results. Typing is debounced
350 ms, with nearby matches available immediately from this in-memory session;
one-character input filters those nearby results. Replies from older queries or
departed screens cannot replace current results. Editing during address selection
invalidates the old selection. Selecting a result resolves its address and
coordinates on the server and ends/renews the Autocomplete billing session.

The GPS button requests location only when explicitly pressed. A previously
granted permission can be reused when opening the field, without another prompt.
GPS and search show real pending states. Typing continues to work while GPS is
pending or denied. No forced wait or simulated successful result is added.

Finding a building does not add service coverage. Only an exact configured Google
place ID, or canonical active society name/city/pincode, selects an existing served
society. Other results prefill the existing manual-address form; its existing
server approval and availability gates still apply before payment. No society,
Captain, work eligibility, booking or payment is fabricated by place discovery.

## Backend and limits

- `searchPlaceSuggestions` and `selectPlaceSuggestion` reuse the existing
  `GOOGLE_MAPS_SERVER_KEY` in Secret Manager and the already-enabled Places API.
  No server key or unrestricted Google response is returned to the app.
- Guest search works before the existing checkout login. The server applies
  30 lookups/minute and 300/day per client, plus a default project cap of 1,000
  lookups/day. `maps.places.dailyLimit` can be configured within 1–20,000.
  Searches, nearby requests and selected-place details each consume one lookup.
  Google Maps usage billing applies; no paid warm instance is enabled.
- Temporary `placeLookupLimits` records store daily hashes and counters only,
  never raw IPs, search text, session tokens or GPS coordinates. Their expiry
  field has a Firestore TTL policy. Provider results/GPS remain transient in the
  app until the Customer explicitly saves/submits their normal address/booking.
- `configure-place-search` verifies both deployed functions before enabling
  `maps.places.enabled`. Organization domain-restricted sharing remains intact;
  the documented `configure-api-access` operation enables only the listed app
  gateways. Search validation, coverage and rate controls remain server-enforced.
- Tests use isolated fake provider replies or the `demo-wheelio` emulators.
  There is no new app testing button, production QA Captain, fixed OTP or payment.

## Native OTP: what is configured and what still needs access

Both native apps use Firebase's native `verifyPhoneNumber`, while browser builds
use its web flow. No native screen contains a separate web bot-check widget and
the code does not force reCAPTCHA. The live Firebase configuration was inspected:
phone sign-in is enabled, `recaptchaConfig` is not configured to force a challenge,
and the installed development certificate's SHA-1 and SHA-256 are registered for
both Android app IDs. Real-number verification is not disabled.

Firebase documents USB/sideloaded Android apps as a reCAPTCHA fallback case on
current SDKs. To check the ordinary invisible path, distribute a properly signed
internal test through Google Play and register the Play app-signing certificate
with Firebase. A USB profile APK does not establish that result. Do not downgrade
the SDK or enable testing bypasses to make a real-number login appear to pass.
[Firebase Android verification](https://firebase.google.com/docs/auth/android/phone-auth#enable-app-verification).

iPhone's ordinary invisible verification needs the APNs authentication key for
team **28JNT7H8KA** and the existing push/background configuration. The private
`.p8` key and Key ID remain pending. Firebase can still use its fallback when
silent verification is unavailable; disabling verification accepts fictional
test numbers only and is not a real-SMS fix.
[Firebase iPhone verification](https://firebase.google.com/docs/auth/ios/phone-auth#enable-app-verification).

### Apple's account errors reported on 1 November

Aman's screenshot said his Apple login could not access team 28JNT7H8KA. Sumit's
later screenshot said the Apple Account was locked for security reasons. The
account owner must complete Unlock Account / recovery directly with Apple first,
then verify membership/team access. Do not change the app team or bundle IDs.

For an Individual membership, App Store Connect invitations do not grant Developer
Program team access; the Account Holder must create the APNs key. For an
Organization membership, the Account Holder or an authorized Admin can do this.
Key creation requires Account Holder/Admin access. The owner handles all password
resets and verification codes in Apple's browser. Keep the private key out of Git
and chat; provide its secure local-file location when it is ready for Firebase.
[Apple roles](https://developer.apple.com/help/account/access/roles),
[Apple key creation](https://developer.apple.com/help/account/keys/create-a-private-key/),
[Apple account recovery](https://support.apple.com/en-gb/102640).

## Verification record

The backend/emulator suite passes 162 tests. The final Customer suite passes 63
tests; the other suites pass Captain 14, shared UI 9 and Firebase 25 (111 total).
All four analyses pass, with Customer analysis rerun after its last UI changes.
The tests cover nearby loading, debouncing, stale replies/selections, selection,
manual-address prefilling, denied/pending GPS, rate limits and coverage boundaries.

The live provider and both deployed callable endpoints were checked using only a
public reference point at the already configured My Home Avatar. The deployed
checks returned eight nearby buildings, five typed suggestions, selected
`soc_avatar` with Hyderabad/500089, and rejected an invalid query with HTTP 400.
No device GPS, real booking, Captain approval or payment was submitted. See
`output/android-native-2026-10-31/place-search-live-smoke-2026-11-01.json`.

Web/native build, publication and physical-device evidence is recorded after the
corresponding checks. These results do not claim Xcode signing, a physical iPhone
pass, a CAPTCHA-free USB install, or completion of Apple's account recovery.
