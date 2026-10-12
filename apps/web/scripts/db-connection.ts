import { loadEnvConfig } from "@next/env";
import postgres from "postgres";

loadEnvConfig(process.cwd());

export function connectDatabase(url = process.env.DIRECT_URL || process.env.DATABASE_URL) {
  if (!url || /USER:PASSWORD|YOUR-ENDPOINT/.test(url)) {
    throw new Error("Set DATABASE_URL (or DIRECT_URL) in apps/web/.env.local before running database commands.");
  }
  return postgres(url, { max: 1, connect_timeout: 15, idle_timeout: 5, onnotice: () => {} });
}

export function reportDatabaseError(error: unknown) {
  const cause = error instanceof Error && error.cause instanceof Error ? error.cause : error;
  let message = cause instanceof Error ? cause.message : "Database operation failed.";
  for (const key of ["DIRECT_URL", "DATABASE_URL", "BETTER_AUTH_SECRET"]) {
    const value = process.env[key];
    if (value) message = message.replaceAll(value, "[redacted]");
  }
  message = message.replace(/postgres(?:ql)?:\/\/[^\s"']+/gi, "[redacted database URL]");
  console.error(message);
  process.exitCode = 1;
}
