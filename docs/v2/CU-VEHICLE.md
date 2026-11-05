# CU-VEHICLE — Vehicle type, number, saved vehicles

Feature map: [FEATURES.md](FEATURES.md). Screens: C05, C06, C46; new C04.

## 5 Nov 2026 — Add and edit vehicles on the phone; book from a saved vehicle

- **Why (Aman):** "Add a vehicle" opened the whole booking flow. It should only save a
  vehicle. And a new booking should let the customer reuse a saved vehicle, then choose
  old photos, new photos or none.
- **Branch:** `v2/cu-bookings-rebook`.

### What changes for the customer

**Where vehicles live (Aman, 5 Nov):** vehicles added here and their photos are stored
**only on the customer's phone** (per account). Nothing is sent to WashKrew or a Captain
until the customer uses that vehicle in a booking; then the photos go with the booking
through the existing booking upload. Deleting the account clears them from the phone.

**Add a vehicle (Vehicles tab → Add a vehicle):**
C05 with header "Add a vehicle" (no step bar), title "What kind of vehicle?", subtitle
"Save it once. Book a wash for it any time.", **no prices or wash times** (5 Nov review)
→ C06 number plate, subtitle "So your Captain finds the right vehicle. You can add it
later." with a quiet grey **Skip for now** link under Next (same plate twice → "This
vehicle is already saved."). A skipped plate shows as "Number plate not added" and is
asked for when that vehicle is booked → C07 photos, **optional**: title "Add photos (optional)",
tip "Keep the number plate visible in at least one photo. You can also add photos later."
**Save vehicle** (with 1–4 photos) or **Skip, add photos later** → back to Vehicles with
"Vehicle saved". No wash, place or time.

**Edit vehicle (new C46b; Vehicles tab → Edit, or "Edit · add photos" when it has none):**
type chips and number plate (for vehicles added on the phone; vehicles known from past
bookings keep their type and plate), and the 4 photos in a 2×2 grid. Every photo has a
small camera button; tapping a photo or an empty slot asks **Take photo / Choose from
gallery**. **Save changes** → "Vehicle updated". Tapping the vehicle card itself still opens
Book again.

**Book a wash with saved vehicles (all Book a wash buttons):**
New first screen **C04 Which vehicle?** lists the saved vehicles (same cards as the
Vehicles tab) and **Add another vehicle** (the normal flow from C05).
Tapping a saved vehicle → C05w wash → **C45b photos step** (shared with Book again):
the vehicle's saved photos (from the phone), or else its last booking's photos → **Use these photos** / **Take fresh photos** /
**Continue without photos** (or only the last two when there are no old photos) →
C09 place → C10 → C11 → C12 time → C13 pay. The number plate step is skipped.
Customers with no saved vehicles start at C05 as before.

### Files changed

- `customer/lib/screens/booking.dart` — new C04 `VehiclePickScreen`; C05/C06 add-vehicle mode;
  C05w goes to the photos step for a saved vehicle.
- `customer/lib/screens/home.dart` — Add a vehicle uses add mode; Book a wash starts at
  `firstBookingStep`; C45b header and next step work for both Book again and saved vehicles;
  saved vehicles load when Home opens.
- `customer/lib/screens/live.dart`, `support.dart` — "Book again/another" starts at `firstBookingStep`.
- `customer/lib/data/store.dart` — `addingVehicle`, `pickedVehicleId`; `localVehicles`,
  `loadLocalVehicles`, `startAddVehicle`, `saveNewVehicle`, `pickVehicleForBooking`,
  `firstBookingStep`; route `vehiclePick`.
- `customer/lib/main.dart` — route.
- `packages/washkrew_ui/lib/src/local_flags.dart` — `getList`/`setList` (device storage).
- `customer/lib/screens/home.dart` also: new C46b `VehicleEditScreen`; Edit link on vehicle cards.
- `customer/lib/data/models.dart` — `Vehicle.photos`.
- `packages/washkrew_ui/lib/src/local_flags.dart` — `saveBytes`/`readBytes` for photos on the phone.
- `customer/test/vehicles_test.dart` — 8 new tests.

### Backend needed (Ajay)

1. **None for saved vehicles** — they stay on the phone by design. Photos saved with a
   vehicle are attached to a booking as normal customer photos when used ("Use these photos").
2. **Reuse photos from a past booking** (only when the vehicle has no photos on the phone):
   copy that booking's `customerPhotos` onto the new booking when `draft.reusePhotosFrom`
   is set — same as CU-BOOKINGS.

### How to test on the iPhone

1. Vehicles → Add a vehicle → type → plate → photos: add 1–4 (Save vehicle) or Skip →
   back on Vehicles, the new one is listed. Same plate again → "already saved".
2. Vehicles → Edit → change type, plate or any photo (camera button) → Save changes.
   Close and reopen the app: the vehicle and photos are still there.
3. Home → Book a wash → Which vehicle? → tap a saved vehicle → wash → photos step →
   choose one option → place → time → Check and pay shows that vehicle.
4. Which vehicle? → Add another vehicle → normal flow from vehicle type.

### Status

Built; analyze clean; Customer 95/95 tests pass (incl. tap-through of the add flow). iPhone: Aman tested 5 Nov 19:00; prices and plate skip fixed after review.
