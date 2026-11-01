# Captain-defined coverage — 1 November 2026

Owner explicitly authorized this feature's new map/slider UI on 1 November. All other Customer/Captain layouts remain under the af036f0 design lock. Existing demo work-area screens remain available unchanged in the design gallery.

## Operational rule

`config/operations.coveragePolicy: captainAreaV1` replaces manual society approval for NEW bookings. After Aadhaar, selfie and payout setup, a Captain saves a map centre, area label, radius (integer 1–10 km) and work hours (existing half-hour editor, 4 AM–10 PM). GPS is optional: area/building search and map positioning are alternatives. Explain GPS before requesting permission. The Home Jobs from → Change control and Me → Where I work open the same editor. Saving waits for server acknowledgment; failures stay editable.

Human admins still verify identity/payout details at https://wheelio-apps.web.app/admin/. They do not select societies under this policy. A legacy submitted application may be reviewed without a work area, but cannot go Online until one is saved. Never approve a real applicant as a test. Training stays hidden and unrequired.

All confirmed homes/societies inside an approved eligible Captain's radius use that Captain's hours and payment mode. Future slot availability uses scheduled coverage, not an assumption that every Captain must stay Online all day. Dispatch/claim additionally require Online and a fresh heartbeat. Self-booking is excluded. If nobody covers a slot it is unavailable; no payment is authorized by a place-search result alone.

The area centre stays fixed; foreground job/availability GPS never moves it. A saved area/hours/approval change invalidates open offers, refreshes Customer availability and triggers dispatch for matching searching bookings. Existing assigned jobs remain finishable after area edits. Payment/cancellation snapshots stay historical.

## Backend and privacy

- `saveCaptainServiceArea`: phone-authenticated, server-only Captain update, validated radius/centre/label/hours. No client approval writes.
- Private `captains/{uid}.serviceArea`: centre, radius, label, geohash, version and server timestamp.
- Server geohash range queries (geofire-common 6.0.0), followed by exact distance filtering, maximum search radius 10 km. Approved + geohash composite index.
- `coverageLocations/loc_<hash>`: stable server-only confirmed building/home identity and coordinates. Does not contain parking instructions, Customer UID or Captain identity. Google selections are provider-resolved; manual homes require explicit map confirmation. Booking checks parking is within 250 m of that confirmed location, then uses the actual parking coordinate for coverage.
- `availabilitySignals/current`: revision + timestamp only; authenticated single-document read, no list/client writes. Customer listener clears cached slots. Orders recheck capacity on creation, capture and claim.
- Paid capacity belongs to a provisional Captain across ALL addresses. Concurrent capture transactions query that day's reservations, preventing a single Captain from being sold twice at different buildings. Claim transfers the reservation only if that Captain has no overlapping reservation. Cancellation releases capacity via existing slot-key accounting. No financial records are migrated.
- New booking/settlement/dispatch/claim/advance code must be deployed together. All existing webhook versions still use the original merchant/mode and cancellation snapshots.

## Rollout

1. Run full emulator and four-package Flutter checks.
2. Deploy Functions + Firestore indexes/rules, then `node backend/firebase/operations.cjs configure-api-access` (retain organization policy).
3. Verify approved/geohash index ready; build/publish Customer, Captain and admin.
4. `node backend/firebase/operations.cjs configure-captain-coverage` only after all controllers/indexes are ready.
5. Existing approved Captains must save an area once. Existing phone-installed apps must update. No legacy area is invented or auto-enabled.
6. On phone: KYC → Serving area → search/GPS → radius → hours → save → human review. After actual owner approval, Online → separate Customer number selects a home → map confirmation → slot. Changing radius/hours should refresh Customer slots without reopening the app.

## OTP limitation

Both native apps use native Firebase phone verification. No web CAPTCHA is embedded by our native UI, and no forced-reCAPTCHA or production verification bypass is enabled. Firebase can show its fallback on USB/sideloaded Android apps; proper Play internal testing + registered Play signing SHA256 is the supported path to invisible Play Integrity verification. Ajay's Play Console currently shows developer-account creation, not an active publisher. Ask whether Aman/Sumit already has a publisher before creating/charging an account. iOS silent verification still needs the paid-team APNs key; Apple account recovery is with the owner. Do not use fictional-number bypass for real SMS or claim challenges can be guaranteed absent.

Primary references: https://firebase.google.com/docs/firestore/solutions/geoqueries and https://firebase.google.com/docs/auth/android/phone-auth#enable-app-verification.

Verification evidence will be appended after builds and device checks. Windows does not establish physical iPhone acceptance.

## Verified build/test record (1 November)

- Full isolated backend suite: **168 passed**. Final five focused coverage/reservation tests also passed after the shared Captain capacity-lock refinement. This includes new document submission → authorized human approval with no society selection → eligible Online, all in the demo project.
- Flutter: Customer 63, Captain 16, shared UI 9, shared Firebase 25: **113 passed**. Four-package static analysis clean. New onboarding area step does not grant approval or training; 360 px layout test passes.
- Customer and Captain release web builds and versioned private admin were published to default Hosting. Separate website site untouched.
- Approved/geohash Firestore index and authenticated read-only signal rules deployed. Captain-area policy switch remains OFF until every backend controller is successfully refreshed.
- Full Function deployment hit regional mutation-rate quota. Retry is prepared with a process-local two-task deployment queue; no Firebase policy/quotas/billing/minimum instances were weakened or increased. Owner login expired after the pause and needs a fresh Google verification before continuing.
- Both new Android arm64 profile APKs built and installed successfully on the connected OnePlus. Captain SHA256 `1dc3feb303bcf31305ea3718c3785ef97753814ecb324b21764def71945086e0`; Customer `a6daadf283a9e5d9cfd54e43dab2f78d67ebd7264bb62880790bbbc831872b0f`. These are USB acceptance builds, not Play releases.
- Owner confirmed Sumit's existing Play publisher account. Dashboard verified as `sumit@trustkeyper.com`, publisher TrustKeyper, with only TrustKeyper and TrustKeyper Staging currently registered. WashKrew Customer form prepared using existing package ID; availability confirmed. Policy/export declarations are unchecked. No new account was paid for or production release made.
- Private Android upload key prepared in the owner's local profile outside this repository. Both Gradle files support `WASHKREW_ANDROID_KEY_PROPERTIES`; bundleRelease refuses a missing upload key, while USB profile builds retain the existing debug certificate. Back up the private key securely; never send it through Git/chat. Play App Signing's final SHA256 must be added to both Firebase Android registrations before real Play-delivered SMS acceptance can be claimed.
- APNs key/Apple team access and physical iPhone acceptance remain with Aman. No real Captain approved, no live payment created, no fixed OTPs or QA accounts seeded in production.

## Publication progress

Firebase's remote OAuth page failed after Google verification. Using the official CLI's local callback completed owner authentication successfully; no password or OTP was copied into the repository. Full Functions deployment and documented API-gateway configuration completed, and `configure-captain-coverage` verified the geo index and activated the new policy. No identity approval was bypassed.

On the physical Android phone, Captain Home received the live policy without reinstalling. The existing Change control opened the new explanation/search screen; granting the owner-authorized GPS permission showed real Google Maps tiles and the radius circle. A 3 km area was saved and persisted when reopened. The Captain remains under review and Offline. Exact device GPS and private map screenshots are not included here.

Both app registrations were created in Sumit's existing Play publisher after the owner explicitly authorized accepting Google's policy/export declarations. They remain Draft, not public releases. Customer and Captain package names remain unchanged. Private internal-test bundles use `WASHKREW_ANDROID_INTERNAL_TEST=1` to skip the costly native R8 shrink pass; Flutter Dart remains release/AOT. Ordinary production release builds keep shrinking enabled. This build setting never selects test payments or bypasses Firebase phone verification.

Repeatable arm64 internal bundle build: set `FLUTTER_BIN`, the usual Java/Android SDK paths and `WASHKREW_ANDROID_KEY_PROPERTIES` to your private properties file, then run `pnpm android:internal` (optional role argument: `customer` or `captain`). Run `flutter pub get --enforce-lockfile` in each app first when dependencies have not been installed. Output is each app's ignored `build/app/outputs/bundle/release/app-release.aab`. Keep the private keystore/properties outside Git and back them up privately. App signing fingerprints issued by Play still need registration with Firebase and the restricted Maps key before Play-delivered phone checks are complete.

## Final publication and phone follow-up

The final guest-map availability controller was deployed successfully with the codebase-qualified filter `functions:wheelio:getAvailability`; documented API gateway configuration completed afterward. Final Customer/Captain web releases and private admin were republished to default Hosting. Read-back confirms `captainAreaV1`, live payment mode and enabled bookings. No production test booking or identity approval was created.

Both private arm64 internal release bundles built successfully from source commit `f15f29f`. SHA256: Customer `0e9abf60b606c0458302a4e8bd68a0e69ade877049c5a6ffd24167dfe006da61`; Captain `998f5096e12a87f5db64c46cfad9223a415b2a0010a11127e809ca3479981b25`. These artifacts have not yet been uploaded to Play; Play delivery and its signing certificates remain separate acceptance gates.

Physical OnePlus checks confirmed the saved 3 km circle persists, the radius reaches 10 km and restores to 3 km, and the existing work-hours editor changes from 4 AM–10 PM to 6 AM–10 PM and restores without saving a different schedule. The owner entered a public area name directly through OnePlus Secure Keyboard; both the owner and the laptop screenshot confirmed multiple live, selectable Google place suggestions. The secure keyboard itself is not mirrored; no security setting was disabled. The Captain remains unapproved and Offline.

Final profile APKs from `f15f29f` both built and installed successfully while preserving app data. Device package read-back confirmed updates on 1 November at 16:52 (Customer) and 16:56 (Captain), IST. SHA256: Customer `50053a1cc31d59c1250ab92b67c81f3646c4247848b59920898dad2ebd93d36c`; Captain `4341380e8ee54a9463faca27d5b4cf2c0e1f0b25df429a72f6ba8b2a7bafade5`. These are USB acceptance builds using the existing debug certificate, not Play-delivered installs. Both private AAB signatures verify locally; Play upload/signing/OTP checks remain separate.

Aman supplied the paid-team APNs key privately on 1 November. Its local file parses as an EC P-256 private key and the provided Team ID matches both apps. The standard Windows picker completed all four Firebase uploads; saved development and production key rows were visually verified for Customer and Captain. The key stays outside Git, and `.p8` files are ignored. Firebase configuration does not establish physical iPhone OTP/push delivery. See [APPLE-PUSH-SETUP-2026-11-01.md](APPLE-PUSH-SETUP-2026-11-01.md).

After the initial APK checks, the new map/form controls were refined to Captain touch-target sizes, and the existing Home KYC card now distinguishes a missing serving area from submitted documents awaiting review. This changes live status text/handlers only, preserving the card layout and the demo reference. The final targeted Captain tests (9) and edited-screen analysis pass. New published web/native artifacts must include this refinement before recording final UI acceptance.

## Guest checkout preservation

The new manual/Google map flow keeps the authored Customer login at checkout. A guest can confirm the pin locally and request availability at that exact coordinate; this public read returns only slot booleans, never Captain identities/coordinates. Only after real phone login does the app register/validate the final address and create the paid booking. No guest can create an order or spend wallet credit. After OTP, Review takes precedence over an earlier manual-address page so checkout does not jump backwards. Added tests cover both Review and the legacy early address-login return, plus guest map availability/invalid coordinates/unapproved coverage.

The complete baseline backend suite passed 168 tests, followed by six focused coverage/guest tests after this refinement. The two added Customer checkout-return tests pass. The live cutover status read found zero legacy pending-payment, searching or assigned bookings, and zero new area bookings; no production booking was created as a test. Google Places session tokens rotate after each Captain selection so editing the location again starts a fresh provider session.
