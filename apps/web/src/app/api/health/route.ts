import { is, sql } from "drizzle-orm";
import { getTableConfig, PgTable } from "drizzle-orm/pg-core";
import { createDb } from "@/lib/db";
import * as schema from "@/lib/db/schema";
import journal from "../../../../drizzle/meta/_journal.json";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const tables = Object.values(schema)
      .filter((value) => is(value, PgTable))
      .map((value) => getTableConfig(value as PgTable).name);
    const result = await createDb().execute(sql`
      select bool_and(to_regclass('public.' || quote_ident(name)) is not null)
        and (select count(*) from drizzle.__drizzle_migrations) = ${journal.entries.length}
        and to_regprocedure('public.current_user_id()') is not null
        and to_regprocedure('public.delete_my_account()') is not null as ready
      from unnest(array[${sql.join(tables.map((name) => sql`${name}`), sql`, `)}]::text[]) as name
    `);
    const ready = result.rows[0]?.ready === true
      && Boolean(process.env.BETTER_AUTH_SECRET && process.env.BETTER_AUTH_URL);
    return Response.json({ status: ready ? "ok" : "unavailable", service: "wheelio-web", database: ready ? "ready" : "not_ready" }, {
      status: ready ? 200 : 503,
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return Response.json({ status: "unavailable", service: "wheelio-web", database: "not_ready" }, {
      status: 503,
      headers: { "Cache-Control": "no-store" },
    });
  }
}
