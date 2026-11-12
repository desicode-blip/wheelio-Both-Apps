# CA-JOURNEY — Captain wash milestones (My level)

**12 Nov 2026, Aman.** My level no longer stops at the first 3 days.

- **Top card:** lifetime washes in big type with the level name, an animated bar to the
  next milestone, "27 more to 100 washes", and that milestone's reward.
- **First 3 days card:** shown only while the Captain is new (live: `workStatus` is not
  `active`; sample: `levelDay` ≤ 3). After that it disappears.
- **Your journey:** a vertical path. Reached = green tick, next = blue flag with a "Next" tag,
  later = grey lock.

| Washes | Level name (draft) | Reward |
|---|---|---|
| 50 | Rising Captain | Badge only |
| 100 | Trusted Captain | Surprise WashKrew merchandise |
| 500 | Pro Captain | Not decided ("Reward coming soon") |
| 1000 | Star Captain | Not decided |
| 2000 | Legend Captain | Not decided |

- Level names are drafts for Aman to confirm. Rewards for 500+ stay placeholders.
- **Config:** the server can replace the list with `config.captainMilestones` =
  `[{washes, title, reward?}]` (no `reward` = badge only, `""` = coming soon).
- **Data:** uses the existing `captains/{uid}.completedWashes` counter. No new backend.
- **Me tab row:** "Day 2 of 3" while new, then "73 washes · next 100".
- **Also fixed:** the rating stars now fill to match the rating (a 2.0 showed 5 full stars).
- **Not built yet (Ajay):** issuing/tracking the 100-wash merchandise (who sends it, address).
- **Files:** `captain/lib/features/wash_journey.dart` (new), `captain/lib/screens/money.dart`,
  test `captain/test/wash_journey_test.dart`.
