# CU-APPROVE — Check photos, approve, rate (and the AI photo check)

Feature map: [FEATURES.md](FEATURES.md). Screens: C25–C28; AI setting card on C19–C23.

## 5 Nov 2026 — Info (i) on the AI wash photo check

- **Why (Aman):** explain the AI check in plain words.
- **Decision (Aman, 5 Nov):** the switch stays **OFF by default** (explicit opt-in under the
  DPDP Act, as decided on 3 Nov). Only an (i) explanation is added.
- **Branch:** `v2/cu-bookings-rebook`.

### What changes

- Title row: **AI wash photo check (i)**. Tapping (i) opens:

  > When your wash is done, we use Google AI (Vertex AI, Gemini) to compare the before and
  > after photos of your vehicle. If it spots dirt or a part that wasn't cleaned properly, we
  > get it fixed before the photos come to you for review.
  >
  > Your photos are safe with us. Number plates and anything in the background are used only
  > for this check and nowhere else. We delete wash photos after 90 days.
  >
  > This check is optional. When it's off, the photos come straight to you for review.

- Card text shortened: "Turn on to let Google AI (Vertex AI, Gemini) check your wash photos for
  missed spots before they reach you. Plates and surroundings may be visible. Aadhaar, selfies
  and bank details are never sent."

### Files changed

- `apps/flutter/customer/lib/screens/booking_ai_setting.dart` — (i) and `showAiPhotoCheckInfo`.

### Backend needed (Ajay)

- The text says the AI **compares before and after** photos. Today the check
  (`wash-photo-review.mjs`) sends only the 4 **after** photos. Either add the 4 before
  photos to the check, or tell Aman so the wording can say "checks the after-wash photos".
- Confirm the privacy policy covers the Vertex AI/Gemini processing as worded.

### Status

Built; analyze clean; tests pass. iPhone test pending.
