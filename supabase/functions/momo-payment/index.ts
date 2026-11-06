import { canonical, sign, requireSandboxUrl } from "../_shared/momo.ts";
import { ApiError, config, cors, errorResponse, json, momoRequest, queryPayment, rpc, userId } from "../_shared/server.ts";

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: cors });
  if (request.method !== "POST") return json({ message: "Method not allowed" }, 405);
  try {
    const owner = await userId(request);
    const settings = config();
    const body = await request.json();
    if (body.action === "configuration") return json({ configured: true });
    if (!Number.isSafeInteger(body.order_id) || body.order_id <= 0) {
      throw new ApiError(400, "Mã đơn hàng không hợp lệ.");
    }
    if (body.action === "check") {
      const current = await rpc("get_momo_payment", { p_order_id: body.order_id, p_user_id: owner });
      if (current.payment?.status === "pending") {
        await queryPayment(current.payment, settings);
      }
      const latest = await rpc("get_momo_payment", { p_order_id: body.order_id, p_user_id: owner });
      return json({ payment_status: latest.payment_status });
    }
    if (body.action !== "create") throw new ApiError(400, "Thao tác không hợp lệ.");
    const payment = await rpc("begin_momo_payment", { p_order_id: body.order_id, p_user_id: owner });
    if (payment.status === "paid") {
      const latest = await rpc("get_momo_payment", { p_order_id: body.order_id, p_user_id: owner });
      return json({ payment_status: latest.payment_status });
    }
    if (payment.pay_url) {
      return json({ payment_status: "pending", pay_url: requireSandboxUrl(payment.pay_url) });
    }

    // Stable IDs and payload are reused when a request is retried after a timeout.
    const callbackUrl = settings.url + "/functions/v1/momo-callback";
    const fields = {
      accessKey: settings.accessKey,
      amount: payment.amount,
      extraData: "",
      ipnUrl: callbackUrl,
      orderId: payment.gateway_order_id,
      orderInfo: "WashCare don " + body.order_id,
      partnerCode: settings.partnerCode,
      redirectUrl: callbackUrl,
      requestId: payment.request_id,
      requestType: "captureWallet",
    };
    const response = await momoRequest("create", {
      ...fields,
      signature: await sign(settings.secretKey, canonical(fields)),
      lang: "vi",
      autoCapture: true,
    });
    // Result 0 here means the payment page was created, not that money was received.
    if (response.resultCode === 0) {
      if (response.orderId !== payment.gateway_order_id || response.requestId !== payment.request_id) {
        throw new ApiError(502, "MoMo trả về giao dịch không khớp.");
      }
      const payUrl = requireSandboxUrl(response.payUrl);
      await rpc("save_momo_pay_url", { p_id: payment.id, p_pay_url: payUrl });
      return json({ payment_status: "pending", pay_url: payUrl });
    }
    if ([40, 41].includes(Number(response.resultCode))) {
      const state = await queryPayment(payment, settings);
      return json({ payment_status: state });
    }
    // An explicit gateway rejection permits a fresh attempt. Network failures remain pending.
    if (Number.isSafeInteger(response.resultCode)) {
      await rpc("apply_momo_result", {
        p_gateway_order_id: payment.gateway_order_id,
        p_request_id: payment.request_id,
        p_amount: payment.amount,
        p_state: "failed",
        p_result_code: response.resultCode,
        p_transaction_id: null,
      });
    }
    throw new ApiError(502, "MoMo chưa tạo được trang thanh toán. Vui lòng kiểm tra cấu hình Sandbox.");
  } catch (error) {
    return errorResponse(error);
  }
});
