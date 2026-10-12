import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { connectDatabase, reportDatabaseError } from "./db-connection";

async function main() {
  const base = new URL(process.env.AUTH_CHECK_URL || "http://localhost:3000");
  assert(["localhost", "127.0.0.1", "[::1]"].includes(base.hostname), "Run auth-check against the local app connected to the intended database.");
  assert(process.env.BETTER_AUTH_URL, "BETTER_AUTH_URL is required.");
  const origin = new URL(process.env.BETTER_AUTH_URL).origin;
  const sql = connectDatabase();
  const id = randomUUID();
  const email = `wheelio-check-${id}@example.invalid`;
  const password = `check-${id}-password`;
  let cookie = "";
  async function request(path: string, body?: Record<string, string>) {
    return fetch(new URL(path, base), {
      method: body ? "POST" : "GET",
      headers: { Origin: origin, Cookie: cookie, ...(body ? { "Content-Type": "application/json" } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
  }
  try {
    const health = await request("/api/health");
    assert.equal(health.status, 200, "The local web backend does not report a ready database.");
    const signup = await request("/api/auth/sign-up/email", { name: "Temporary database check", email, password });
    assert.equal(signup.status, 200, "Registration failed against the web backend.");
    const registered = await signup.json() as { user: { id: string } };
    const login = await request("/api/auth/sign-in/email", { email, password });
    assert.equal(login.status, 200, "Login failed against the web backend.");
    cookie = login.headers.getSetCookie().map((value) => value.split(";")[0]).join("; ");
    const sessionResponse = await request("/api/auth/get-session");
    assert.equal(sessionResponse.status, 200);
    const session = await sessionResponse.json() as { user: { id: string } };
    assert.equal(session?.user.id, registered.user.id, "Session lookup did not identify the registered user.");
    const [persisted] = await sql`select count(*)::int as count from session where user_id = ${registered.user.id}`;
    assert(persisted.count >= 1, "Session was not persisted in the configured database.");
    const incorrect = await request("/api/auth/sign-in/email", { email, password: "incorrect-password" });
    assert.equal(incorrect.status, 401, "Incorrect credentials were not rejected.");
    const logout = await request("/api/auth/sign-out", {});
    assert.equal(logout.status, 200);
    const ended = await request("/api/auth/get-session");
    assert.equal(await ended.json(), null, "Logged-out session remained active.");
    console.log("HTTP backend checks passed: database readiness, registration, login, persisted session lookup, incorrect-password rejection, and logout.");
  } finally {
    // This unique address identifies only the fixture, even if registration partially failed.
    try { await sql`delete from "user" where email = ${email}`; }
    finally { await sql.end(); }
  }
}

void main().catch(reportDatabaseError);
