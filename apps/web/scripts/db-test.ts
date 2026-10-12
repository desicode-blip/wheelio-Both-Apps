import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { drizzle } from "drizzle-orm/postgres-js";
import { createAuth } from "../src/lib/auth";
import * as schema from "../src/lib/db/schema";
import { connectDatabase, reportDatabaseError } from "./db-connection";
import { verifyDatabase } from "./db-check";

async function main() {
  const url = process.env.WHEELIO_TEST_DATABASE_URL;
  if (!url || !["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
    throw new Error("db:test writes test fixtures. Set WHEELIO_TEST_DATABASE_URL to a migrated, disposable local PostgreSQL database.");
  }
  const sql = connectDatabase(url);
  const id = randomUUID();
  const a = `test-customer-${id}`, b = `test-other-${id}`, washer = `test-washer-${id}`;
  const society = randomUUID();
  const rollback = new Error("ROLLBACK_TEST_FIXTURES");
  try {
    await verifyDatabase(sql);
    try {
      await sql.begin(async (tx) => {
        for (const uid of [a, b, washer]) {
          await tx`insert into "user" (id, name, email) values (${uid}, 'Database test', ${`${uid}@example.invalid`})`;
        }
        await tx`insert into customers (id, phone, free_washes) values (${a}, ${a}, 1), (${b}, ${b}, 0)`;
        await tx`insert into washers (id, phone, status) values (${washer}, ${washer}, 'active')`;
        await tx`insert into societies (id, name, area, location, is_live)
          values (${society}, 'Test society', 'Test area', st_point(78.358, 17.392)::geography, true)`;
        await tx`insert into washer_societies (washer_id, society_id) values (${washer}, ${society})`;
        await tx`select set_config('wheelio.user_id', ${a}, true)`;
        const createOrder = (free = false, floor = "B2") => tx`select * from create_order(
          'hatchback', 'TS09EA4521', ${society}, 'Tower 3', ${floor}, '41',
          now() + interval '1 day', now() + interval '1 day 2 hours', '', null, ${free})`;
        async function rejects(operation: (sp: typeof tx) => Promise<unknown>, message: RegExp) {
          await assert.rejects(tx.savepoint((sp) => operation(sp as typeof tx)), message);
        }
        await rejects((sp) => sp`select * from create_order('hatchback', 'TS09EA4521', ${society}, '', '', '', now() + interval '1 day', now() + interval '1 day 2 hours')`, /floor_required/);
        const [paid] = await createOrder();
        assert.equal(paid.price_paise, 14900);
        assert.match(paid.ref, /^WH-\d+$/);
        const [free] = await createOrder(true);
        assert.equal(free.price_paise, 0);
        let [credits] = await tx`select free_washes from customers where id = ${a}`;
        assert.equal(credits.free_washes, 0);
        await rejects((sp) => sp`select * from create_order('hatchback', 'TS09EA4521', ${society}, '', 'B2', '', now() + interval '1 day', now() + interval '1 day 2 hours', '', null, true)`, /no_free_washes/);
        await tx`select * from cancel_order(${free.id})`;
        [credits] = await tx`select free_washes from customers where id = ${a}`;
        assert.equal(credits.free_washes, 1);
        await rejects((sp) => sp`select * from cancel_order(${free.id})`, /cannot_cancel_now/);
        await tx`select set_config('wheelio.user_id', ${b}, true)`;
        await rejects((sp) => sp`select * from cancel_order(${paid.id})`, /not_found/);
        await rejects((sp) => sp`select * from approve_order(${paid.id})`, /cannot_approve/);
        // Exercise RLS as a non-owner; the migration/owner role bypasses RLS by design.
        await tx.unsafe('create role wheelio_test_reader nologin');
        await tx.unsafe('grant usage on schema public to wheelio_test_reader');
        await tx.unsafe('grant select on all tables in schema public to wheelio_test_reader');
        await tx.unsafe('grant execute on function current_user_id(), is_admin() to wheelio_test_reader');
        await tx.unsafe('set local role wheelio_test_reader');
        const [visible] = await tx`select count(*)::int as count from orders where customer_id = ${a}`;
        assert.equal(visible.count, 0);
        await tx`select set_config('wheelio.user_id', ${a}, true)`;
        const [own] = await tx`select count(*)::int as count from orders where customer_id = ${a}`;
        assert.equal(own.count, 2);
        await tx.unsafe('reset role');
        await tx`insert into payments (order_id, amount_paise, status) values (${paid.id}, ${paid.price_paise}, 'captured')`;
        await tx`update orders set status = 'searching' where id = ${paid.id}`;
        const [blocked] = await tx`select delete_my_account() as deleted`;
        assert.equal(blocked.deleted, false);
        await tx`select * from cancel_order(${paid.id}, 'Test cancellation')`;
        const [refund] = await tx`select amount_paise from refunds where order_id = ${paid.id}`;
        assert.equal(refund.amount_paise, paid.price_paise);
        const [completed] = await createOrder();
        await tx`update orders set status = 'photos_ready', washer_id = ${washer}, finished_at = now() where id = ${completed.id}`;
        await tx`insert into payouts (order_id, washer_id, gross_paise, net_paise) values (${completed.id}, ${washer}, 10000, 10000)`;
        await tx`select * from approve_order(${completed.id})`;
        const [payout] = await tx`select status from payouts where order_id = ${completed.id}`;
        assert.equal(payout.status, 'released');
        await tx`select rate_order(${completed.id}, 5)`;
        await tx`select rate_order(${completed.id}, 1)`;
        const [rating] = await tx`select stars, needs_review from ratings where order_id = ${completed.id}`;
        assert.equal(rating.stars, 1);
        assert.equal(rating.needs_review, true);
        const [dispute] = await tx`select * from report_problem(${completed.id}, 'damage', 'Test')`;
        assert.equal(dispute.outcome, 'damage_priority');
        const [held] = await tx`select status from payouts where order_id = ${completed.id}`;
        assert.equal(held.status, 'held');
        const [captain] = await tx`select status from washers where id = ${washer}`;
        assert.equal(captain.status, 'paused');
        await tx`update orders set status = 'dispute_upheld' where id = ${completed.id}`;
        const [deleted] = await tx`select delete_my_account() as deleted`;
        assert.equal(deleted.deleted, true);
        const [profile] = await tx`select deleted_at, phone from customers where id = ${a}`;
        assert(profile.deleted_at);
        assert.equal(profile.phone, `deleted:${a}`);
        const [history] = await tx`select count(*)::int as count from orders where customer_id = ${a}`;
        assert.equal(history.count, 3);
        await rejects((sp) => sp`select * from create_order('hatchback', 'TS09EA4521', ${society}, '', 'B2', '', now() + interval '1 day', now() + interval '1 day 2 hours')`, /not_logged_in/);
        console.log("Booking, credits, cancellation/refunds, user isolation/RLS, approval/payout, ratings, damage disputes, and account deletion passed.");
        throw rollback;
      });
    } catch (error) {
      if (error !== rollback) throw error;
    }

    // Test the actual Better Auth configuration with a PostgreSQL adapter.
    const auth = createAuth(drizzle(sql, { schema }));
    const email = `auth-${id}@example.invalid`;
    const password = `test-${id}-password`;
    let authUserId: string | undefined;
    try {
      const created = await auth.api.signUpEmail({ body: { name: "Auth test", email, password } });
      authUserId = created.user.id;
      assert(created.token);
      const signedIn = await auth.api.signInEmail({ body: { email, password }, asResponse: true });
      assert.equal(signedIn.status, 200);
      const headers = new Headers({ cookie: signedIn.headers.getSetCookie().map((cookie) => cookie.split(";")[0]).join("; ") });
      const session = await auth.api.getSession({ headers });
      assert.equal(session?.user.id, authUserId);
      const [sessions] = await sql`select count(*)::int as count from session where user_id = ${authUserId}`;
      assert(sessions.count >= 1);
      await assert.rejects(auth.api.signInEmail({ body: { email, password: "incorrect-password" } }));
      await auth.api.signOut({ headers });
      assert.equal(await auth.api.getSession({ headers }), null);
      console.log("Better Auth sign-up, sign-in, session lookup/persistence, sign-out, and incorrect-password rejection passed.");
    } finally {
      if (authUserId) await sql`delete from "user" where id = ${authUserId}`;
    }
  } finally {
    await sql.end();
  }
}

void main().catch(reportDatabaseError);
