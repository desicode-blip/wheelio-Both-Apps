# CU-PHOTOS — Vehicle photos before booking

Feature map: [FEATURES.md](FEATURES.md). Screens: C07–C08b.

## 5 Nov 2026 — Side name above the camera outline (C08)

- **Why (Aman):** make it obvious which side of the vehicle to shoot.
- **Screens:** C08 camera.
- **What changed for the user:** the side is written in capitals right above the dotted
  outline — FRONT, BACK, LEFT, RIGHT — in the same white (90%) as the dotted line, with
  the same soft dark edge so it reads on bright backgrounds. It changes with each photo.
  The title bar and the "Fit the … in the outline" line stay as they were.
- **Files changed:** `customer/lib/screens/booking.dart` (camera screen).
- **Backend needed (Ajay):** none.
- **How to test on the phone:** book a wash → Take photos → each step shows the side name
  above the outline.
- **Status:** built; analyze clean; Customer tests 97/97. iPhone check pending.
