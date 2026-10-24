# Backend hook-up list (app side)

## 22 October 2026 acceptance update

Browser testing found and fixed Captain application recovery, a location-permission hang, and arrival/wash-description feedback. No live screen or lifecycle transition was replaced with a fake. Disposable approved accounts, dummy photos and synthetic coordinates exist only in the guarded local `demo-wheelio` fixtures. Actual Razorpay test checkout passed on 21 October; completed browser and release acceptance is recorded in [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md).

On 22 October, unpaid-booking recovery, Finish/photo review, approval/rating, earnings, dispute holds and both actual provider test refunds were verified. The initially rejected netbanking refund processed in full after an explicit ₹100 virtual merchant-balance test payment, separate from customer bookings and never deployed. Refund recovery now backs off, finds existing refunds before retrying, prevents stale-worker regressions and exposes safe delayed/review copy with an existing-refund status check. Hosting and the changed payment/refund Functions were deployed. Repeat booking no longer implies connected WhatsApp gate-pass handling or a sample voice note. The guarded prepare-wash fixture simulates capture only in local demo-wheelio; separate actual Razorpay test captures/refunds were independently verified. No production account, captain, booking or fixed OTP was fabricated. No new app screen fakes data.

## 21 October 2026 implementation update

The Firebase paid-booking implementation is documented in [FIREBASE-BOOKINGS.md](FIREBASE-BOOKINGS.md). Phone OTP, server prices/capacity, real persisted orders, Razorpay order/capture verification, private uploads, online captains, expiring private offers, atomic assignment, arrival/wash/evidence stages, optional foreground location, customer approval/rating, refund processing and earnings now have server controllers and emulator coverage. Deployment and real merchant/account/paid-flow acceptance are separate checks; test credentials cannot take live payments.

The test-payment web release, all 22 Functions, rules, indexes and private-photo browser settings are deployed. Hosted capacity requests succeed and honestly show no availability until actual captains are approved. The builder checks web plugin registration after clearing stale caches; availability failures have a retry action. On 21 October the owner confirmed receiving real SMS OTPs; the name was then saved at their request and the signed-in Profile page confirmed account completion. The completed test-payment browser checks and their replay boundaries are recorded in WEB-ACCEPTANCE.md. Wheelio has a separate test webhook on the existing Trustkeyper merchant; unrelated merchant events cannot create Wheelio bookings. Aman is handling merchant onboarding, so live keys and live webhook registration remain pending.

Normal URLs use those controllers. Sample queues, extra-offer timers, sample captain/owner details, fixed OTPs, fake upload progress, midnight approval, made-up bank refunds/payouts and demo KYC/AI outcomes remain confined to `?demo=true`. No new screen fakes backend data. The live UI's timers only display actual offer expiry, refresh location freshness, send an online heartbeat, and share a user-authorized location; they do not invent job transitions.

Live notes are text only. Location displays actual coordinates and a map link, with no fake pin or ETA. Captain approval, payout transfers and dispute decisions need real operations. Voice/video recording, FCM/background tracking, AI/face checks, masked calls, account deletion and phone changes remain unconnected and are not presented as successful live actions. The historical checklists below still enumerate the full demo scope.

> **Read this first whenever the backend is being connected.** Started 16 Oct 2026.
> Every item below is something the apps currently fake on the phone (sample data,
> demo timers, test buttons) that must be switched to real data or removed.
> **Flutter (`apps/flutter/`) is the development stack** and already has every item below
> (16 Oct 2026). File names below are the SwiftUI reference in `apps/ios/`; the Flutter
> files of the same name are listed under "Where it is in Flutter". Search either codebase
> for `BACKEND`, `Demo` and `TestFlags` / `onboardingSkip` / `planClockTest` to find each
> spot. Accounts, keys and approvals are in `CONNECT-LATER.md`.
>
> Keep this list current: add a line whenever a new screen fakes something, and tick
> a line off (move it to "Done") only when it works against the real backend.

## Where it is in Flutter

| SwiftUI reference | Flutter |
|---|---|
| `Captain/Data/CaptainStore.swift`, `WNotifications.swift` | `apps/flutter/captain/lib/data/store.dart` (`planNow`, `planSkipSeconds`, `planAlerts`, `openWNotif`) |
| `TestFlags.onboardingSkip`, `TestFlags.planClock` | `onboardingSkip`, `planClockTest` in `captain/lib/screens/onboarding.dart` |
| `HomeJobScreens.swift` (`DayPlan`, `JobAlertScreen`) | `captain/lib/screens/home.dart` |
| `WWelcomeScreens.swift`, `WOtpScreen` (resend, edit number) | `captain/lib/screens/welcome.dart` |
| `Customer/App/DesignFlags.swift` | `customer/lib/app/design_flags.dart` |
| `Customer/Data/AppStore.swift` | `customer/lib/data/store.dart` |
| `BookingScreens.swift` (`EntryNotesScreen`, photos) | `customer/lib/screens/booking.dart` |
| Screens galleries | `captain/lib/screens/gallery.dart`, `customer/lib/screens/gallery.dart` |

## Native iPhone builds (added 23 Oct 2026)

The Flutter apps now have an `ios` platform, but phone builds run on sample data
(`WHEELIO_DEMO=true` in `tool/run-ios.sh`). Before a phone build can use the live backend:

- [ ] Register the iOS apps `com.amanmaheshwari.wheelio.customer` and `com.amanmaheshwari.wheelio.captain` in Firebase project `wheelio-apps` (owner: ajay@trustkeyper.com) and pass their iOS app IDs, plus `iosBundleId`, in `WheelioFirebase.initialize()`.
- [ ] Phone sign-in: `signInWithPhoneNumber` / `linkWithPhoneNumber` are web-only. Add the native `verifyPhoneNumber` flow (`live_backend.dart`, `portal.dart`), with an APNs key in Firebase or the reCAPTCHA URL scheme (encoded iOS app ID) in `Info.plist`.
- [ ] Razorpay: `checkout_stub.dart` throws on phones. Add the native Razorpay SDK for iOS.
- [ ] Push notifications (APNs key, FCM) and the paid Apple Developer account for TestFlight; the free account allows 3 apps on the phone and builds expire after 7 days.
- [ ] Remove `WHEELIO_DEMO` from `tool/run-ios.sh` once the above work.

## 0. Remove before launch (test-only switches)

- [ ] Captain `TestFlags.onboardingSkip`: "TEST ONLY · Skip onboarding" button (`Captain/Screens/OnboardingScreens.swift`).
- [ ] Captain `TestFlags.planClock`: "TEST +5 min" button on Today's plan (`HomeJobScreens.swift`, `DayPlan`).
- [ ] "Demo code: 123456" captions on code screens (Captain `WAccountScreens.swift`, Customer `AuthPayScreens.swift`, `SupportScreens.swift`).
- [ ] "Demo: call done →" link on the Captain intro-call step (`OnboardingScreens.swift`).
- [ ] Screens gallery tab and demo switches in both apps (`Captain/App/CaptainApp.swift`, `Customer/App/CustomerApp.swift`, `GalleryScreen.swift`, `resetDemo()`).
- [ ] Customer `DesignFlags` (hidden designs): decide per flag, see `hidden-designs.md`.

## 1. Captain: sign-up, login, KYC

- [ ] Send the SMS code when "Get code" is tapped (sign-up and login).
- [ ] Verify the code on Next. Today any 6 digits pass and the SMS auto-read is faked (`WOtpScreen`, "381624"). Use the Android SMS Retriever / iOS one-time-code autofill for real auto-read.
- [ ] Resend code: call the server in `WOtpScreen.resend()`. The 15 s wait and 3-resend limit ("try after 10 minutes") must match the server's rate limit.
- [ ] Edit number from the code screen: invalidate the old code when the number changes.
- [ ] Login: load the returning captain's profile and KYC status (today login marks `signedUp = true`).
- [ ] Guest mode: nothing is stored server-side until sign-up; then create the captain record.
- [ ] KYC (only when accepting the first job): upload Aadhaar/PAN/selfie, bank or UPI details, store status (`finishKyc`).
- [ ] Onboarding training videos: real YouTube video IDs (today a 6-second stand-in).
- [ ] Quiz: questions and answers from the server, save the result.
- [ ] Intro call step: real call booking / completion signal.
- [ ] Change phone number and change payout UPI: code to the registered phone first (`CaptainStore` BACKEND notes).

## 2. Captain: going online and jobs

- [ ] Online / Offline toggle (Home header and the new "Go offline" pill on the job alert): send status to the server; stop job pushes when offline.
- [ ] Captain location while online (today `CaptainStore` "where the phone is right now" is fixed).
- [ ] "Where I work" (all / societies / distance / place): save to the server and filter offers server-side (today `wantsJob` filters the sample pool on the phone).
- [ ] Job offers: real push + in-app stack. Today offers come from `CaptainStore.offerPool` and extra jobs "ring" at 6 s and 13 s.
- [ ] Offer timer: 60 s to decide, then 30 s greyed "Opportunity missed" before the card leaves. The server must own the expiry (who gets the job) and the app should show server time left.
- [ ] Accept: atomic claim on the server (handle "someone else took it"). Reject: tell the server so the job goes to the next captain.
- [ ] Daily job limit / level (W24) from the server.
- [ ] Today's plan: load the captain's accepted jobs with real time windows (today `sampleQueue`).
- [ ] **Plan clock:** replace the demo clock (`CaptainStore.planNow`, starts at 9:29:20 AM) with real time. Remove `planSkip`. Reset the demo window change for the 2nd sample job ("9:30–11:30").
- [ ] **Plan alerts** (window opened, 25 min left and not started, running late): the app fires them only while Home is open. Send them as server-scheduled pushes so they arrive when the app is closed; keep the in-app banners. Use the server's "job started" state instead of `ownerNoteHeard`.
- [ ] Late penalty "−₹1 every late minute" and the cap: from config, not hard-coded text.
- [ ] Starting a job in any order (`startJob`): tell the server which job is current.

## 3. Captain: doing the job

- [ ] Full address, society, spot, plate and booking (wash type, water, inside): from the order.
- [ ] Vehicle photos (front/back/left/right) on Go to vehicle: owner's real photos (`BookingVisual.swift`, `VehiclePhotoView`).
- [ ] Owner's note: play the owner's recorded audio/video (today the phone's voice reads sample text, `NotePlayer`). Save "heard" on the server.
- [ ] "I'm at the vehicle": send arrival (with location) to the server; this is what stops the late / no-show timers.
- [ ] Before and after photos: upload to storage, then AI photo check.
- [ ] Gate pass ready, owner cancelled, can't get in, can't find vehicle, no-show flow: real events (today `startNoShowDemo`).
- [ ] Finish job: mark done on the server; earnings update from the server, not `earnedToday += pay`.

## 4. Captain: money, help, notifications

- [ ] Earnings, waiting money, payouts, money on hold: from the server.
- [ ] Ratings and the level / probation / blocked states: from the server.
- [ ] Notifications: register for push (APNs/FCM), save the token; the inbox is server data.
- [ ] Help ladder: app quick check → owner → team callback. Connect masked calling to the owner and a callback request to the team. Emergency row calls the real number.
- [ ] Help topic flows (money, job, rating, app): create a support ticket.
- [ ] Language choice: save to the profile so pushes come in the right language.

## 5. Customer app

- [ ] Login: send / verify code (today 123456 works, 000000 is expired; `AppStore` auth BACKEND notes). Change number the same way.
- [ ] Vehicles, places, slots: from the server (today early slots look full on purpose).
- [ ] Photos and walk-around video: real camera capture and storage upload (today the back photo can fail once by design).
- [ ] Entry notes: real video / voice recording and upload, one of them plus optional text (`EntryNotesScreen`, `record()` demo).
- [ ] Map and pin: Google Maps (`MapPlaceholder`).
- [ ] Create order + Razorpay checkout, money held until approval (`AppStore` create_order).
- [ ] Live order steps: real status from the server (today a timer with `stepSeconds`; demo switches for no captain, late, no-show, can't find, entry pass).
- [ ] Cancel (with `[CANCELLATION FEE]` once decided), approve (releases money), report a problem and dispute result.
- [ ] Notifications inbox and push (today `seedSampleNotifications`).
- [ ] Free washes / credit on the account.

## Address typed by hand (added 24 Oct 2026)

- [ ] Customer C09d "Type your address" (sample-data app only for now): the address is kept on the phone as a
      `Society` with id `manual-…`. Save it on the server, check the pincode/area is served and tell the customer
      before payment (the screen promises this), and add the same "Enter address by hand" link to the live app,
      which today shows only listed societies.

## Several time windows / any time (added 24 Oct 2026)

- [ ] Customer C12: the sample-data app lets people pick several windows or "Any time of the day"
      (`TimeSlot.windows`, `TimeSlot.anyTime`). The live app still sends one window (`startHour`/`endHour`).
      To turn it on live: accept a list of windows (or an any-time flag) in `createOrder`, check capacity for
      each in `getAvailability`, assign captains within them, and base late / slot-ended messages on the
      last window's end.

## Cancelling and free washes (added 24 Oct 2026)

- [ ] New rule (sample app): customers can cancel only within **15 minutes of booking** (`BusinessRules.cancelWindow`),
      and get **no refund** but **1 free wash** credited instead. The live `cancelBooking` function still refunds:
      change it to enforce the window on the server (booking time from the server, not the phone), credit the free wash
      to the customer record, and send the "Booking cancelled · 1 free wash added" notification.
- [ ] Free washes: keep the count on the server; a booking paid with a free wash skips Razorpay (`price` 0).
- [ ] Bookings for a later slot stay "Booked" until the slot; captains are assigned before it. The live lifecycle
      should not show captain, wash or before/after photos before the slot starts.

## 6. Values still to decide (config, not code)

Prices, cancellation fee, wait fee, approval and dispute windows, late-penalty
amount and cap, offer timers (60 s + 30 s), plan reminder (25 min), resend wait and
limits (15 s, 3 tries, 10 min), support numbers, terms and privacy URLs, final brand
name. Keep them in server config; see also the list at the end of `CONNECT-LATER.md`.

## Done

### 20 October 2026: Firebase prelaunch portal

- Live email/password registration, login, persistent session, reset and logout in shared Flutter `packages/wheelio_firebase/`. Phone SMS has an implementation but its UI is hidden unless `FIREBASE_PHONE_AUTH_ENABLED=true`; do not enable it before provider/billing configuration and verification.
- Live profile creation/update in Firestore `users/{uid}`. No sample customer is inserted in live mode.
- Customer wash **requests** save to `washRequests` with realtime history and owner cancellation. These are prelaunch interest records, not paid or confirmed bookings. No simulated captain assignment, payment or wash timer runs on these records.
- Captain interest saves privately to `captainApplications/{uid}`. Clients cannot approve KYC or access jobs/payouts.
- Firestore security rules and owner/time index; emulator tests for account isolation and protected states.
- Both complete designed demo apps remain accessible only with `?demo=true`; their persistent demo strip identifies sample data. Every item still unchecked above remains unfinished for the designed production wash flow.
