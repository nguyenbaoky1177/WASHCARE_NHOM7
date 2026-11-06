import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import {
  canonical, sign, verifyIpn, paymentState, requireSandboxUrl, assertResult,
} from "./momo.ts";

test("HMAC matches the RFC 4231 SHA-256 test vector", async () => {
  assert.equal(await sign("\x0b".repeat(20), "Hi There"),
    "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7");
});

test("create signature fields use MoMo alphabetical ordering", () => {
  assert.equal(canonical({
    requestType: "captureWallet", requestId: "rq", redirectUrl: "https://return",
    partnerCode: "partner", orderInfo: "WashCare don 1", orderId: "od",
    ipnUrl: "https://ipn", extraData: "", amount: 95000, accessKey: "access",
  }), "accessKey=access&amount=95000&extraData=&ipnUrl=https://ipn&orderId=od&orderInfo=WashCare don 1&partnerCode=partner&redirectUrl=https://return&requestId=rq&requestType=captureWallet");
});

const callback = {
  amount: 95000, extraData: "", message: "Success", orderId: "order-1",
  orderInfo: "WashCare don 1", orderType: "momo_wallet", partnerCode: "partner",
  payType: "web", requestId: "request-1", responseTime: 1790000000000,
  resultCode: 0, transId: 123456,
};
const signedText = "accessKey=access&amount=95000&extraData=&message=Success&orderId=order-1&orderInfo=WashCare don 1&orderType=momo_wallet&partnerCode=partner&payType=web&requestId=request-1&responseTime=1790000000000&resultCode=0&transId=123456";
const signature = createHmac("sha256", "secret").update(signedText).digest("hex");

test("IPN signature validates genuine payload and rejects changed amount or key", async () => {
  assert.equal(await verifyIpn({ ...callback, signature }, "access", "secret"), true);
  assert.equal(await verifyIpn({ ...callback, amount: 1, signature }, "access", "secret"), false);
  assert.equal(await verifyIpn({ ...callback, signature }, "access", "wrong"), false);
  assert.equal(await verifyIpn({ ...callback, signature: "bad" }, "access", "secret"), false);
});

test("a valid signature still needs a matching stored transaction", () => {
  const stored = { gateway_order_id: "order-1", request_id: "request-1", amount: 95000 };
  assert.equal(assertResult(callback, stored, "partner"), 0);
  assert.throws(() => assertResult(callback, { ...stored, amount: 95001 }, "partner"));
  assert.throws(() => assertResult(callback, { ...stored, request_id: "other" }, "partner"));
  assert.throws(() => assertResult({ ...callback, transId: 0 }, stored, "partner"));
});

test("pending and authorized results are never counted as paid", () => {
  for (const code of [1000, 7000, 9000]) assert.equal(paymentState(code), "pending");
  assert.equal(paymentState(0), "paid");
  assert.equal(paymentState(1006), "failed");
});

test("only HTTPS links on the Sandbox host are accepted", () => {
  assert.equal(requireSandboxUrl("https://test-payment.momo.vn/pay?id=1"),
    "https://test-payment.momo.vn/pay?id=1");
  for (const url of [
    "https://payment.momo.vn/pay", "http://test-payment.momo.vn/pay",
    "https://test-payment.momo.vn.evil.test/pay",
    "https://user@test-payment.momo.vn/pay", "javascript:alert(1)",
  ]) assert.throws(() => requireSandboxUrl(url));
});

const env: Record<string, string> = {
  SUPABASE_URL: "https://project.supabase.co", SUPABASE_ANON_KEY: "anon",
  SUPABASE_SERVICE_ROLE_KEY: "server-only", MOMO_PARTNER_CODE: "partner",
  MOMO_ACCESS_KEY: "access", MOMO_SECRET_KEY: "secret",
};
type Handler = (request: Request) => Promise<Response>;
let handler: Handler;
(globalThis as any).Deno = {
  env: { get: (key: string) => env[key] },
  serve: (value: Handler) => { handler = value; },
};
await import("../momo-payment/index.ts");
const paymentHandler = handler!;
await import("../momo-callback/index.ts");
const callbackHandler = handler!;
const originalFetch = globalThis.fetch;
const respond = (value: unknown) => new Response(JSON.stringify(value), {
  headers: { "Content-Type": "application/json" },
});
const stored = {
  id: "9c3ca000-0000-4000-8000-000000000001", order_id: 1,
  gateway_order_id: "order-1", request_id: "request-1", amount: 95000, status: "pending",
};
function appRequest(body: unknown, authenticated = true) {
  return new Request("https://project.supabase.co/functions/v1/momo-payment", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(authenticated ? { Authorization: "Bearer user-token" } : {}) },
    body: JSON.stringify(body),
  });
}

test("create page success only saves the URL, never marks the order paid", async () => {
  const calls: string[] = [];
  globalThis.fetch = async (input, options) => {
    const url = String(input);
    calls.push(url);
    if (url.endsWith("/auth/v1/user")) return respond({ id: "customer-id" });
    if (url.endsWith("/begin_momo_payment")) return respond(stored);
    if (url.endsWith("/create")) return respond({
      resultCode: 0, orderId: stored.gateway_order_id, requestId: stored.request_id,
      payUrl: "https://test-payment.momo.vn/pay?id=1",
    });
    if (url.endsWith("/save_momo_pay_url")) {
      const body = JSON.parse(String(options?.body));
      assert.equal(body.p_pay_url, "https://test-payment.momo.vn/pay?id=1");
      return respond(null);
    }
    throw new Error("Unexpected API " + url);
  };
  try {
    const result = await paymentHandler(appRequest({ action: "create", order_id: 1 }));
    assert.equal(result.status, 200);
    assert.equal((await result.json()).payment_status, "pending");
    assert.equal(calls.some((url) => url.endsWith("/apply_momo_result")), false);
  } finally { globalThis.fetch = originalFetch; }
});

test("a timeout after creating an intent does not declare failure or success", async () => {
  const calls: string[] = [];
  globalThis.fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url.endsWith("/auth/v1/user")) return respond({ id: "customer-id" });
    if (url.endsWith("/begin_momo_payment")) return respond(stored);
    throw new Error("Network timeout");
  };
  try {
    const response = await paymentHandler(appRequest({ action: "create", order_id: 1 }));
    assert.equal(response.status, 502);
    assert.equal(calls.some((url) => url.endsWith("/apply_momo_result")), false);
  } finally { globalThis.fetch = originalFetch; }
});

test("anonymous payment requests cannot reach database helpers", async () => {
  globalThis.fetch = async () => { throw new Error("Must not fetch"); };
  try {
    assert.equal((await paymentHandler(appRequest({ action: "create", order_id: 1 }, false))).status, 401);
  } finally { globalThis.fetch = originalFetch; }
});

test("IPN rejects an invalid signature before calling the database", async () => {
  globalThis.fetch = async () => { throw new Error("Must not fetch"); };
  try {
    const response = await callbackHandler(new Request("https://callback", {
      method: "POST", body: JSON.stringify({ ...callback, signature: "0".repeat(64) }),
    }));
    assert.equal(response.status, 401);
  } finally { globalThis.fetch = originalFetch; }
});

test("verified IPN passes the original ID and amount to the locked database operation", async () => {
  let calls = 0;
  globalThis.fetch = async (input, options) => {
    assert.ok(String(input).endsWith("/apply_momo_result"));
    const body = JSON.parse(String(options?.body));
    assert.equal(body.p_amount, 95000);
    assert.equal(body.p_request_id, "request-1");
    assert.equal(body.p_state, "paid");
    calls++;
    return respond("paid");
  };
  try {
    for (let attempt = 0; attempt < 2; attempt++) {
      const response = await callbackHandler(new Request("https://callback", {
        method: "POST", body: JSON.stringify({ ...callback, signature }),
      }));
      assert.equal(response.status, 204);
    }
    assert.equal(calls, 2);
  } finally { globalThis.fetch = originalFetch; }
});
test("saved pending URLs are reused without issuing another provider create", async () => {
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.endsWith("/auth/v1/user")) return respond({ id: "customer-id" });
    if (url.endsWith("/begin_momo_payment")) return respond({
      ...stored, pay_url: "https://test-payment.momo.vn/pay?id=existing",
    });
    throw new Error("Provider must not be called");
  };
  try {
    const response = await paymentHandler(appRequest({ action: "create", order_id: 1 }));
    assert.equal(response.status, 200);
    assert.equal((await response.json()).pay_url, "https://test-payment.momo.vn/pay?id=existing");
  } finally { globalThis.fetch = originalFetch; }
});

test("checking uses a fresh query signature and applies only the verified provider status", async () => {
  for (const code of [0, 7000, 9000, 1006]) {
    let state = "pending";
    globalThis.fetch = async (input, options) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) return respond({ id: "customer-id" });
      if (url.endsWith("/get_momo_payment")) return respond({
        payment_status: state, payment: { ...stored, status: state },
      });
      if (url.endsWith("/query")) {
        const body = JSON.parse(String(options?.body));
        assert.notEqual(body.requestId, stored.request_id);
        const raw = "accessKey=access&orderId=order-1&partnerCode=partner&requestId=" + body.requestId;
        assert.equal(body.signature, createHmac("sha256", "secret").update(raw).digest("hex"));
        return respond({
          partnerCode: "partner", orderId: stored.gateway_order_id,
          requestId: body.requestId, amount: stored.amount, transId: 123456,
          resultCode: code,
        });
      }
      if (url.endsWith("/apply_momo_result")) {
        const body = JSON.parse(String(options?.body));
        assert.equal(body.p_request_id, stored.request_id);
        state = body.p_state;
        return respond(state);
      }
      throw new Error("Unexpected API " + url);
    };
    try {
      const response = await paymentHandler(appRequest({ action: "check", order_id: 1 }));
      assert.equal(response.status, 200);
      assert.equal((await response.json()).payment_status, paymentState(code));
    } finally { globalThis.fetch = originalFetch; }
  }
});

test("missing Sandbox configuration is reported before a payment intent is inserted", async () => {
  const secret = env.MOMO_SECRET_KEY;
  delete env.MOMO_SECRET_KEY;
  globalThis.fetch = async (input) => {
    assert.ok(String(input).endsWith("/auth/v1/user"));
    return respond({ id: "customer-id" });
  };
  try {
    const response = await paymentHandler(appRequest({ action: "configuration" }));
    assert.equal(response.status, 503);
  } finally {
    env.MOMO_SECRET_KEY = secret;
    globalThis.fetch = originalFetch;
  }
});
test("browser return parameters cannot mark an order paid", async () => {
  globalThis.fetch = async () => { throw new Error("Must not fetch"); };
  try {
    const response = await callbackHandler(new Request(
      "https://callback?resultCode=0&amount=95000&orderId=order-1",
    ));
    assert.equal(response.status, 200);
    assert.match(await response.text(), /Kiểm tra trạng thái/);
  } finally { globalThis.fetch = originalFetch; }
});
