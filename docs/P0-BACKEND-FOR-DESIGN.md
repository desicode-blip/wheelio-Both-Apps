# P0: backend and functionality needed for the designed screens

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

_(Added as the Captain screens are rebuilt; see below.)_
