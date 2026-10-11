# Wheelio web and backend

The web app is a Next.js App Router application deployed to Cloudflare Workers through the OpenNext adapter. Route Handlers run as part of the same Worker deployment. Better Auth provides email and password authentication, and Drizzle connects to Neon Postgres through Neon’s serverless HTTP driver.

## Local setup

Use Node.js 24 and pnpm 11. Copy `.env.example` to `.env.local`, then fill in `DATABASE_URL`, `BETTER_AUTH_SECRET` and `BETTER_AUTH_URL`. The local `.env.local` file is ignored by Git. For Cloudflare runtime preview, `.dev.vars` selects the development environment; copy `.dev.vars.example` if it is missing.

From the repository root:

```sh
pnpm install
pnpm dev
```

`pnpm dev` runs the regular Next.js development server. To preview through the Workers runtime instead, run `pnpm preview`. Authentication and database requests need a real Neon URL and Better Auth secret; the landing page and `/api/health` do not.

## Cloudflare deployment

The Worker name is `wheelio-web`. After connecting Wrangler to the intended Cloudflare account with `wrangler login`, `pnpm deploy` builds the OpenNext Worker and deploys it. Add these runtime secrets/environment variables to the Worker in the Cloudflare dashboard before deployment:

- `DATABASE_URL` — Neon connection string with SSL enabled.
- `BETTER_AUTH_SECRET` — a random secret with at least 32 characters.
- `BETTER_AUTH_URL` — the public application origin, such as `https://example.com`.

For Cloudflare Workers Builds, provide those values under Build variables and secrets as well, so the Next.js build can access any server values it needs. Never commit populated `.env*` or `.dev.vars` files.

## Database and authentication

`src/lib/db/schema.ts` declares Better Auth’s PostgreSQL tables. `drizzle.config.ts` points Drizzle Kit at that schema. Once the Neon credentials are available, generate a migration with `pnpm db:generate`, review it, and apply it with `pnpm db:migrate`. These commands have not been run against a database.

The auth endpoint is `/api/auth/*`; a basic health endpoint is `/api/health`. The current site has no sign-in UI yet. The existing Supabase migrations and edge functions under `backend/supabase/` are preserved; this setup does not migrate their application schema or data.
