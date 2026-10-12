import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { getTableConfig, isPgEnum, PgTable } from "drizzle-orm/pg-core";
import { is } from "drizzle-orm";
import * as schema from "../src/lib/db/schema";
import { connectDatabase, reportDatabaseError } from "./db-connection";

type Connection = ReturnType<typeof connectDatabase>;

export async function checkMigrationHistory(sql: Connection, requireComplete = true) {
  const journal = JSON.parse(await readFile("drizzle/meta/_journal.json", "utf8")) as {
    entries: { tag: string; when: number }[];
  };
  const [exists] = await sql`select to_regclass('drizzle.__drizzle_migrations') is not null as present`;
  const applied = exists.present
    ? await sql`select hash, created_at from drizzle.__drizzle_migrations order by created_at, id`
    : [];
  assert(applied.length <= journal.entries.length, "Database has migrations missing from this checkout.");
  for (let i = 0; i < applied.length; i++) {
    const entry = journal.entries[i];
    const hash = createHash("sha256").update(await readFile(`drizzle/${entry.tag}.sql`)).digest("hex");
    assert.equal(applied[i].hash, hash, `Applied migration ${entry.tag} has changed; restore it before proceeding.`);
    assert.equal(Number(applied[i].created_at), entry.when, `Migration order differs at ${entry.tag}.`);
  }
  if (requireComplete) assert.equal(applied.length, journal.entries.length, "Database migrations are pending. Run pnpm db:migrate.");
  return applied.length;
}

export async function verifyDatabase(sql: Connection) {
  const migrationCount = await checkMigrationHistory(sql);
  const tables = Object.values(schema).filter((value) => is(value, PgTable)).map((value) => getTableConfig(value as PgTable));
  const columns = await sql`select table_name, column_name, is_nullable, data_type
    from information_schema.columns where table_schema = 'public'`;
  const relations = await sql`select relname, relrowsecurity from pg_class
    where relnamespace = 'public'::regnamespace and relkind = 'r'`;
  const types = await sql`select c.relname as table_name, a.attname as column_name,
    format_type(a.atttypid, a.atttypmod) as type
    from pg_attribute a join pg_class c on c.oid = a.attrelid
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and a.attnum > 0 and not a.attisdropped`;
  const constraints = await sql`select conname from pg_constraint where connamespace = 'public'::regnamespace`;
  const indexes = await sql`select indexname from pg_indexes where schemaname = 'public'`;
  for (const table of tables) {
    const relation = relations.find((row) => row.relname === table.name);
    assert(relation, `Missing table: ${table.name}`);
    assert.equal(relation.relrowsecurity, table.enableRLS, `RLS differs for ${table.name}`);
    for (const column of table.columns) {
      const actual = columns.find((row) => row.table_name === table.name && row.column_name === column.name);
      assert(actual, `Missing column: ${table.name}.${column.name}`);
      assert.equal(actual.is_nullable, column.notNull ? "NO" : "YES", `Nullability differs for ${table.name}.${column.name}`);
      const type = types.find((row) => row.table_name === table.name && row.column_name === column.name);
      const expectedType = column.getSQLType().replace(/^bigserial$/, "bigint").replace(/^serial$/, "integer").replace(/numeric\((\d+),\s*(\d+)\)/, "numeric($1,$2)");
      assert.equal(type?.type, expectedType, `Type differs for ${table.name}.${column.name}`);
    }
    for (const check of table.checks) {
      assert(constraints.some((row) => row.conname === check.name), `Missing constraint: ${check.name}`);
    }
    for (const foreignKey of table.foreignKeys) {
      assert(constraints.some((row) => row.conname === foreignKey.getName()), `Missing foreign key: ${foreignKey.getName()}`);
    }
    for (const index of table.indexes) {
      assert(indexes.some((row) => row.indexname === index.config.name), `Missing index: ${index.config.name}`);
    }
  }
  const [extensions] = await sql`select count(*)::int as count from pg_extension where extname in ('postgis', 'pgcrypto')`;
  assert.equal(extensions.count, 2, "PostGIS/pgcrypto extensions are missing.");
  const enumValues = await sql`select t.typname, e.enumlabel from pg_enum e join pg_type t on t.oid = e.enumtypid
    where t.typnamespace = 'public'::regnamespace order by e.enumsortorder`;
  for (const enumType of Object.values(schema)) {
    if (!isPgEnum(enumType)) continue;
    assert.deepEqual(enumValues.filter((row) => row.typname === enumType.enumName).map((row) => row.enumlabel), enumType.enumValues, `Enum values differ for ${enumType.enumName}`);
  }
  const functions = await sql`select proname from pg_proc where pronamespace = 'public'::regnamespace`;
  for (const name of ["current_user_id", "is_admin", "setting_int", "log_event", "create_order", "cancel_order", "approve_order", "rate_order", "report_problem", "delete_my_account", "search_societies", "nearest_society", "available_slots"]) {
    assert(functions.some((row) => row.proname === name), `Missing function: ${name}`);
  }
  const [config] = await sql`select
    (select count(*)::int from app_settings) as settings,
    (select count(*)::int from vehicle_types) as vehicles,
    (select count(*)::int from slot_templates) as slots`;
  assert(config.settings >= 10 && config.vehicles >= 4 && config.slots >= 6, "Initial settings/catalogue/slots are incomplete.");
  const policies = await sql`select tablename from pg_policies where schemaname = 'public'`;
  for (const table of tables.filter((table) => table.enableRLS)) {
    assert(policies.some((row) => row.tablename === table.name), `Missing policies for ${table.name}`);
  }
  console.log(`Database verified: ${tables.length} tables, ${migrationCount} migrations, extensions, identity functions, policies, and catalogue configuration.`);
}

if (process.argv[1]?.endsWith("db-check.ts")) {
  void (async () => {
    let sql: Connection | undefined;
    try {
      sql = connectDatabase();
      await sql.begin("read only", async (tx) => {
        await verifyDatabase(tx as unknown as Connection);
      });
    } catch (error) {
      reportDatabaseError(error);
    } finally {
      await sql?.end();
    }
  })();
}
