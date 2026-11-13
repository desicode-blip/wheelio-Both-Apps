# Coming soon — no dead ends (rule from Aman, 13 Nov 2026)

**Never let a customer or Captain start a journey that will dead-end.**
- If the live server can't do something yet, stop them at the **entry point**: grey it out and
  say "**<Feature> is coming soon. We're working on it.**" (a toast at the top).
- Don't block them later, at payment.
- Sample (non-live) builds keep everything open for review.

**Shared pieces (`washkrew_ui/lib/src/toast.dart`):**
- `showComingSoon(context, feature)`: shows the message.
- `ComingSoonTag`: the grey "Coming soon" pill.
- `ComingSoonGate(available, feature, child)`: wraps an entry point. When unavailable it greys the
  child out, makes it unusable, and shows the message on tap.

## Where it applies today (live builds)

| Entry point | Switch that opens it (`config/operations`) | Until then |
|---|---|---|
| Premium / Extra Premium | `washTiers: true` | greyed, "Coming soon"; tap → toast; Basic stays selected |
| Interior cleaning | `washTiers: true` | chip "Interior · coming soon"; tap → toast |
| Monthly plan | `monthlyPlans: true` | segment "Monthly · soon"; tap → toast |
| Referrals (Profile, Coupons "Want more?", Captain Me, Captain money card, sign-up code) | `referrals: true` | rows greyed with "Coming soon"; sample earnings card and sign-up code field hidden |
| Gate pass upload | `gatePass: true` | "Upload gate pass · coming soon"; tap → toast |
| Exact time windows | `customTimeWindows: true` | the picker covers only the server's slot hours, and any window books the slots inside it, so time never blocks |

When Ajay's server part for a row is live, set its switch to `true` and the entry point opens.
No app update is needed.

**For new features:** wrap the entry point in `ComingSoonGate(available: <switch>, feature: '…')`
from day one.
