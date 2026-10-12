# Customer app ↔ backend contract

> Historical Supabase contract. The active database schema is now ported to Neon/Better Auth; see [NEON-DATABASE.md](NEON-DATABASE.md). The SwiftUI apps still use demo stores, and the calls below are not active Neon API routes.

The app talks to the server only through the `Backend` interface in
`apps/customer/lib/data/backend.dart`. Today `MockBackend` implements it with
sample data. `SupabaseBackend` will implement the same methods with the calls below,
so no screen changes when the backend is connected.

| `Backend` method | Supabase call | Notes |
|---|---|---|
| `requestOtp(phone)` | `auth.signInWithOtp(phone: '+91…')` | SMS provider set in Supabase Auth (MSG91 / Twilio Verify). DLT template needed. |
| `verifyOtp(phone, code)` | `auth.verifyOTP(type: sms)` | New user row created by trigger `handle_new_user`. `isNewCustomer` = `customers.name` is empty. |
| `currentCustomer` | `from('customers').select().eq('id', uid)` | Cached after login. |
| `updateName` / `setNotifications` | `from('customers').update(...)` | RLS: own row only. Push token saved here too. |
| `logout` | `auth.signOut()` | |
| `deleteAccount` | `rpc('delete_my_account')` | Returns false while a wash is in progress. |
| `vehicleTypes` | `from('vehicle_types').select().eq('active', true).order('sort')` | Prices in paise → divide by 100. |
| `searchSocieties(q)` | `rpc('search_societies', {p_query})` | |
| `placeFromLocation(lat, lng)` | `rpc('nearest_society', {p_lat, p_lng})` | |
| `timeSlots(place, day)` | `rpc('available_slots', {p_society, p_day})` | |
| `paymentMethods` | Static list; Razorpay checkout shows the real methods | UPI intent on Android (CA3). |
| `uploadPhoto(angle, path)` | `storage.from('order-photos').upload('drafts/<uid>/<angle>.jpg')` | Moved under the order after `create_order`. Private bucket. |
| `createOrder(...)` | `rpc('create_order', {...})` | Server sets the price. Floor is required. |
| `pay(orderId, method)` | `functions.invoke('create-payment')` → Razorpay checkout SDK | Outcome confirmed by `razorpay-webhook`, not by the app. |
| `checkPayment(orderId)` | `from('payments').select('status')` | For C18c "Check again". |
| `watchOrder(orderId)` | Realtime: `from('orders').stream(primaryKey: ['id']).eq('id', orderId)` | Drives C20 → C22 → C23 → C25 automatically. |
| `getOrder` / `myOrders` | `from('orders').select('*, vehicles(*), washers(name, rating, washes), refunds(*), disputes(*)')` | Washer fields limited to first name, rating and count. |
| `myVehicles` | `from('vehicles').select()` | |
| `cancelOrder(orderId, reason)` | `rpc('cancel_order', {p_order, p_reason})` | Fee after accept comes from `app_settings.cancellation_fee_paise`. |
| `answerCantFind(orderId, answer)` | `from('order_events').insert(kind: 'customer_answer')` + push to washer | |
| `approve(orderId)` | `rpc('approve_order', {p_order})` | |
| `rate(orderId, stars, tags)` | `rpc('rate_order', {...})` | Ratings of 2 or below flagged for human review. |
| `reportProblem(orderId, kind, note)` | `rpc('report_problem', {...})` + upload dispute photos + `functions.invoke('ai-photo-check', mode: 'dispute')` | Damage → priority, washer paused. |

Status mapping: database `order_status` values are the snake_case form of the app's `OrderStatus` enum (`on_the_way` ↔ `onTheWay`).
