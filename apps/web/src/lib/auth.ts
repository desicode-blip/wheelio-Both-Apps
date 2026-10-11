import { drizzleAdapter } from "@better-auth/drizzle-adapter";
import { betterAuth } from "better-auth/minimal";
import { createDb } from "./db";
import * as schema from "./db/schema";

export function createAuth() {
  const secret = process.env.BETTER_AUTH_SECRET;
  const baseURL = process.env.BETTER_AUTH_URL;

  if (!secret) {
    throw new Error("BETTER_AUTH_SECRET is missing from the server environment.");
  }

  if (!baseURL) {
    throw new Error("BETTER_AUTH_URL is missing from the server environment.");
  }

  return betterAuth({
    secret,
    baseURL,
    database: drizzleAdapter(createDb(), {
      provider: "pg",
      schema,
    }),
    emailAndPassword: {
      enabled: true,
    },
  });
}
