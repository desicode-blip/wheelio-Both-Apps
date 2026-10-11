# WhatsApp message templates (entry-pass bot)

Meta must approve each template before it can be sent. Category: **Utility**. Language: English (en) first; Hindi and Telugu versions for washers come in phase 3.

## 1. `booking_confirmed_pass_request` — sent right after payment (C19, C19b)

> Booking confirmed
> {{1}} · {{2}}
> {{3}}
> {{4}}
> {{5}} held safely
>
> Please reply with your society entry pass (MyGate, NoBrokerHood or a photo of the gate pass). The washer needs it to get in.

Variables: 1 plate (TS 09 EA 4521), 2 vehicle (Hatchback), 3 time (Today, 8 – 10 AM), 4 place (My Home Avatar, Tower 3, B2 slot 41), 5 amount (₹149).
Quick-reply button: **Send gate pass**.

## 2. `pass_received` — after the customer replies (session message, no template needed within 24 h)

> Got it. Pass saved for this booking. We’ll share it with your washer only.

## 3. `pass_reminder` — washer accepted and no pass yet (C22b)

> Your washer {{1}} is on the way and arrives by {{2}}. We still need your gate pass, or {{1}} may be stopped at the gate. Reply here with your MyGate or society pass.

## 4. `washer_accepted`

> {{1}} accepted your wash for {{2}}. Arrives by {{3}}. Track it in the app.

## 5. `photos_ready`

> Your wash is done. Check the before and after photos in the app and approve to release {{1}} to {{2}}. It approves automatically at {{3}}.

## 6. `no_washer_refund` (C21)

> Sorry, no washer was free for {{1}}. Your {{2}} is on its way back: 2 to 3 working days to your UPI.

Rules: the entry pass is stored per order (`entry_passes`), shared only with the assigned washer, and asked for on every order, repeats included (roadmap F10).
