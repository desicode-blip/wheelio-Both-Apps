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
