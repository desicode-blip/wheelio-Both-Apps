# Backend hook-up list (app side)

> **Read this first whenever the backend is being connected.** Started 16 Oct 2026.
> Every item below is something the apps currently fake on the phone (sample data,
> demo timers, test buttons) that must be switched to real data or removed.
> The reference code is the SwiftUI apps in `apps/ios/`; the Flutter apps must do the
> same when they are ported. Search the code for `BACKEND`, `Demo` and `TestFlags`
> to find each spot. Accounts, keys and approvals are in `CONNECT-LATER.md`.
>
> Keep this list current: add a line whenever a new screen fakes something, and tick
> a line off (move it to "Done") only when it works against the real backend.

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

## 6. Values still to decide (config, not code)

Prices, cancellation fee, wait fee, approval and dispute windows, late-penalty
amount and cap, offer timers (60 s + 30 s), plan reminder (25 min), resend wait and
limits (15 s, 3 tries, 10 min), support numbers, terms and privacy URLs, final brand
name. Keep them in server config; see also the list at the end of `CONNECT-LATER.md`.

## Done

(nothing yet)
