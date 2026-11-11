import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import test, { before, after } from "node:test";
import assert from "node:assert/strict";

// Install the test runtime using the command in the root README.
const require = createRequire(new URL("../../.dart_tool/momo-sql-check/package.json", import.meta.url));
const { PGlite } = require("@electric-sql/pglite");
const db = new PGlite();
const a = "00000000-0000-4000-8000-000000000001";
const b = "00000000-0000-4000-8000-000000000002";
let order;
let intent;

before(async () => {
  await db.exec(readFileSync(new URL("./momo_fixture.sql", import.meta.url), "utf8"));
  for (const file of [
    "202611050001_align_order_workflow.sql", "202611050002_momo_demo.sql",
    "202611050003_momo_sandbox.sql", "202611050003_momo_sandbox.sql",
    "202611050004_first_order_voucher.sql",
  ]) {
    await db.exec(readFileSync(new URL("../migrations/" + file, import.meta.url), "utf8"));
  }
});
after(async () => { await db.close(); });

async function role(name, uid = "") {
  await db.exec("RESET ROLE");
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [uid]);
  if (name !== "postgres") await db.exec("SET ROLE " + name);
}
async function result(sql, params = []) {
  return (await db.query(sql, params)).rows[0].result;
}
async function apply(payment, state, code, transaction = null, amount = payment.amount) {
  return result("SELECT public.apply_momo_result($1,$2,$3,$4,$5,$6) AS result",
    [payment.gateway_order_id, payment.request_id, amount, state, code, transaction]);
}

test("migrations apply twice and customer checkout calculates the stored amount", async () => {
  await role("authenticated", a);
  const created = await result(
    "SELECT public.create_order_v2('Test','0999999999','Test',now()+interval '1 day','TEST NOTE',$1,'standard','momo','WASHCARE20') AS result",
    [JSON.stringify([{ service_id: 1, quantity: 1 }])],
  );
  assert.equal(created.total_price, 75000);
  order = created.id;
});

test("customers cannot call service-only helpers, even with a forged user ID", async () => {
  await role("authenticated", a);
  await assert.rejects(() => result(
    "SELECT public.begin_momo_payment($1,$2) AS result", [order, b],
  ), /permission denied/);
});

test("repeated start requests reuse one pending provider reference", async () => {
  await role("service_role");
  intent = await result("SELECT public.begin_momo_payment($1,$2) AS result", [order, a]);
  const repeat = await result("SELECT public.begin_momo_payment($1,$2) AS result", [order, a]);
  assert.equal(intent.id, repeat.id);
  assert.equal(intent.amount, 75000);
  await assert.rejects(() => result(
    "SELECT public.begin_momo_payment($1,$2) AS result", [order, b],
  ), /Không tìm thấy/);
});

test("a second customer cannot read the first customer's payment row", async () => {
  await role("authenticated", b);
  const rows = (await db.query("SELECT * FROM public.momo_payments")).rows;
  assert.deepEqual(rows, []);
});

test("customer updates cannot forge a paid flag or cancel an in-flight payment", async () => {
  await role("authenticated", a);
  await assert.rejects(() => db.query(
    "UPDATE public.orders SET momo_payment_status='paid' WHERE id=$1", [order],
  ), /permission denied/);
  await assert.rejects(() => db.query(
    "UPDATE public.orders SET status='cancelled' WHERE id=$1", [order],
  ), /Cần kiểm tra giao dịch MoMo/);
});

test("mismatched amount and request IDs cannot settle a transaction", async () => {
  await role("service_role");
  await assert.rejects(() => apply(intent, "paid", 0, "transaction-1", 1), /không khớp/);
  await assert.rejects(() => apply({ ...intent, request_id: "forged" }, "paid", 0, "transaction-1"), /không khớp/);
});

test("duplicate successful callbacks stay paid and preserve customer notes", async () => {
  await role("service_role");
  assert.equal(await apply(intent, "paid", 0, "transaction-1"), "paid");
  assert.equal(await apply(intent, "paid", 0, "transaction-1"), "paid");
  assert.equal(await apply(intent, "failed", 1006), "paid");
  await role("postgres");
  const row = (await db.query("SELECT note,momo_payment_status FROM public.orders WHERE id=$1", [order])).rows[0];
  assert.equal(row.note, "TEST NOTE");
  assert.equal(row.momo_payment_status, "paid");
  assert.equal(Number((await db.query("SELECT count(*) AS n FROM public.momo_payments WHERE order_id=$1", [order])).rows[0].n), 1);
});

test("already paid orders cannot start a second payment or be cancelled", async () => {
  await role("service_role");
  const paid = await result("SELECT public.begin_momo_payment($1,$2) AS result", [order, a]);
  assert.equal(paid.id, intent.id);
  assert.equal(paid.status, "paid");
  await role("authenticated", a);
  await assert.rejects(() => db.query(
    "UPDATE public.orders SET status='cancelled' WHERE id=$1", [order],
  ), /Cần kiểm tra giao dịch MoMo/);
});
test("failed attempts may retry, while late conflicting successes require review", async () => {
  await role("authenticated", a);
  const fresh = await result(
    "SELECT public.create_order_v2('Test','0999999999','Test',now()+interval '1 day','RETRY',$1,'standard','momo',null) AS result",
    [JSON.stringify([{ service_id: 1, quantity: 1 }])],
  );
  await role("service_role");
  const first = await result("SELECT public.begin_momo_payment($1,$2) AS result", [fresh.id, a]);
  assert.equal(await apply(first, "failed", 1006), "failed");
  const second = await result("SELECT public.begin_momo_payment($1,$2) AS result", [fresh.id, a]);
  assert.notEqual(first.id, second.id);
  assert.equal(await apply(first, "paid", 0, "late-transaction"), "paid");
  assert.equal(await apply(second, "paid", 0, "second-transaction"), "review_required");
});

test("first-order voucher is blocked after an existing order and restored after cancellation", async () => {
  await role("authenticated", a);
  assert.equal(await result("SELECT public.is_first_order_eligible() AS result"), false);
  await assert.rejects(() => result(
    "SELECT public.create_order_v2('Test','0999999999','Test',now()+interval '1 day','SECOND VOUCHER',$1,'standard','cod','WASHCARE20') AS result",
    [JSON.stringify([{ service_id: 1, quantity: 1 }])],
  ), /đơn đầu tiên/);
  await role("authenticated", b);
  assert.equal(await result("SELECT public.is_first_order_eligible() AS result"), true);
  const first = await result(
    "SELECT public.create_order_v2('Test B','0999999999','Test',now()+interval '1 day','FIRST VOUCHER',$1,'standard','cod','WASHCARE20') AS result",
    [JSON.stringify([{ service_id: 1, quantity: 1 }])],
  );
  assert.equal(first.total_price, 75000);
  assert.equal(await result("SELECT public.is_first_order_eligible() AS result"), false);
  await db.query("UPDATE public.orders SET status='cancelled' WHERE id=$1", [first.id]);
  assert.equal(await result("SELECT public.is_first_order_eligible() AS result"), true);
});
