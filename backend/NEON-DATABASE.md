# Historical database archive - no current frontend

The Next.js/Neon frontend was retired and removed on 28 October 2026 at the
owner's request. The current apps use Firebase; the migration commands/paths
below are historical, recoverable in Git af036f0. Do not run them as setup for
the current apps, migrate data or delete any database during frontend cleanup.

# Neon database migration

The active web backend uses Neon PostgreSQL, Drizzle and Better Auth. The migrations in `apps/web/drizzle/` port the original Supabase application schema to this stack. This is a schema migration; no existing Supabase user or business data has been copied.

## Included

Four ordered migrations create 27 tables:

- Authentication: `user`, `session`, `account`, `verification`.
- Configuration/catalogue: `app_settings`, `vehicle_types`, `societies`, `slot_templates`.
- People/vehicles: `customers`, `washers`, `admins`, `washer_societies`, `vehicles`.
- Bookings/evidence: `orders`, `order_events`, `order_photos`, `entry_passes`, `job_offers`.
- Money/quality: `payments`, `refunds`, `payouts`, `credits_ledger`, `ratings`, `disputes`.
- Training: `training_videos`, `washer_training`, `quiz_attempts`.

The port retains foreign keys, indexes, six enums, money in paise, PostGIS location indexes, row-level policies, catalogue defaults, configuration values, booking references and customer action functions. Identity references use Better Auth text IDs instead of Supabase UUID users. Business record IDs remain UUIDs.

Prices/settings retain the original specification, including notes identifying proposed values. Undecided cancellation/wait fees remain JSON null. Demo users and live societies are not inserted into the live database. Training video IDs and service availability need operational configuration.

## Apply future migrations to Neon

Set `DATABASE_URL` in `apps/web/.env.local`. `DIRECT_URL` is optional and, when present, is used by migration/check commands instead of the pooled connection. The application uses `DATABASE_URL`. Both URLs must point to the same database/branch. Keep credentials in ignored environment files.

`BETTER_AUTH_SECRET` must be a random server secret of at least 32 characters. `BETTER_AUTH_URL` is the application origin. A local secret was generated during this setup; production needs a stable secret configured in its runtime environment.

From the repository root:

```sh
pnpm db:migrate
pnpm db:check
```

The migrator takes an advisory lock, checks the hashes/order of previously applied migrations, and runs pending migrations through Drizzle's transaction. It then verifies tables, columns/types/nullability, constraints, foreign keys, indexes, enums, extensions, functions, RLS, policies and initial configuration rows. Repeating the command does not recreate the schema or replace data. Existing unmanaged tables require a deliberate baseline; this setup does not drop them or force a schema replacement.

Use `pnpm db:generate --name=<change>` for future typed schema changes. Add custom Drizzle migrations for policy/function changes. Applied migrations are immutable. Avoid `drizzle-kit push`: policies/functions and configuration inserts are managed by custom migrations.

`/api/health` performs a readiness query: HTTP 200 requires the expected tables, migration count, identity/account-deletion functions and auth configuration; missing/unavailable configuration returns HTTP 503 without connection details. `pnpm db:check` performs the detailed inspection.

## Authenticated SQL

`public.current_user_id()` reads transaction-local `wheelio.user_id`. Application routes must obtain this ID from a verified Better Auth session and set it with `set_config('wheelio.user_id', session.user.id, true)` **inside the same transaction** as the operation. Never take it from a request body or persist it on a pooled connection. With Neon's HTTP driver, batch the setting and operation using `neon(...).transaction([...])`; Drizzle callback transactions are unsupported by the HTTP adapter.

Security-definer functions have PUBLIC execution revoked and are intended for the trusted server connection. The migration/owner connection bypasses RLS: routes using it must enforce ownership themselves or call ownership-checking action functions. A separate restricted runtime role needs explicit table/column and function grants. Never expose the owner connection to browser/mobile clients.

Customer profiles require a verified phone number before insertion; email registration alone does not create a phone-verified customer or approved captain.

## Verified on 12 October 2026

All four migrations passed in a disposable PostgreSQL 17/PostGIS database and were then applied to the configured live Neon database. The live migration/check commands passed, including a repeat migration run. The local production web backend returned HTTP 200 readiness and passed registration, login, persisted signed-cookie session lookup, incorrect-password rejection and logout against Neon; its temporary test account was removed. Reapplying migrations and the read-only integrity check passed. Integration tests covered:

- Server-priced bookings and required-floor validation.
- Free-wash reservation, insufficient-credit rejection and exactly-once return on cancellation.
- Cross-customer action rejection and RLS filtering with a non-owner role.
- Captured-payment cancellations producing correct refund records.
- Approval releasing payouts, updated low ratings triggering review, and damage disputes holding payouts/pausing captains.
- Deletion blocked during active bookings, customer/vehicle/location scrubbing, and retention of referenced financial/order history.
- The actual Better Auth configuration: registration, login, signed-cookie session lookup, persistence, logout and incorrect-password rejection.
- TypeScript, the production build and HTTP 503 readiness behavior with missing credentials.

To repeat behavior tests, create and migrate a disposable local PostgreSQL/PostGIS database. Set `WHEELIO_TEST_DATABASE_URL` to its localhost URL and run `pnpm db:test`. The command refuses remote hosts; business fixtures and its test role roll back, and its auth user is cleaned up. It does not migrate the test database automatically. To verify the local web API against the configured database, start the app with `pnpm start` (or `pnpm dev`) and run `pnpm db:auth-check`. This creates a uniquely named temporary auth user and removes it afterward; business-flow tests remain restricted to a disposable local database.

## Pending

The live Neon database is migrated and the local web backend is verified against it. Both iOS apps still use demo stores; migrating tables does not connect those screens. Booking/captain routes, phone OTP, photo/object storage, Razorpay checkout/webhooks, WhatsApp, push notifications, dispatch/realtime and scheduled approval/payout jobs still need implementation and/or provider configuration. Preserved Supabase edge functions need adaptation for Neon. Deletion of retained media/provider artifacts requires storage integration and a retention policy.
