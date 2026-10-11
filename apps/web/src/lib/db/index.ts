import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";
import * as schema from "./schema";

export function createDb(connectionString = requiredDatabaseUrl()) {
  const client = neon(connectionString);
  return drizzle({ client, schema });
}

function requiredDatabaseUrl() {
  const connectionString = process.env.DATABASE_URL;

  if (!connectionString) {
    throw new Error(
      "DATABASE_URL is missing. Copy apps/web/.env.example to apps/web/.env.local and add your Neon connection string.",
    );
  }

  return connectionString;
}
