import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import { checkMigrationHistory, verifyDatabase } from "./db-check";
import { connectDatabase, reportDatabaseError } from "./db-connection";

async function main() {
  let sql: ReturnType<typeof connectDatabase> | undefined;
  let locked = false;
  try {
    sql = connectDatabase();
    // One connection keeps the session lock across Drizzle's migration transaction.
    await sql`select pg_advisory_lock(817492, 1)`;
    locked = true;
    await checkMigrationHistory(sql, false);
    await migrate(drizzle(sql), { migrationsFolder: "./drizzle" });
    await verifyDatabase(sql);
  } catch (error) {
    reportDatabaseError(error);
  } finally {
    if (sql) {
      try { if (locked) await sql`select pg_advisory_unlock(817492, 1)`; }
      finally { await sql.end(); }
    }
  }

}

void main();
