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
