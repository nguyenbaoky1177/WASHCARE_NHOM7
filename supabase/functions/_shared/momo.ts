export type Payload = Record<string, unknown>;
export type PaymentState = "pending" | "paid" | "failed";

export function canonical(fields: Record<string, string | number>): string {
  return Object.keys(fields).sort().map((key) => key + "=" + fields[key]).join("&");
}

export async function sign(secret: string, data: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const bytes = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function ipnFields(data: Payload, accessKey: string): Record<string, string | number> {
  const names = [
    "amount", "extraData", "message", "orderId", "orderInfo", "orderType",
    "partnerCode", "payType", "requestId", "responseTime", "resultCode", "transId",
  ];
  const result: Record<string, string | number> = { accessKey };
  for (const name of names) {
    const value = data[name];
    if (typeof value !== "string" && typeof value !== "number") {
      throw new Error("Invalid IPN field " + name);
    }
    result[name] = value;
  }
  return result;
}

export async function verifyIpn(data: Payload, accessKey: string, secret: string): Promise<boolean> {
  if (typeof data.signature !== "string" || !/^[0-9a-f]{64}$/i.test(data.signature)) return false;
  const signature = Uint8Array.from(
    data.signature.match(/../g)!, (byte) => parseInt(byte, 16),
  );
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["verify"],
  );
  return crypto.subtle.verify(
    "HMAC", key, signature, new TextEncoder().encode(canonical(ipnFields(data, accessKey))),
  );
}

export function paymentState(code: number): PaymentState {
  if (code === 0) return "paid";
  if ([1000, 7000, 9000].includes(code)) return "pending";
  return "failed";
}

// Query failures such as invalid credentials or maintenance do not settle an order.
export function isSettlementResult(code: number): boolean {
  return code === 0 || [
    1000, 7000, 9000, 1001, 1002, 1003, 1004, 1005, 1006, 1007,
    1026, 1080, 1081, 2001, 2007, 3001, 3002, 4001, 4100, 4010, 4011, 4015,
  ].includes(code);
}

export function requireSandboxUrl(value: unknown): string {
  if (typeof value !== "string") throw new Error("Missing payment URL");
  const url = new URL(value);
  if (url.protocol !== "https:" || url.hostname !== "test-payment.momo.vn" ||
      url.username || url.password || url.port) {
    throw new Error("Invalid Sandbox payment URL");
  }
  return url.toString();
}

export function assertResult(data: Payload, payment: Payload, partnerCode: string): number {
  if (data.partnerCode !== partnerCode || data.orderId !== payment.gateway_order_id ||
      data.requestId !== payment.request_id || Number(data.amount) !== Number(payment.amount)) {
    throw new Error("Payment response does not match stored request");
  }
  const code = data.resultCode;
  if (typeof code !== "number" || !Number.isSafeInteger(code)) throw new Error("Invalid result code");
  if (code === 0 && (!data.transId || String(data.transId) === "0")) {
    throw new Error("Missing successful transaction ID");
  }
  return code;
}
