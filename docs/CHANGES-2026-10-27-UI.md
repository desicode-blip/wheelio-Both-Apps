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

---

## 5. Captain: the review-call screen (W13 "Get ready") is removed. After "I agree" → "You’re in" → Home

**What Aman decided:** there is **no separate verification or video-call round**. Once the
documents are done and the captain agrees to the rules, he goes straight to the celebration
screen with the day 1 / day 2 / day 3 job counts (W14 "You’re in"), then Home.
- **Verified:** he goes **online automatically**.
- **Not verified yet:** a pop-up says **"Your profile is under review"**. The review is meant
  to be **automatic, within 30 minutes**. The pop-up counts down from 30:00 from when the
  application was sent. When it reaches zero, a **Call our team** button appears.

**What changed (Captain app)**
- Removed: `UnderReviewScreen` (W13 "Get ready / Your review call is pending / Change time"), its
  route `N.underReview` and its gallery entry. The app no longer shows the intro-call time
  (`introCallLabel`) or sends the "Change time" support request.
- Rules **I agree** (real data): sends the application (`submitCaptainApplication`, as before),
  then opens W14 "You’re in". The testing path (skipped stages) also goes to W14, without sending.
- W14 **Go to home**:
  - approved (`captains.approved == true`): calls your existing `setCaptainOnline {online: true}`
    and opens Home online;
  - not approved: opens Home and shows the pop-up.
- If approval arrives later in the same session, the app goes online by itself (same call) and
  closes the pop-up.
- Pop-up: `showReviewNotice` in `captain/lib/screens/onboarding.dart`. The countdown uses
  `captains.submittedAt` (falls back to the time "I agree" was tapped). **Call our team** uses
  `Support.call()` (the published support number). Tapping **Go online** while under review shows
  the same pop-up. The steps list's Continue (when already sent) opens Home with the pop-up.
- Sample app: approves straight away and goes online. To see the pop-up: Screens → W14r
  "Home: profile under review (pop-up)".
- Store: `CaptainStore` "Review after I agree" section (`reviewWait` = 30 min, `underReview`,
  `callUnlocksIn`, `startReview`, `goOnlineAfterApproval`).

**Backend needed (P0)**
1. **Automatic review within 30 minutes.** Today approval is a human operator action
   (`review-identity` / manual). Build the automatic check: Aadhaar photo readable and an Aadhaar,
   selfie matches the Aadhaar photo, training/quiz done, payout UPI valid. Approve (`approved:
   true`, `kycStatus: 'approved'`) within 30 minutes of `submittedAt`. Send to a human only when
   unsure, and say so in the app (tell Aman so it can be designed).
2. **Drop the intro-call step.** `schedule-intro`, `introCallLabel` and the intro-call wording in
   operator tools and docs are no longer part of the flow. Approval must not wait for a call.
3. **Support number.** The **Call our team** button needs `config.support.phone` published
   (E.164, e.g. +91…); until then it shows "The support number is awaiting publication."
4. **Rejections.** If the automatic review rejects something, set `kycStatus: 'changesRequested'`
   with a reason the app can show (the steps list already marks Aadhaar as "1 thing to fix").
   Send Aman the reasons so the messages can be written.
5. **Go online on approval.** The app calls `setCaptainOnline true` itself right after approval.
   Make sure an approved captain with no work-time/area preference set can go online, or send a
   clear error message.

---

## 6. "Skip 30 min (testing)" on the under-review pop-up (TESTING ONLY)

**What Aman asked:** a testing-only skip for the 30-minute timer that goes straight to live (online).

**What changed (Captain)**
- The "Your profile is under review" pop-up has a small grey **Skip 30 min (testing)** link under OK.
- Tapping it treats the profile as approved **on this phone only** (`CaptainStore.testSkipReview`,
  `testApproved`). It closes the pop-up and puts the captain on Home, **Online**.
- Real data: the server is **not** told. `setCaptainOnline` and the 60-second online heartbeat are
  not sent while only test-approved (`testOnlyOnline`), because the server would refuse an
  unapproved captain. The server still sees him unapproved and offline, so **no real job offers
  arrive**. Cleared on log out.
- Sample app: approves and goes online (sample jobs ring as usual).
- Hidden when `onboardingSkip` is false. **Turn it off before launch.**

**Backend needed:** nothing to build. For real end-to-end job tests, approve the test captain on the
server (or build the automatic review in item 5).

---

## 7. Captain first-time "work profile": two questions while the documents are reviewed

**What Aman asked:** after the documents are submitted and the review countdown has started, keep
the captain engaged by having him build his profile: **one question per screen**, (1) which jobs
he wants, then (2) when he works. After the last answer, the questionnaire **closes by shrinking
into the "Jobs from: … · Change" chip at the top of Home**, so he learns that is where to change it
later. **First-time onboarding only**; afterwards it is edited from that chip (or Me → Where I work).

**Flow now:** Rules **I agree** (application sent, countdown starts) → **Your work profile**,
question 1 "Which jobs should ring?" → **Next** → question 2 "When do you work?" → **Done** →
"You’re in" (day 1 / 2 / 3) → **Go to home** → the profile card shrinks into the "Jobs from" chip,
the chip glows → then (if not approved) the "under review" pop-up, or (if approved) online.

**What changed (Captain)**
- `WorkAreaScreen(setup: true)` (`captain/lib/screens/help.dart`), new route `N.workSetup`. Same
  choices and saving as Where I work, split into two pages with a 2-step progress bar, no back to
  Rules, and a green note "Documents sent. While we check them, set up how you work." Question 2
  uses big time tiles (6–10 AM, 10 AM–2 PM, 2–6 PM; none = any time).
- **Done** saves with your existing `setCaptainPreferences` (`liveSaveWorkPreferences`). If saving
  fails it shows the error and **still continues**; it can be changed later from the chip.
- Home (`captain/lib/screens/home.dart`): `_ProfileShrink` overlay animation (≈1.7 s) from a
  summary card ("Your work profile · Jobs from … · When …") into the chip, then a 1.5 s glow on
  the chip. Job alerts wait until it finishes. Shown once (`CaptainStore.workSetupLanding`).
- Sample gallery: W12w "Work profile (first time)".

**Backend needed (P0)**
1. **Save preferences before approval.** `setCaptainPreferences` must accept a captain whose
   application is under review (not approved yet). Please confirm, or the first-time answers are
   only kept on the phone.
2. Approval should use these saved preferences (areas/times) when the captain goes online.

---

## 8. Work profile: left-to-right slide, time sliders with "Add more time", no "You’re in" screen

**What Aman asked**
- Moving from question 1 to question 2 should slide **left to right**, the same way the progress
  bar fills (going back slides the other way). Before, it was a small fade.
- "When do you work?": instead of three fixed options, choose a **start and end time with a
  slider**, plus **Add more time** for breaks (e.g. 9–10 AM and 1–7 PM). Same in the normal
  "Where I work" screen (Home → Jobs from → Change, or Me → Where I work), not just onboarding.
- Remove the **"You’re in"** screen (Day 1 / Day 2 / Day 3 jobs) completely. Tapping **Done** on
  the time question closes the questionnaire straight away by shrinking it into Home’s "Jobs from"
  chip.

**What changed (Captain)**
- `WorkSlotsEditor` (`captain/lib/screens/help.dart`): one card per time range. Each card has a
  big "9 AM – 6 PM" label, a duration, a range slider from 6 AM to 9 PM in 30-minute steps
  (at least 1 hour) and a remove ✕ when there is more than one. **Add more time** adds a range
  1 hour after the last one (up to 4). Overlapping ranges are merged on save, and the card says so.
- Store: `workSlots` (minutes, `WorkSlot`) replaces the old `WorkTime` morning/midday/afternoon
  set. `workSlotsLabel` gives "9 AM–6 PM, 7 PM–9 PM". Matching a job uses overlap with any slot.
- **Saving to your backend (unchanged):** `setCaptainPreferences` still only accepts the windows
  6–10, 10–14 and 14–18. As Aman asked, the app sends **every window that any slot touches**
  (`serverWindowsFor`), to give the captain the most job offers. Example: 9–10 AM and 1–7 PM →
  all three windows. The exact slots are kept on the phone and stay as long as the server windows
  match them.
- Removed: `LiveScreen` (W14 "You’re in"), route `N.live` and its gallery entry. **Done** now:
  sample app approves; approved → goes online automatically; not approved → after the animation,
  the "under review" pop-up. `playWorkProfileLanding` (home.dart) shows a full-screen summary
  ("Your work profile · Jobs from … · When …") for a moment, shrinks it into the chip (about
  1.5 s), then the chip glows. Job alerts and the pop-up wait until then.

**Backend needed (P0)**
1. **Store exact working times.** Accept and save any start/end ranges (e.g. 30-minute steps,
   several per day, `workingSlots: [{start: "09:00", end: "10:00"}, …]`). Offer jobs whose booking
   window overlaps a slot (or fits inside it; decide with Aman, who prefers more offers). Then the
   app can send the exact slots instead of whole windows.
2. Until then, the whole-window "lump sum" above is what the server sees.
