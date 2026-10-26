# P0: backend and functionality needed for the designed screens

**26 October update:** this file retains the original design gap checklist for acceptance. Many implementation gaps below are now connected, locally tested and published in test mode; read the current behavior, release checks and remaining gates in [FUNCTIONALITY-2026-10-26.md](FUNCTIONALITY-2026-10-26.md). Unticked items are not claims that their implemented server paths are absent. They remain open for their full stated external/native/operational acceptance. Do not replace the staging design to clear this checklist.

**Owner: Ajay. Priority: P0 (first).** Requested by Aman on 25 October 2026.

On 25 October the real-data (Firebase) apps were changed to use **exactly the designed screens** from the
design reference (staging commit `31fa906`, 25 Oct 09:25 IST). Before this, the real-data builds replaced
many designed screens with plain generic ones (Customer: one order screen for everything after payment,
simpler notifications/help/profile; Captain: one generic screen for the whole app after login).

The UI is now the design. The items below are **built in the UI but not yet backed by the backend or real
functionality**. Until each is done, the app does not fake success: an action that has no backend yet shows
the toast "This isn’t available yet. Call us and we’ll do it for you." (Customer: `AppStore.blockLive`;
Captain: `CaptainStore.blockLive`), and values the server does not provide fall back as noted.

Please treat every item as **P0**. Tick an item only when it works end to end against the real backend.

## Customer app

### Booking flow
- [ ] **Location and map (C08 "Is your vehicle here?")**: needs real location permission, a real map
  (Google Maps) and matching the phone's position to a served society. Today the designed map is a drawing;
  the card shows the customer's last booked place, and a first-time customer goes straight to the address
  search.
- [ ] **Payment method choice (C17 pay sheet)**: the designed list (Google Pay, PhonePe, Other UPI app,
  Card) is shown. Every choice opens the same Razorpay checkout. Pass the chosen method to Razorpay
  (`prefill.method` / UPI intent) and show the customer's saved UPI ID under Google Pay when known.
- [ ] **"Get the code on a call instead" (C15 code expired)**: voice OTP is not connected.
- [ ] **Library photos**: the design's camera screen has a shutter only (no "Choose from photos").
  Ajay's "Choose from photos" button was removed to match the design. If photo-library picking is needed,
  it needs a design decision first.
- [ ] **Recorded voice/video playback on Entry notes (C10)**: the designed play button animates; real
  playback of the recorded clip before booking is not wired (upload after booking works).

### After booking
- [ ] **Captain ETA ("Arrives by …", C22)**: no ETA from the server. The app shows the end of the booked
  window as the latest arrival time. Needs a real arrival estimate.
- [ ] **Captain running late / "We’re checking on your wash" / captain no-show (C24, C24x, C25)**: the
  server has no late, checking or no-show states. Designed screens exist; they never appear in real data.
- [ ] **Captain can’t find the vehicle (C30)**: no server event; the customer’s three answers are not
  sent anywhere (tapping shows the "not available yet" toast).
- [ ] **Gate pass on WhatsApp (C19, C22b, "Send pass on WhatsApp", "Message on WhatsApp")**: WhatsApp
  Business messaging is not connected. Buttons show the toast. "Entry pass received" currently maps to the
  captain's arrival (`arrivedAt`), which is not the same thing.
- [ ] **Calling the captain (masked calls)**: the call button dials support. Masked customer↔captain
  calling is not connected.
- [ ] **Live captain location**: the server supports location sharing (`CaptainTracking`), but the design
  has no location view, so it is not shown. Needs a design decision, or design the view.
- [ ] **Rating tags (C27: Spotless, On time, Polite, Missed a spot, Late)**: only the stars are sent
  (`rateWash`). Save the tags.
- [ ] **Problem photos (C32 "Show us the problem")**: the customer’s photos are taken and shown, but not
  uploaded. `reportWashProblem` takes only kind and note. Add photo upload.
- [ ] **Dispute decisions (C34 upheld, C35 rejected, C36 damage priority)**: the server has no outcome,
  refund-plus-bonus, or priority-damage states; only "under review" shows. "Download evidence pack" does
  nothing.
- [ ] **Refund to UPI (C29 "Add UPI ID for refund", C29b)**: refunds go back to the original payment
  method. The designed UPI-ID refund flow is shown; saving the UPI ID shows the toast.
- [ ] **No captain found / auto-cancel refund (C29)**: no server state for "no captain could take your
  wash" with an automatic refund.
- [ ] **Auto-approve at midnight (C28)**: `autoApproveAt` is read, but there is no server state
  `autoApproved`; check the scheduled job sets it and the app shows C28.
- [ ] **Download receipt (C44)**: not connected.

### Account
- [ ] **Change phone number (C47)**: needs OTP to the new number and an account update. Shows the toast.
- [ ] **Delete account (C48)**: not connected. Shows the toast.
- [ ] **Notifications read / delete**: the inbox comes from the server, but "read", "unread" and
  "delete" are kept on the phone only (lost on reinstall). Save them on the server.
- [ ] **Notification wording**: the server writes generic text ("Open WashKrew for the latest booking
  details.") and prefixes test bookings with "Test · ". The app now shows the designed wording built from
  the booking; the server copy should match the design and drop the "Test · " prefix
  (`backend/firebase/functions/src/notifications.mjs`).
- [ ] **Notification settings (C40 quiet hours, mute, categories)**: kept on the phone; push delivery
  ignores them. Save them on the server and respect them when sending.
- [ ] **Profile photo**: kept on the phone only.
- [ ] **Saved places**: shows the last booked place; there is no saved-places list on the server.
- [ ] **Terms and privacy**: no page linked.

### Removed from the real-data screens to match the design (no backend work, but please confirm)
- "Test booking" badges on Home, Bookings and booking detail, and the "TEST PAYMENTS" banner.
- The SMS consent line under the phone number on the login screen ("By continuing, you agree to receive
  an SMS verification code…"). If this is legally required, it needs to be added to the design.
- Alternative wording Ajay added for real data on the welcome slide, payment-failed/pending, repeat
  booking, skip-photos alert and the "held safely" note. The designed wording is used everywhere.

## Captain app

The generic `FirebaseCaptainScreen` was removed. `CaptainStore(live: …)` now fills the designed screens
from Firebase (`data/store.dart`, "Live data" section): sign-up and SMS login, KYC uploads and the
application, Online/Offline, job offers in the designed job alert, claiming, arrival, before/after photos,
start and finish, today's and later jobs, earnings, "When I work" and the inbox.

### Sign-up and KYC
- [ ] **DigiLocker (W05 "Open DigiLocker")**: not connected. The live app photographs the Aadhaar card
  instead and uploads it as `aadhaar`.
- [ ] **Aadhaar "photo is not clear" check (W05b)**: no automatic quality check; the screen never appears
  from real data.
- [ ] **Bank proof**: the server requires `kyc/{uid}/bank.jpg`, but the designed "Get paid" screen only asks
  for a UPI ID. The live app asks for a passbook/cheque photo when Save is tapped. Drop the requirement for
  UPI payouts, or add it to the design.
- [ ] **Bank-account payouts (W08 "Bank account" tab)**: UPI only on the server. The tab shows the toast.
- [ ] **Training videos and quiz (W09–W12)**: shown as designed, but completion is kept on the phone only.
  Store video progress and the quiz result on the server and check them before approval.
- [ ] **Intro video call and its time (W13 "We’ll call you today", "Change time")**: no scheduling.
  "Change time" shows the toast.
- [ ] **Level and job limits (W14 days 1–3, W24 daily limit, W44–W47 level, probation, refresher,
  blocked)**: no server fields. The app reads `captains.levelDay` and `captains.jobLimit` if present;
  otherwise the designed defaults show. Add the rules and fields.

### Jobs
- [ ] **Distance in the job alert ("600 m away")**: offers have no distance. Shown empty.
- [ ] **Vehicle details in the alert**: offers deliberately hide plate and parking until accepted (Ajay's
  privacy rule). The designed alert shows them; confirm with Aman which wins.
- [ ] **Owner’s voice note (W27 "Listen before you start")**: the real note is uploaded by the customer, but
  the designed player plays a sample. The live app skips this screen. Play the real `note_audio` in the
  designed player.
- [ ] **Face check before photos (W28)**: the selfie is taken but not compared with the KYC photo.
- [ ] **Gate pass (W29 "Can’t get in", gate pass row) and "Can’t find vehicle" (W30)**: no server flow;
  the designed screens show sample data.
- [ ] **AI photo check (W36 "Left mirror looks dusty") and dark-photo check (W33)**: not connected; the
  live app skips them.
- [ ] **Late timer, slot-over warning, no-show cancellation and penalty (W26 banners, W52)**: no server
  states. Penalty amounts are placeholders (`[NO-SHOW PENALTY]`).
- [ ] **Owner cancelled after the captain set off: trip fee (W40, `[CANCELLATION FEE]`)**: the cancellation
  is shown (job struck through); the trip fee is not paid by the server.
- [ ] **Live location**: Ajay's location sharing is not in the design; not shown. Needs a design decision.
- [ ] **Societies after approval ("Where I work")**: approved societies come from operations; changing them
  in the app only changes which alerts the phone shows. "You’re at … now" needs location matching.
- [ ] **Distance and place filters ("Within 3 km", "A place I choose")**: no server filter.

### Money
- [ ] **Payout history and payout detail (W41)**: payouts are sent by operations and not recorded for the
  app. The designed rows show only for the sample app; live shows today's/week's earnings and held money.
- [ ] **Held money detail and "Explain by voice" (W42)**: shows sample text.
- [ ] **Change payout UPI and phone number (W54, W55)**: need OTP and an account update. Show the toast.

### Notifications
- [ ] **Captain notification kinds**: the server sends only approved / cancelled / disputed. The design
  also has new job, gate pass, late, window open, finish soon, slot ended, penalty, payout sent, level up,
  probation, blocked and phone changed. Read/delete are kept on the phone only.
