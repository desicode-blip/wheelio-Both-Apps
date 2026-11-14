# Coming soon — no dead ends (rule from Aman, 13 Nov 2026)

**Never let a customer or Captain start a journey that will dead-end.**
- If the live server can't do something yet, stop them at the **entry point**: grey it out
  (unselected, not highlighted). **No "Coming soon" text in the app.** Only a tap shows the
  toast "**<Feature> is coming soon. We're working on it.**" at the top.
- Don't block them later, at payment.
- Sample (non-live) builds keep everything open for review.

**Shared pieces (`washkrew_ui/lib/src/toast.dart`):**
- `showComingSoon(context, feature)`: shows the message.
- `ComingSoonTag`: a grey "Coming soon" pill. Not used in the apps (Aman, 13 Nov).
- `ComingSoonGate(available, feature, child)`: wraps an entry point. When unavailable it greys the
  child out and shows the toast on tap. `showTag` defaults to false.

## Where it applies today (live builds)

| Entry point | Switch that opens it (`config/operations`) | Until then |
|---|---|---|
| Premium / Extra Premium | `washTiers: true` (+ `washPrices`) | greyed, no price; tap → toast; Basic stays selected. **Server done in this push; Ajay to deploy and switch on.** |
| Interior cleaning | `washTiers: true` **and `interior: true`** (+ `washPrices`) | "Exterior + interior" chip greyed; tap → toast. **Server done; deploy and switch on.** |
| Monthly plan | `monthlyPlans: true` | "Monthly plan" segment greyed; tap → toast. **Server done (one payment per month); deploy and switch on.** |
| Referrals (Profile, Coupons "Want more?", Captain Me, Captain money card, sign-up code) | `referrals: true` | rows greyed; tap → toast; sample earnings card and sign-up code field hidden |
| Gate pass upload | `gatePass: true` | "Upload gate pass" greyed; tap → toast |
| Exact time windows | `customTimeWindows: true` | the picker covers only the server's slot hours, and any window books the slots inside it, so time never blocks |

When Ajay's server part for a row is live, set its switch to `true` and the entry point opens.
No app update is needed.

**For new features:** wrap the entry point in `ComingSoonGate(available: <switch>, feature: '…')`
from day one.
