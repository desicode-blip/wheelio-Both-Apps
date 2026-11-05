# CU-LIVE — Finding a Captain, on the way, washing (and gate pass)

Feature map: [FEATURES.md](FEATURES.md). Screens: C19, C20–C24, C30. Captain side: W26, W27.

## 5 Nov 2026 — Upload the gate pass in the app

- **Why (Aman):** the WhatsApp gate-pass step was never connected. The customer should
  upload the pass in the app, and the Captain should see it.
- **Branch:** `v2/cu-bookings-rebook`.
- **Screens:** C19 "You're booked" and C22 "On the way" (customer); W26 "Go to vehicle"
  gate-pass row and W27 "Show this at the gate" (Captain).

### What changes

Customer (new shared `GatePassCard`, replaces the WhatsApp card on C19 and the
"We still need your gate pass · Send now" banner on C22):

- No pass yet: door icon, **Gate pass**, "Needed if your society checks visitors.",
  "Upload your MyGate or society entry pass…", button **Upload gate pass**.
- Upload asks **Take photo / Choose from gallery / Cancel** (camera and gallery are
  separate, as in Captain Aadhaar upload).
- After upload: the pass is shown as a preview with **Change**. Caption:
  "{Captain} can see it and show it at the gate." once the server confirms;
  until then "Saved on this phone. Sharing with your Captain is being connected."

Captain: W27 shows the customer's pass image (full width) when the booking has
`entryPass.path`; otherwise the existing placeholder. W26 badge (Pending/Ready) unchanged.

### Files changed

- `apps/flutter/customer/lib/screens/gate_pass.dart` (new) — `GatePassCard`, `pickGatePass`.
- `apps/flutter/customer/lib/screens/auth_pay.dart` — C19 uses `GatePassCard`.
- `apps/flutter/customer/lib/screens/live.dart` — C22 uses `GatePassCard`.
- `apps/flutter/customer/lib/data/models.dart` — `Order.gatePassPath`, `Order.gatePassBytes`.
- `apps/flutter/customer/lib/data/store.dart` — reads `entryPass.path`; `uploadGatePass()` hook.
- `apps/flutter/captain/lib/screens/home.dart` — W27 shows the uploaded pass.
- `apps/flutter/customer/test/live_completion_test.dart` — 2 tests updated (WhatsApp card removed).

### Backend needed (Ajay)

1. A Customer-only callable (or Storage upload + callable), e.g. `uploadGatePass(bookingId, image)`:
   verify ownership and an active, paid booking; store at `orders/{id}/gatePass.jpg`;
   set `entryPass = {status:'received', path, uploadedAt}`; replacing an earlier pass is allowed.
2. Storage/Firestore rules: the customer and the **assigned Captain only** can read it.
3. Notify the Captain (existing `gatePassReady` notification kind).
4. Delete with the other wash photos (90-day retention) and on account deletion.
5. Connect `AppStore.uploadGatePass` (customer) to it. Until then the picked image stays on
   the phone and the Captain does not see it.

### How to test on the iPhone

Book (or open a booked wash) → "Gate pass" card → Upload gate pass → Take photo or
Choose from gallery → preview appears with Change. (Captain display needs the backend.)

### Status

Built; analyze clean; Customer 85/85, Captain 40/40 tests pass. iPhone test pending.
