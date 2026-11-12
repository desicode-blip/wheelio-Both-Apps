# CU-TIME — Time windows and availability

Feature map: [FEATURES.md](FEATURES.md). Screens: C12, C12b.

## 5 Nov 2026 — Clearer heading and checkboxes on time slots

- **Why (Aman):** "When should we come?" sounds like one visit time. The question is when
  the vehicle is free, and several slots can be chosen.
- **Branch:** `v2/cu-bookings-rebook` (made together with Book again).
- **Screens:** C12.

### What changes for the customer

- Heading: **When is your vehicle free?**
- Subtitle (multi-slot): *Tick every time slot when it can be washed. Your Captain comes in one of them.*
  (single-slot: *Your Captain comes any time in this time slot.*)
- Every time slot shows a **checkbox** in front of the time: empty box when not chosen,
  blue box with a white tick when chosen, faint box when the slot is full.
- Summary line under the grid says "time slots" instead of "windows".
- "Any time of the day" is unchanged.

### Files changed

- `apps/flutter/customer/lib/screens/booking.dart` — C12 heading/subtitle; slot chips use `checkbox`.
- `apps/flutter/packages/washkrew_ui/lib/src/components.dart` (SH-DESIGN) — `WChip` gets an
  optional `checkbox` flag (default off, so every other chip looks the same as before).

### Backend needed (Ajay)

None.

### How to test on the iPhone

Book a wash (or Book again) → time step: heading reads "When is your vehicle free?", each slot
has a checkbox, tapping ticks/unticks it, several can be ticked, full slots look disabled.

### Status

Built; analyze clean; Customer 85/85, shared UI 9/9 tests pass. iPhone test: pending.

## 12 Nov 2026 — Time windows with a slider and clearer hierarchy (C12)

- **Why (Aman):** picking From/Until needed a livelier control, and the screen needed a
  clearer order of information.
- **What changed for the customer:**
  - Two labelled sections: **Day** (Today / Tomorrow / next day, the date, *Other date*) and **Time**.
  - Each window is one card: big blue **From** and **Until** times, a duration pill
    ("2 hours"), and a **range slider** to drag both ends in 15-minute steps. The times roll
    over as you drag, with a light tap of haptics. The two ends stay at least 1 hour apart.
    Tapping a time still opens the clock to type an exact minute.
  - Today the slider starts at the next quarter hour, so a past time can't be picked, and
    the suggested window is the next free 2 hours (other days: 8–10 AM) — no more
    "already ended" on arrival.
  - *Add another window* suggests the next free 2 hours; the delete button shows only when
    there is more than one window.
  - Problems show in a red banner with an icon (not colour alone); the rule line moved
    under the title.
- **Files:** `packages/washkrew_purchase_ui/lib/src/time_windows.dart` (also used by the
  monthly plan time step), tests updated.
- **Backend needed (Ajay):** none beyond exact-minute windows (V2-FEATURES.md).
- **Status:** built; package 28/28, Customer 119/119.

