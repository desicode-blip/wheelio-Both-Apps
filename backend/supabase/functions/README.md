# Edge functions

| Function | Status | What it does | Needs |
|---|---|---|---|
| `ai-photo-check` | Written | Compares before/after photos (W36 missed-spot check) and drafts dispute recommendations (C33–C35) with Claude vision. The final dispute decision stays with a person. | `ANTHROPIC_API_KEY` |
| `razorpay-webhook` | Written | Verifies the signature, marks payments captured/failed, starts washer search, records refunds and payouts. | Razorpay account with Route, `RAZORPAY_WEBHOOK_SECRET` |
| `create-payment` | To write | Creates the Razorpay order for an order (amount from the database, never from the app) and returns `order_id` for the checkout SDK. | Razorpay keys |
| `dispatch-jobs` | To write | Finds nearby washers in the society (PostGIS), respects probation daily limits and job chaining (20 min per wash plus travel), sends 15-second offers (W22), marks `no_washer` and refunds when nobody accepts. | FCM for washer push |
| `whatsapp-webhook` | To write | Sends the booking message (C19b templates in `backend/whatsapp-templates.md`), receives the entry pass reply and stores it in `entry_passes`. | WhatsApp Business number, approved templates |
| `masked-call` | To write | Connects customer and washer through a virtual number that works from acceptance until about 2 hours after completion. | Exotel or similar |
| `nightly-payouts` | To write | Before midnight: releases approved payouts (minus late penalty, capped by `late_penalty_cap_pct`) as Razorpay Route transfers. Holds payouts with open disputes. | Razorpay Route |
| `no-show-refunds` | To write | Refunds in full when no wash started by the end of the window plus grace. | — |

Shared rules: the app never sends prices or payout amounts; every amount is read from the database. All webhooks verify signatures. Service-role keys live only in function secrets.
