# Wheelio build status

## 10 Oct 2026: customer app code written (no outside accounts used)

### Done

- **Design system** (`packages/wheelio_ui`): every token from the design read-me (colours, type scale, spacing, radius, control sizes) and the shared components, including buttons, header and progress, footer bar, bottom nav, fields, chips, OTP boxes, tabs, tiles, badges, banners, full-screen states, photo slots, list rows, status steps, sheets, dialogs and snackbars.
- **Customer app** (`apps/customer`): all 72 customer screens and states from the designs (C01–C55, CA1–CA4):
  - Booking flow: vehicle → plate → photos → place → floor → notes → time → login → pay → booked.
  - Live order: searching → on the way → washing → check photos → approve → rate.
  - Edge states: cancel before and after accept, no washer, washer late, gate pass missing, can't find vehicle, auto-approve, report problem, dispute upheld or rejected, damage, refund tracking.
  - Home, bookings, booking detail, repeat booking, vehicles, profile, delete account and help.
  - System states: offline, error, session expired, loading, and 200% text.
- **Runs without a server.** A sample backend acts like the real one: sample customer Ananya and washer Raju, live status changes every few seconds, failures on demand. The in-app **Screens** tab on the left edge opens any screen directly and has switches for every edge case. Demo login code: 123456.
- **Ready for Supabase.** The database schema has row-level security and server functions for create order, cancel, approve, rate, report problem, delete account, society search and available slots. The sample data and the API contract are written. The payment webhook and AI photo check (Claude vision) are written.
- **Unit tests** cover plate and phone rules, time labels, OTP, the full order lifecycle and cancel refunds.

### Not verified yet

Flutter isn't installed on this Mac, so the code hasn't been compiled or run. It was reviewed by hand and a few issues were fixed. Expect a short round of compile fixes on the first `flutter analyze`. Running `tool/bootstrap_customer.sh` after installing Flutter does this, and then the app can be checked screen by screen in the iPhone simulator.

### Waiting on you

See `CONNECT-LATER.md`. The steps that unblock the most are:

1. Install Flutter (say "install Flutter").
2. Create a Supabase project in the Mumbai region.
3. Start the Apple Developer (D-U-N-S) and DLT SMS registrations, because both take 1–2 weeks.

### Next for Claude once unblocked

1. Compile, fix, and run in the simulator. Check every screen against the designs.
2. Write `SupabaseBackend` and the real device features (camera, location, push).
3. Add Razorpay checkout and the `create-payment` function.
4. Run the Android customer build (CA1–CA4 are already handled in the same code).
5. Build the washer app (W01–W50) using the same design system.
