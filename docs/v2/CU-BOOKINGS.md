# CU-BOOKINGS — Bookings, detail, Book again

Feature map: [FEATURES.md](FEATURES.md). Screens: C43–C45.

## 5 Nov 2026 — Prefilled Book again

- **Why (Aman):** rebooking should not repeat the whole booking flow. Show what was
  used last time, let the customer change only what they want, ask about fresh photos,
  then go to the time.
- **Branch:** `v2/cu-bookings-rebook` (base `ecafb1b`, the submitted version 1 + docs).
- **Figma:** to be added (C45 redesign).
- **Screens:** C45 Book again redesigned. Reuses C05 (vehicle type), C05w (wash), new C45b (Book again – photos),
  C06 (vehicle number), C07/C08 (photos), C09–C11 (place), C12 (time), C13 (check and pay).

### What changes for the customer

Entry points (unchanged): Home → Book again card, Bookings → past booking → Book again,
Vehicles → tap a vehicle.

C45 now shows three prefilled cards, each with **Change**:

| Card | Shows | Change opens | Then |
|---|---|---|---|
| Vehicle | plate, type | C05 vehicle type → C06 number (wash step skipped) | **Done** returns to C45 |
| Wash | wash kind, detail, price | C05w wash type | **Done** returns to C45 |
| Place | place, parking, last notes | C09 location (or search) → C10 floor/slot → C11 notes | **Done** returns to C45 |

**Next** (enabled when vehicle and place are set) opens **C45b Book again – photos**
(added 5 Nov, Aman's review):

- Shows the customer's 4 photos from the booking being repeated (or the latest booking of
  that vehicle that has photos), in a 2×2 grid. Older photos may already be deleted after 90 days.
- Primary: **Use these photos** → C12 time. When there are no old photos the primary
  becomes **Continue without photos**.
- Secondary (outline): **Take fresh photos** → C07 photos → C12 time.
- Text link (only when old photos exist): **Continue without photos** → C12 time.

After C12 the normal C13 check and pay and payment follow. Back from any step returns
to the previous screen as before. Changing the vehicle to a type the old wash does not
suit resets the wash to "Wet wash, outside".

Fresh photos always start empty. Choosing **Use these photos** only records which booking's
photos to reuse (`draft.reusePhotosFrom`); see Backend needed.

### Files changed

- `apps/flutter/customer/lib/data/store.dart` — `RepeatEdit` enum; `BookingDraft.repeatFrom`,
  `editing`, `lastPhotoPaths`, `lastPhotosOrderId`, `reusePhotosFrom`; route `N.repeatPhotos`; `AppStore.openRepeat`, `editRepeat`, `finishRepeatEdit`;
  `AppRouter.popTo`.
- `apps/flutter/customer/lib/screens/home.dart` — C45 `RepeatScreen` rebuilt from the draft
  (`_RepeatSection`); new C45b `RepeatPhotosScreen`; the three entry points call `openRepeat` first.
- `apps/flutter/customer/lib/main.dart` — route `N.repeatPhotos`.
- `apps/flutter/customer/lib/screens/booking.dart` — Next/Done on C05, C05w, C06, C11 return
  to C45 when changing from Book again; photos lead to time in a Book again.
- `apps/flutter/customer/lib/screens/gallery.dart` — C45 sample opens a prefilled draft.
- `apps/flutter/customer/test/book_again_test.dart` — 5 new tests.

### Backend needed (Ajay)

- **Reuse old photos (new):** when `draft.reusePhotosFrom` is set (a previous booking id of the
  same customer), copy that booking's `customerPhotos` onto the new booking, e.g. in
  `createBooking`/a small callable `reuseCustomerPhotos(fromBookingId, toBookingId)`.
  Check ownership, copy (do not move) the Storage objects so each booking keeps its own
  retention, and set `customerSkippedPhotos` accordingly. Until this is connected, a
  booking made with "Use these photos" is created **without** customer photos (same as
  "Continue without photos"). Nothing else changes: same draft fields, place save,
  availability and checkout.

### How to test on the iPhone

1. Home → tap a Book again card. All three cards are filled.
2. Change → Wash: pick another wash → Done → back on Book again with the new wash.
3. Change → Vehicle: change type/number → Done → back with the new vehicle (no wash step).
4. Change → Place: move the pin / floor / notes → Done → back with the new place.
5. Next → photos screen → *Continue without photos* → time slots → Check and pay shows all edits.
6. Book again → Next → photos screen shows last time's photos → *Use these photos* → time.
7. Same, but *Take fresh photos* → 4 photos → Next → time.
8. Back arrow on any Change step returns to Book again with nothing lost.

### Status

Built; `flutter analyze` clean; Customer tests 85/85 pass. iPhone: first version tested by Aman
(5 Nov 10:03); photos moved to C45b after his review; retest pending.
