# CU-BOOKINGS — Bookings, detail, Book again

Feature map: [FEATURES.md](FEATURES.md). Screens: C43–C45.

## 5 Nov 2026 — Prefilled Book again

- **Why (Aman):** rebooking should not repeat the whole booking flow. Show what was
  used last time, let the customer change only what they want, ask about fresh photos,
  then go to the time.
- **Branch:** `v2/cu-bookings-rebook` (base `ecafb1b`, the submitted version 1 + docs).
- **Figma:** to be added (C45 redesign).
- **Screens:** C45 Book again redesigned. Reuses C05 (vehicle type), C05w (wash),
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

Below the cards: **Fresh photos of the vehicle?**
- *Yes, take new photos* → C07 photos → C12 time (place step skipped, it is already set).
- *No, go to time* → C12 time directly.

The button reads **Take photos** or **Pick a time** and is enabled once an answer is chosen.
After C12 the normal C13 check and pay and payment follow. Back from any step returns
to the previous screen as before. Changing the vehicle to a type the old wash does not
suit resets the wash to "Wet wash, outside".

Old photos are never reused: every Book again starts with no photos, as before.

### Files changed

- `apps/flutter/customer/lib/data/store.dart` — `RepeatEdit` enum; `BookingDraft.repeatFrom`,
  `editing`, `freshPhotos`; `AppStore.openRepeat`, `editRepeat`, `finishRepeatEdit`;
  `AppRouter.popTo`.
- `apps/flutter/customer/lib/screens/home.dart` — C45 `RepeatScreen` rebuilt from the draft
  (`_RepeatSection`, `_RepeatChoice`); the three entry points call `openRepeat` first.
- `apps/flutter/customer/lib/screens/booking.dart` — Next/Done on C05, C05w, C06, C11 return
  to C45 when changing from Book again; photos lead to time in a Book again.
- `apps/flutter/customer/lib/screens/gallery.dart` — C45 sample opens a prefilled draft.
- `apps/flutter/customer/test/book_again_test.dart` — 4 new tests.

### Backend needed (Ajay)

**None.** The booking is created exactly as a normal booking (same draft fields, same
place save, availability and checkout). No photo reuse, no new fields or functions.

### How to test on the iPhone

1. Home → tap a Book again card. All three cards are filled; nothing is asked yet except photos.
2. Change → Wash: pick another wash → Done → back on Book again with the new wash.
3. Change → Vehicle: change type/number → Done → back with the new vehicle (no wash step).
4. Change → Place: move the pin / floor / notes → Done → back with the new place.
5. Choose *No, go to time* → Pick a time → time windows → Check and pay shows all edits.
6. Repeat with *Yes, take new photos* → photos screen → Next → time.
7. Back arrow on any Change step returns to Book again with nothing lost.

### Status

Built; `flutter analyze` clean; Customer tests 84/84 pass. iPhone test: pending.
