import { canonical, sign, assertResult, isSettlementResult, paymentState, type Payload } from "./momo.ts";

export class ApiError extends Error {
  readonly status: number;
  constructor(status: number, message: string) { super(message); this.status = status; }
}

export function required(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new ApiError(503, "MoMo Sandbox chưa được cấu hình trên máy chủ.");
  return value;
}

export function config() {
  return {
    url: required("SUPABASE_URL"),
    partnerCode: required("MOMO_PARTNER_CODE"),
    accessKey: required("MOMO_ACCESS_KEY"),
    secretKey: required("MOMO_SECRET_KEY"),
  };
}

export async function rpc(name: string, args: Payload): Promise<any> {
  const key = required("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(required("SUPABASE_URL") + "/rest/v1/rpc/" + name, {
    method: "POST",
    headers: { apikey: key, Authorization: "Bearer " + key, "Content-Type": "application/json" },
    body: JSON.stringify(args),
    signal: AbortSignal.timeout(10000),
  });
  const data = await response.json();
  if (!response.ok) {
    console.error("Payment database operation failed", name, response.status);
    throw new ApiError(409, "Không thể cập nhật giao dịch. Hãy kiểm tra đơn và thử lại.");
  }
  return data;
}

export async function userId(request: Request): Promise<string> {
  const token = request.headers.get("Authorization") ?? "";
  if (!token.startsWith("Bearer ")) throw new ApiError(401, "Vui lòng đăng nhập lại.");
  const response = await fetch(required("SUPABASE_URL") + "/auth/v1/user", {
    headers: { apikey: required("SUPABASE_ANON_KEY"), Authorization: token },
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new ApiError(401, "Phiên đăng nhập không hợp lệ.");
  const user = await response.json();
  if (typeof user.id !== "string") throw new ApiError(401, "Phiên đăng nhập không hợp lệ.");
  return user.id;
}

export async function momoRequest(path: string, body: Payload): Promise<Payload> {
  const response = await fetch("https://test-payment.momo.vn/v2/gateway/api/" + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(35000),
  });
  if (!response.ok) throw new ApiError(502, "MoMo Sandbox đang tạm thời không phản hồi.");
  return response.json();
}

export async function settle(data: Payload, payment: Payload, settings: ReturnType<typeof config>, expectedRequestId = String(payment.request_id)) {
  const code = assertResult(data, { ...payment, request_id: expectedRequestId }, settings.partnerCode);
  if (!isSettlementResult(code)) {
    throw new ApiError(502, "MoMo chưa trả về trạng thái giao dịch. Vui lòng kiểm tra lại sau.");
  }
  return rpc("apply_momo_result", {
    p_gateway_order_id: payment.gateway_order_id,
    p_request_id: payment.request_id,
    p_amount: payment.amount,
    p_state: paymentState(code),
    p_result_code: code,
    p_transaction_id: code === 0 ? String(data.transId) : null,
  });
}

export async function queryPayment(payment: Payload, settings: ReturnType<typeof config>) {
  const fields = {
    accessKey: settings.accessKey,
    orderId: String(payment.gateway_order_id),
    partnerCode: settings.partnerCode,
    requestId: crypto.randomUUID(),
  };
  const data = await momoRequest("query", {
    partnerCode: settings.partnerCode,
    orderId: payment.gateway_order_id,
    requestId: fields.requestId,
    signature: await sign(settings.secretKey, canonical(fields)),
    lang: "vi",
  });
  return settle(data, payment, settings, fields.requestId);
}

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof ApiError) return json({ message: error.message }, error.status);
  console.error("Payment operation failed", error instanceof Error ? error.name : "unknown");
  return json({ message: "Không thể kiểm tra thanh toán. Vui lòng thử lại." }, 502);
}
