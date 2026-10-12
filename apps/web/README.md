# Wheelio web and backend

The web app is a Next.js App Router application deployed to Cloudflare Workers through the OpenNext adapter. Route Handlers run as part of the same Worker deployment. Better Auth provides email and password authentication, and Drizzle connects to Neon Postgres through Neon’s serverless HTTP driver.

## Local setup

Use Node.js 24 and pnpm 11. Copy `.env.example` to `.env.local`, then fill in `DATABASE_URL`, `BETTER_AUTH_SECRET` and `BETTER_AUTH_URL`. The local `.env.local` file is ignored by Git. For Cloudflare runtime preview, `.dev.vars` selects the development environment; copy `.dev.vars.example` if it is missing.

From the repository root:

```sh
pnpm install
pnpm dev
```

`pnpm dev` runs the regular Next.js development server. To preview through the Workers runtime instead, run `pnpm preview`. Authentication and database requests need a real Neon URL and Better Auth secret. The landing page works without them; `/api/health` reports HTTP 503 until database readiness and auth configuration checks pass.

## Cloudflare deployment

The Worker name is `wheelio-web`. After connecting Wrangler to the intended Cloudflare account with `wrangler login`, `pnpm deploy` builds the OpenNext Worker and deploys it. Add these runtime secrets/environment variables to the Worker in the Cloudflare dashboard before deployment:

- `DATABASE_URL` — Neon connection string with SSL enabled.
- `BETTER_AUTH_SECRET` — a random secret with at least 32 characters.
- `BETTER_AUTH_URL` — the public application origin, such as `https://example.com`.

For Cloudflare Workers Builds, provide those values under Build variables and secrets as well, so the Next.js build can access any server values it needs. Never commit populated `.env*` or `.dev.vars` files.

## Database and authentication

`src/lib/db/schema.ts` exports four Better Auth tables and 23 application tables. Four reviewed migrations under `drizzle/` include PostGIS, indexes, constraints, identity-aware policies, customer action functions and initial configuration/catalogue data. Apply them with `pnpm db:migrate`, then run the read-only `pnpm db:check`. Migration/check commands prefer `DIRECT_URL` when supplied. The migrations and behavior tests passed in a disposable PostgreSQL/PostGIS database; all migrations were then applied to live Neon, and the HTTP web backend authentication/readiness checks passed. See [the migration guide](../../backend/NEON-DATABASE.md) for commands, identity handling, test coverage and remaining integrations.

The auth endpoint is `/api/auth/*`; `/api/health` checks database readiness. The current site has no sign-in UI yet. Original Supabase files remain under `backend/supabase/`; their application schema has been ported, while existing data and edge-function integrations have not been transferred.
