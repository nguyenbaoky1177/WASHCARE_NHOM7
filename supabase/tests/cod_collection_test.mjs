import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";

// Uses the same local PostgreSQL runtime as momo_sandbox_test.mjs.
const require = createRequire(new URL("../../.dart_tool/momo-sql-check/package.json", import.meta.url));
const { PGlite } = require("@electric-sql/pglite");

test("COD checkout, fulfillment and collection are authorized and retry-safe", async () => {
  const db = new PGlite();
  const customer = "00000000-0000-4000-8000-000000000001";
  const admin = "00000000-0000-4000-8000-000000000002";
  async function asUser(user) {
    await db.exec("RESET ROLE");
    await db.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [user]);
    await db.exec("SET ROLE authenticated");
  }
  try {
    await db.exec(readFileSync(new URL("./momo_fixture.sql", import.meta.url), "utf8"));
    await db.exec("CREATE PUBLICATION supabase_realtime");
    const migrations = [
      "202611050001_align_order_workflow.sql",
      "202611050002_momo_demo.sql",
      "202611050003_momo_sandbox.sql",
      "202611050004_first_order_voucher.sql",
      "202611050005_orders_realtime.sql",
      "202611100001_cod_collection.sql",
      "202611100001_cod_collection.sql",
    ];
    for (const file of migrations) {
      await db.exec(readFileSync(new URL("../migrations/" + file, import.meta.url), "utf8"));
    }
    await db.query("UPDATE public.profiles SET role = 'admin' WHERE id = $1", [admin]);
    // Ensure the trigger remains effective even if table-wide UPDATE is granted.
    await db.exec("GRANT UPDATE ON public.orders TO authenticated");

    await asUser(customer);
    const created = (await db.query(
      "SELECT public.create_order_v2('Customer','0999999999','Test',now()+interval '1 day','Test',$1,'standard','cod',NULL) AS receipt",
      [JSON.stringify([{ service_id: 1, quantity: 1 }])],
    )).rows[0].receipt;
    const id = created.id;
    const confirm = async () => (await db.query(
      "SELECT public.admin_confirm_cod_collection($1) AS receipt", [id],
    )).rows[0].receipt;
    await assert.rejects(confirm, /Admin access required/);
    await assert.rejects(() => db.query(
      "UPDATE public.orders SET status = 'cancelled', cod_collected_amount = 100 WHERE id = $1", [id],
    ), /Use the admin COD collection function/);

    await asUser(admin);
    await assert.rejects(confirm, /Only completed COD orders/);
    for (const status of ["confirmed", "washing", "delivering", "completed"]) {
      await db.query("SELECT public.admin_update_order_status($1, $2)", [id, status]);
    }
    const receipt = await confirm();
    assert.equal(receipt.cod_collected_amount, created.total_price);
    assert.equal(receipt.cod_collected_by, admin);
    assert.ok(Date.parse(receipt.cod_collected_at));
    assert.deepEqual(await confirm(), receipt);

    await asUser(customer);
    const row = (await db.query(
      "SELECT cod_collected_amount, cod_collected_at FROM public.orders WHERE id = $1", [id],
    )).rows[0];
    assert.equal(Number(row.cod_collected_amount), created.total_price);
    assert.ok(row.cod_collected_at);
  } finally {
    await db.close();
  }
});
