import { assertResult, paymentState, verifyIpn } from "../_shared/momo.ts";
import { ApiError, config, errorResponse, rpc } from "../_shared/server.ts";

Deno.serve(async (request: Request) => {
  if (request.method === "GET") {
    return new Response(
      'MoMo Sandbox — Quay lại ứng dụng WashCare và chọn Kiểm tra trạng thái để xem kết quả giao dịch.',
      { headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } },
    );
  }
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    const settings = config();
    const data = await request.json();
    if (data.partnerCode !== settings.partnerCode ||
        !(await verifyIpn(data, settings.accessKey, settings.secretKey))) {
      throw new ApiError(401, "Invalid signature");
    }
    // The database validates the reference, request ID and amount under row locks.
    assertResult(data, {
      gateway_order_id: data.orderId, request_id: data.requestId, amount: data.amount,
    }, settings.partnerCode);
    await rpc("apply_momo_result", {
      p_gateway_order_id: data.orderId,
      p_request_id: data.requestId,
      p_amount: data.amount,
      p_state: paymentState(data.resultCode),
      p_result_code: data.resultCode,
      p_transaction_id: data.resultCode === 0 ? String(data.transId) : null,
    });
    return new Response(null, { status: 204 });
  } catch (error) {
    return errorResponse(error);
  }
});
