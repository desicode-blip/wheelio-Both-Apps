# CU-CARE — vehicle check and care routine

**12 Nov 2026, Aman.** After the photos, the booking confirms which vehicle it is and shows
a short care routine for it. The Captain sees the same routine on the job.

## Customer flow (Book a wash)

Photos → **Is this your vehicle?** → **Your care routine** → place / time (as before).

1. **Checking your photos:** a short wait while AI reads the photos.
2. **Is this your vehicle?** Front photo, then the name in big type (e.g. *Hyundai Creta*), with
   Colour and Paint (Glossy / Matte) under it. "Found by AI from your photos."
   - **Yes, that's it:** saved, on to the care routine.
   - **No, edit details:** the form below, prefilled with what AI found.
3. **Tell us about your vehicle** (optional, *Skip* always there): Company, Model, Colour,
   Paint (Glossy / Matte / Not sure), Seats for cars (Fabric / Leather / Not sure).
   "The more we know, the better your Captain cares for it."
4. **Your care routine:** 2–3 cards (icon, short title, one line), e.g.
   - Matte paint → *Matte-safe wash*: mild shampoo, no wax or polish, patted dry.
   - Glossy → *Gloss kept bright*: two-bucket wash, microfibre dry.
   - Leather seats + interior → *Leather seats: no water*: dry microfibre only, no wet wipes.
   - Bike → *Electrics kept dry*: low pressure near chain, engine, switches.
   - Dark paint → *No swirl marks*; white/silver → *Edges and lower panels*.
   - Always last: *Spot-free finish*.

When are the steps skipped?
- No photos taken → straight on, as before.
- Skip on the form → straight on; nothing is sent.
- Same number plate booked again on this phone → "Same vehicle as before?" with the saved details
  (one tap), no AI call.
- Adding a vehicle (not booking) → unchanged.

## Captain

The job's booking card (wash screen) gets **Care for this vehicle**: the vehicle line
("Hyundai Creta · White · Matte paint · Leather seats") and the routine as ticked lines.

## Server work (Ajay)

- **`identifyVehicle` callable:** input `{vehicleKind, images: [base64 JPEG, up to 2, ≤ 1.5 MB each]}`
  (front first). Output `{make, model, color, finish: glossy|matte|unknown, confidence 0–1}`. The app
  ignores results under 0.6 confidence and shows the form instead. Same Google AI project as the
  wash-photo check. **Consent:** these are the customer's own photos sent to Google AI; add a line
  to the privacy policy / consent before switching on.
- **Switch:** `config/operations.vehicleAi = true`. Until then live builds skip AI and show the
  optional form after the photos (sample builds show a sample result).
- **Booking:** `createBooking` now receives `vehicleProfile: {make, model, color, finish, seats, source: ai|customer}`
  and `careRoutine: [{title, detail}]`. Copy both onto the order and the Captain's job/offer
  documents. Later: keep the profile on the customer's saved vehicle (today it is kept on the phone,
  keyed by number plate).

## Files

`customer/lib/features/vehicle_profile.dart` (model, care rules, AI call),
`customer/lib/features/vehicle_care_screens.dart` (screens), `booking.dart` (Photos → Next),
`store.dart` (draft fields, booking map, routes), `main.dart`;
`captain/lib/features/v2_job.dart`, `captain/lib/screens/parts.dart`, sample job j8.
Tests: `customer/test/vehicle_care_test.dart`, `captain/test/care_routine_job_test.dart`.
