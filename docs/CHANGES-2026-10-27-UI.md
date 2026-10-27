# UI changes from Aman's session — 27 October 2026 (for Ajay)

**Read this first, Ajay.** Today Aman is changing the **UI only** on top of staging `752e222`.
**The backend was not changed** (no Firebase functions, rules or config). Every item below says
what still needs connecting on the backend side. Treat the "Backend needed" items as **P0**.

Until you connect an item, its real-data (Firebase) build shows the toast or dialog message
"This isn’t available yet. Call us and we’ll do it for you." It never fakes success.
The sample (demo) build shows the full designed flow.

New items are added to this list as the session goes on.

---

## 1. Delete account in the Profile (Captain app is new; Customer app already had it)

**What Aman asked:** a "Delete account" option in the profile of both apps.

**Captain app (new UI)**
- Me tab → last row under **Log out**: **Delete account** (red trash icon). Shown only to
  registered captains, in English, Hindi and Telugu.
- Tapping it opens the designed C53 dialog (same look as the Customer app): trash icon,
  "Delete your account?", "Your profile, KYC documents and job history go with it. You can’t do
  this while you have a job in progress.", red **Delete account** and text **Keep my account**.
  Buttons use the captain size (64 px).
- Sample app: deletes the local account, logs out and goes to the start.
- Real data: shows "This isn’t available yet. Call us and we’ll do it for you." in red inside
  the dialog. Nothing is deleted.
- Code: `CaptainStore.deleteAccount()` in `captain/lib/data/store.dart` (marked BACKEND), the row in
  `captain/lib/screens/money.dart` (Me tab), and the shared dialog
  `packages/washkrew_ui/lib/src/delete_account.dart` (`showDeleteAccountDialog`).

**Customer app (no change)**
- Profile → **Delete account** under **Log out** was already there (C53) and is already wired by
  you to `deleteOwnAccount`. Left as it is.

**Backend needed (P0)**
1. **Connect Captain deletion.** In `CaptainStore.deleteAccount()`, replace the `isLive` early
   return with your real call: take the captain offline (`setCaptainOnline false`), call
   `deleteOwnAccount {confirm: true}`, check `deleted == true`, sign out, then `_logOut()`.
   Return `null` on success, or the error text (via `backendError`) to show in the dialog.
2. **Login older than 5 minutes.** `deleteAccount` in `service.mjs` refuses unless the login was
   in the last 5 minutes ("sign out and log in again…"). Most people will hit this, in **both
   apps**. Please add a fresh SMS check before deleting (you already have
   `requestAccountVerification` / `confirmAccountVerification` for payout UPI). If it needs a
   code-entry step, tell Aman so it can be designed. Don't ask people to log out and back in.
3. **One number, both roles.** `deleteOwnAccount` removes the whole Firebase user. Someone who is
   both a customer and a captain on the same number loses **both** accounts. Decide with Aman
   whether that is right; if yes, the dialog text in both apps needs a line saying so.
4. **Open jobs.** The server blocks deletion while a booking or job is open. The dialog shows
   your error text. Please make it short and friendly for captains (it is also shown in
   Hindi/Telugu users' dialogs, so send a translatable code if possible).

---

## 2. Captain KYC: "Upload Aadhaar photo" asks camera or gallery, then checks the photo

**What Aman asked:** rename the link (no "instead"). Tapping it must not jump to the error screen.
It asks camera or gallery, shows the chosen photo while it is being checked, then shows either
"approved" or the "not clear" screen.

**What changed (Captain, W05 `AadhaarScreen` in `captain/lib/screens/onboarding.dart`)**
- Link text: **Upload Aadhaar photo** (Hindi/Telugu unchanged; they never said "instead").
- Before, the link opened the W05b "Photo is not clear" screen straight away, with no photo.
  Now it opens a choice sheet: **Take photo** (camera opens) / **Choose from gallery** (photo
  library opens) / Cancel.
- After a photo is picked: **Checking your photo** with the actual photo dimmed, a spinner and
  "Checking…" (shown for at least about 2 seconds so it is visible), then:
  - **Photo is clear**: the photo with a green "Clear" badge, "Your Aadhaar photo is added. Our
    team checks the details before you take jobs.", **Continue** (→ steps list) and **Use a
    different photo**.
  - **Photo is not clear** (W05b): the actual photo with a red reason badge (Too dark, Too far,
    Covered, Can’t read) and the three tips. **Take again** opens the same camera/gallery choice.
- What decides clear or not: the existing on-phone check `checkPhotoQuality` (light, size,
  covered/unreadable). Real data: a clear photo is uploaded with your existing
  `liveUploadKyc('aadhaar', …)`, as before. No backend change.
- "Open DigiLocker" is unchanged (real data: opens the camera, as before).

**Backend needed (P0)**
1. **Real Aadhaar check.** Today "clear" only means the photo is readable. Nothing reads the card
   or checks that it is an Aadhaar card. Add the server-side check (OCR/document check, or
   DigiLocker) and send the result back, so the app can show a real "Aadhaar verified" or a
   specific reason ("This isn’t an Aadhaar card", "Name doesn’t match").
2. **Front and back.** The W04 step list says "Photo of the front and back", but one photo is
   taken (as before). Decide whether the back is needed; if yes, tell Aman so the screen can ask
   for it.
3. **Gallery photos.** Photos from the gallery can be old or edited. Decide whether gallery uploads
   are allowed for KYC, or need extra checks.

---

## 3. "Skip this step (testing)" text link on every onboarding stage (TESTING ONLY)

**What Aman asked:** a small text-only button to skip onboarding, stage after stage, for testing
and internal use.

**What changed (Captain, `captain/lib/screens/onboarding.dart`)**
- The old orange pill "TEST ONLY · Skip onboarding" (sample app only, jumped straight to "You’re
  in") is replaced by a small grey text link, **Skip this step (testing)**, on: the 4-steps list,
  Aadhaar, Your photo (selfie), Get paid, Training, the video player and the quiz.
- Each tap marks **that one stage** done and returns to the steps list. On the steps list it
  skips the next stage to do. Once all stages are done, Continue goes to the rules, as normal.
- It shows in **both** the sample app and the real-data app, so Aman can test on his phone.
- Real data: skipped stages are kept **on this phone only** (`CaptainStore.testSkipped`) and
  re-applied over server data; cleared on log out. **The server is not told.** "I agree" on the
  rules still submits the application, and your server checks still apply (missing documents,
  training or quiz are refused). Nothing is approved by skipping.
- Switch: `const onboardingSkip = true;` at the top of `onboarding.dart`. **Set it to false
  before launch.** (Same for `planClockTest`.)

**Backend needed:** nothing to build. Please confirm the server rejects an application with
skipped stages, with a clear message, and remind us to turn the switch off before release.

---

## 4. Captain "I agree" (Rules) failed with "INTERNAL"

**What Aman saw:** after skipping stages with the testing link, tapping **I agree** on Rules
showed "INTERNAL" and did not move on.

**Cause:** "I agree" calls `submitCaptainApplication`. The skipped stages had no Aadhaar/selfie
photo in Storage. In `service.mjs`, `this.evidence.metadata('kyc/{uid}/aadhaar.jpg')` uses
Storage `getMetadata()`, which **throws a 404 when the file is missing** instead of returning
null. That is not a `ServiceError`, so the callable returns a generic internal error. The intended
message ("Upload your identity and selfie.") never reaches the app.

**What changed in the app (Captain, `RulesScreen` in `onboarding.dart`; backend unchanged)**
- Testing: if any stage was skipped with "Skip this step (testing)", **I agree** does not send
  the application. It shows "Testing: you skipped steps, so the application was not sent." and
  goes to "Get ready" (W13), so the rest of the flow can be tested.
- Real use: if the Aadhaar or selfie photo is not uploaded, the app says "Upload your Aadhaar and
  selfie first." and goes back to the steps list, instead of calling the server.
- "Get ready" (W13) also has the **Skip this step (testing)** link, which goes to "You’re in" (W14).
  Real data: this is on the phone only. The captain is not approved and still cannot go online.

**Backend needed (P0)**
1. **Fix the missing-file crash** in `submitCaptainApplication`: catch the 404 from
   `getMetadata()` (or check `file.exists()` first) and `fail('failed-precondition', 'Upload your
   identity and selfie.')`. Other places that call `evidence.metadata` probably have the same issue.
2. Please make sure every refusal reaches the app as a clear message, never "INTERNAL".
