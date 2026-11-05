# CU-VEHICLE — Vehicle type, number, saved vehicles

Feature map: [FEATURES.md](FEATURES.md). Screens: C05, C06, C46; new C04.

## 5 Nov 2026 — Add a vehicle without booking; book from a saved vehicle

- **Why (Aman):** "Add a vehicle" opened the whole booking flow. It should only save a
  vehicle. And a new booking should let the customer reuse a saved vehicle, then choose
  old photos, new photos or none.
- **Branch:** `v2/cu-bookings-rebook`.

### What changes for the customer

**Add a vehicle (Vehicles tab → Add a vehicle):**
C05 with header "Add a vehicle" (no step bar), title "What kind of vehicle?", subtitle
"Save it once. Book a wash for it any time." → C06 number plate, button **Save vehicle** →
back to Vehicles with the toast "Vehicle saved". No wash, photos, place or time.
The same plate cannot be saved twice ("This vehicle is already saved.").

**Book a wash with saved vehicles (all Book a wash buttons):**
New first screen **C04 Which vehicle?** lists the saved vehicles (same cards as the
Vehicles tab) and **Add another vehicle** (the normal flow from C05).
Tapping a saved vehicle → C05w wash → **C45b photos step** (shared with Book again):
last booking's photos for that vehicle → **Use these photos** / **Take fresh photos** /
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
- `customer/test/vehicles_test.dart` — 4 new tests.

### Backend needed (Ajay)

1. **Saved vehicles on the account.** Today vehicles only come from past bookings. Add
   `customers/{uid}/vehicles/{id}` (`plate`, `kind`, `createdAt`) with a Customer-only
   callable `saveCustomerVehicle` (validate plate format, no duplicates) and later
   rename/delete. Stream them into `AppStore.vehicles` and drop the device copy in
   `saveNewVehicle`/`loadLocalVehicles`. Until then vehicles added this way stay on the
   phone (per account) and are not seen on another phone.
2. **Reuse old photos** — same as CU-BOOKINGS: copy the chosen booking's `customerPhotos`
   onto the new booking when `draft.reusePhotosFrom` is set.
3. Include saved vehicles in account deletion.

### How to test on the iPhone

1. Vehicles → Add a vehicle → pick type → Next → enter plate → Save vehicle → back on
   Vehicles, the new one is listed. Try the same plate again → "already saved".
2. Home → Book a wash → Which vehicle? → tap a saved vehicle → wash → photos step →
   choose one option → place → time → Check and pay shows that vehicle.
3. Which vehicle? → Add another vehicle → normal flow from vehicle type.

### Status

Built; analyze clean; Customer 89/89 tests pass. iPhone test pending.
