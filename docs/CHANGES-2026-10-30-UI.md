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
