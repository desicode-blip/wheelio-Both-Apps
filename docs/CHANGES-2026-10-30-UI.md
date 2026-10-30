# App changes from Aman's session — 30 October 2026 (for Ajay)

UI changes on the current Flutter apps (staging, design pinned to af036f0). No backend
change. Items are added as the session goes on.

## 1. Customer "Is your vehicle here?" (C09): big "Locate me" button on the map

**What Aman asked:** a "Locate me" button on the map, bigger than the standard small
icon, with an icon and text, placed sensibly.

**What changed**
- Shared `MapLocateButton` (`packages/washkrew_ui/lib/src/map_controls.dart`): white pill,
  48 px high, locate icon + "Locate me", shadow; shows a spinner while locating.
- Placed **bottom-right of the map** (12 px inset), clear of the Google logo (bottom-left)
  and the centre pin. Replaces the small round "My location" icon on the sample map.
- Real map (`LivePlaceMap`, new optional `onLocate`): tap → phone GPS (existing
  `currentPosition`, which asks for permission) → existing `matchServiceLocation` via
  `AppStore.locatePlace` → the map animates to the position (zoom 17) and the pin's
  coordinates update as when dragging. If the position is in a different served society,
  the address card switches to it. Outside served societies the pin does not move and a
  message says so (no guessed coverage). Permission denied shows the existing error text.
- Address card title now uses `Place.title`, so an empty tower no longer shows a trailing
  comma ("My Home Avatar,").

**Backend needed:** none. It uses the existing location matching. Coverage for other
societies still depends on their configured coordinates/boundaries.

---

## 2. Speed: screens no longer wait for saves the next step doesn't need (Customer)

**What Aman saw:** on "Where is it parked?" (C10), **Next** took a long time before
the next screen appeared. He asked for every such delay to be found and removed,
Customer first, then Captain.

**Cause:** the button waited for a Cloud Function (`saveCustomerPlace`) to answer before
moving on. Every first call after a quiet period also pays a Functions cold start.

**Audit of Customer server waits (`customer/lib/screens`)**

| Screen / action | Before | Now |
|---|---|---|
| C10 Parking → Next | waited for `saveCustomerPlace` | moves on at once; saves in the background (`saveDraftPlaceInBackground`), failure → toast. The booking itself still sends the place. |
| C12 "When should we come?" | fetched `getAvailability` only when the screen opened | fetched ahead from C10 for the next 3 days (`prefetchAvailability`) and reused for 45 s (`availabilityFor`); failures are not cached; pull/refresh still asks fresh |
| Rate the wash → Submit | waited for `rateWash` | closes at once; rating sends in the background, failure → toast |
| Profile photo | waited for the upload before showing | shows at once; uploads in the background; on failure goes back to the old photo with a toast |
| OTP, name, address check, pay, payment check, approve, cancel, report a problem, phone change, delete account | wait | **unchanged on purpose**: they need the server's real answer (money, identity, account) and already show a loading state |

Screen transitions are the standard iOS slide (`CupertinoPage`); not changed.

**Backend suggestion (Ajay, P1):** cold starts make the first call after idle slow. Consider
`minInstances: 1` for the busiest callables (`getAvailability`, `createBooking`,
`createCheckout`, `verifyPayment`, Captain `setCaptainOnline` / `claimJob`) in asia-south1,
weighing the always-on cost.

## 3. Speed: Captain

**Audit of Captain server waits (`captain/lib/screens`)**

| Screen / action | Before | Now |
|---|---|---|
| Where I work → Save (Home "Jobs from · Change", Me) | waited for `setCaptainPreferences` (and GPS for Distance) | closes at once with "Saved: …"; saves in the background; on failure the previous values come back with a toast |
| Profile photo | waited for the upload | shows at once; failure restores the old photo |
| First-time work profile → Done | waits | **unchanged**: approval/availability need the saved preferences, and failure must keep the captain on the screen |
| Online switch | already moves at once (server confirms, reverts on failure) | unchanged |
| OTP, KYC uploads, payout, application, accept job, arrival, selfie check, note heard, photos, check photos, start, finish, vehicle help, phone/UPI change | wait | **unchanged on purpose**: the server decides; they already show loading states |

---

## 4. Customer guided photos (C08): live camera inside the box, photo taken in place

**What Aman asked:** on "Front · 1 of 4", the camera should open by itself inside the dark
box, keeping the dotted outline as a guide; the instruction goes under the box with only
the side word in bold (front, back, left side, right side); the round button takes the
photo right there (no separate camera screen); a see-through dark layer keeps the dotted
lines visible on bright scenes; and the outline matches a two-wheeler or a four-wheeler.

**What changed**
- New dependency `camera` 0.12.0+2 (in `washkrew_ui`; both apps' `pubspec.lock` updated).
  `WCameraController` / `WCameraPreview` (`packages/washkrew_ui/lib/src/live_camera.dart`):
  back camera, high preset, JPEG; released when the app goes to the background and
  restarted when it returns; reports denied vs no camera.
- `CameraScreen` (`customer/lib/screens/booking.dart`): preview fills the existing rounded
  box (cropped to fit); black layer at 10% (`_guideScrim`, one number to tune) over it; the
  dashed outline on top with a soft dark edge under the white dashes. Shutter: takes the
  photo, short white flash + haptic, keeps it (`AppStore.keepPhoto`), moves to the next
  missing side, closes after the fourth. The flash icon now toggles the flash.
- Instruction under the box: "Fit the **front** of the vehicle in the outline" (bold side).
- `VehicleOutlinePainter`: car front/back (windscreen, lights, tyres) and side (cabin
  shifts for left/right); two-wheeler front/back (handlebar, light, one tyre) and side (two
  wheels, body, handlebar). Chosen from the booking's vehicle type.
- Camera denied: the existing "Camera access needed" screen, with Settings. No usable
  camera (laptop/simulator): falls back to the previous picker/sample path.

**Backend needed:** none. Photos still upload with the booking as before.
