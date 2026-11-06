BEGIN;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS momo_payment_status text
  NOT NULL DEFAULT 'unpaid'
  CHECK (momo_payment_status IN ('unpaid','pending','paid','failed','review_required'));

CREATE TABLE IF NOT EXISTS public.momo_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id bigint NOT NULL REFERENCES public.orders(id),
  gateway_order_id text NOT NULL UNIQUE,
  request_id text NOT NULL UNIQUE,
  amount bigint NOT NULL CHECK (amount > 0),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','failed')),
  pay_url text,
  transaction_id text,
  result_code integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS momo_one_pending_per_order
  ON public.momo_payments(order_id) WHERE status = 'pending';

ALTER TABLE public.momo_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.momo_payments FROM anon, authenticated;
GRANT SELECT ON public.momo_payments TO authenticated;
DROP POLICY IF EXISTS momo_read_own ON public.momo_payments;
CREATE POLICY momo_read_own ON public.momo_payments FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.orders o WHERE o.id = order_id
    AND (o.user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()))
));

CREATE OR REPLACE FUNCTION public.create_order_v2(p_customer_name text, p_phone text, p_address text, p_pickup_time timestamp with time zone, p_note text, p_items jsonb, p_delivery_type text DEFAULT 'standard', p_payment_method text DEFAULT 'cod', p_voucher_code text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_order_id bigint;
  v_total numeric(12,2) := 0;
  v_item jsonb;
  v_service_id bigint;
  v_quantity numeric;
  v_price numeric(12,2);
  v_subtotal numeric(12,2);
  v_shipping numeric(12,2);
  v_discount numeric(12,2) := 0;
  v_snapshots jsonb := '[]'::jsonb;
  v_voucher text := nullif(upper(trim(p_voucher_code)), '');
begin
  if v_user_id is null then
    raise exception 'Bạn cần đăng nhập để đặt đơn.';
  end if;
  if p_pickup_time is null or p_pickup_time <= now() then
    raise exception 'Vui lòng chọn thời gian lấy đồ trong tương lai.';
  end if;
  if p_delivery_type is null or p_delivery_type not in ('standard', 'express')
     or p_payment_method is null or p_payment_method not in ('cod', 'momo') then
    raise exception 'Phương thức giao nhận hoặc thanh toán không hợp lệ.';
  end if;
  if nullif(trim(p_customer_name), '') is null
     or nullif(trim(p_phone), '') is null
     or nullif(trim(p_address), '') is null then
    raise exception 'Vui lòng nhập họ tên, số điện thoại và địa chỉ.';
  end if;
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Đơn hàng phải có ít nhất một dịch vụ.';
  end if;
  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_service_id := (v_item->>'service_id')::bigint;
    v_quantity := (v_item->>'quantity')::numeric;
    if v_quantity is null or v_quantity::text in ('NaN', 'Infinity', '-Infinity') or v_quantity <= 0 then
      raise exception 'Số lượng phải lớn hơn 0.';
    end if;
    select s.price
      into v_price
      from public.services s
     where s.id = v_service_id
       and s.is_active = true
     for share;
    if not found then
      raise exception 'Dịch vụ không tồn tại hoặc đã ngừng hoạt động.';
    end if;
    if v_price is null or v_price::text in ('NaN', 'Infinity', '-Infinity') or v_price < 0 then
      raise exception 'Đơn giá dịch vụ không hợp lệ.';
    end if;
    v_subtotal := round(v_price * v_quantity, 2);
    v_total := v_total + v_subtotal;
    v_snapshots := v_snapshots || jsonb_build_array(jsonb_build_object(
      'service_id', v_service_id, 'quantity', v_quantity,
      'unit_price', v_price, 'subtotal', v_subtotal
    ));
  end loop;
  v_shipping := case
    when p_delivery_type = 'express' then 25000
    when v_total >= 100000 then 0 else 15000 end;
  if v_voucher is not null then
    if v_voucher <> 'WASHCARE20' or v_total < 50000 then
      raise exception 'Mã ưu đãi không hợp lệ hoặc đơn chưa đủ 50.000đ.';
    end if;
    v_discount := 20000;
  end if;
  insert into public.orders (
    user_id,
    customer_name,
    phone,
    address,
    pickup_time,
    note,
    total_price,
    service_subtotal, shipping_fee, discount_amount,
    delivery_type, payment_method, voucher_code,
    status
  )
  values (
    v_user_id,
    trim(p_customer_name),
    trim(p_phone),
    trim(p_address),
    p_pickup_time,
    nullif(trim(coalesce(p_note, '')), ''),
    greatest(v_total + v_shipping - v_discount, 0),
    v_total, v_shipping, v_discount,
    p_delivery_type, p_payment_method, v_voucher,
    'pending'
  )
  returning id into v_order_id;
  for v_item in select value from jsonb_array_elements(v_snapshots)
  loop
    v_service_id := (v_item->>'service_id')::bigint;
    v_quantity := (v_item->>'quantity')::numeric;
    v_price := (v_item->>'unit_price')::numeric;
    v_subtotal := (v_item->>'subtotal')::numeric;
    insert into public.order_items (
      order_id,
      service_id,
      quantity,
      unit_price,
      subtotal
    )
    values (
      v_order_id,
      v_service_id,
      v_quantity,
      v_price,
      v_subtotal
    );
  end loop;
  return jsonb_build_object(
    'id', v_order_id,
    'total_price', greatest(v_total + v_shipping - v_discount, 0)
  );
end;
$function$;


-- The following helpers are callable only by the authenticated Edge Function service.
CREATE OR REPLACE FUNCTION public.get_momo_payment(p_order_id bigint, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_payment public.momo_payments%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND OR (
    v_order.user_id IS DISTINCT FROM p_user_id AND NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = p_user_id AND role = 'admin'
    )
  ) THEN RAISE EXCEPTION 'Không có quyền xem thanh toán của đơn này.'; END IF;
  SELECT * INTO v_payment FROM public.momo_payments
    WHERE order_id = p_order_id ORDER BY created_at DESC, id DESC LIMIT 1;
  RETURN jsonb_build_object('payment_status', v_order.momo_payment_status,
    'payment', CASE WHEN v_payment.id IS NULL THEN NULL ELSE to_jsonb(v_payment) END);
END;
$$;

CREATE OR REPLACE FUNCTION public.begin_momo_payment(p_order_id bigint, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_payment public.momo_payments%ROWTYPE;
  v_id uuid := gen_random_uuid();
  v_reference text;
BEGIN
  SELECT * INTO v_order FROM public.orders
    WHERE id = p_order_id AND user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy đơn hàng của bạn.'; END IF;
  IF v_order.payment_method IS DISTINCT FROM 'momo' OR v_order.status = 'cancelled' THEN
    RAISE EXCEPTION 'Đơn hàng không thể thanh toán qua MoMo Sandbox.';
  END IF;
  IF v_order.total_price <= 0 OR v_order.total_price <> trunc(v_order.total_price) THEN
    RAISE EXCEPTION 'MoMo yêu cầu số tiền nguyên dương.';
  END IF;
  SELECT * INTO v_payment FROM public.momo_payments
    WHERE order_id = p_order_id AND status IN ('pending','paid')
    ORDER BY (status = 'paid') DESC, created_at DESC LIMIT 1;
  IF FOUND THEN RETURN to_jsonb(v_payment); END IF;

  v_reference := 'WASHCARE-' || p_order_id || '-' || replace(v_id::text, '-', '');
  INSERT INTO public.momo_payments(id, order_id, gateway_order_id, request_id, amount)
    VALUES (v_id, p_order_id, v_reference, v_reference, v_order.total_price)
    RETURNING * INTO v_payment;
  UPDATE public.orders SET momo_payment_status = 'pending' WHERE id = p_order_id;
  RETURN to_jsonb(v_payment);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_momo_pay_url(p_id uuid, p_pay_url text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  UPDATE public.momo_payments SET pay_url = p_pay_url WHERE id = p_id;
$$;

CREATE OR REPLACE FUNCTION public.apply_momo_result(
  p_gateway_order_id text, p_request_id text, p_amount bigint,
  p_state text, p_result_code integer, p_transaction_id text DEFAULT NULL
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_payment public.momo_payments%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_order_id bigint;
  v_paid integer;
  v_pending integer;
  v_status text;
BEGIN
  SELECT order_id INTO v_order_id FROM public.momo_payments
    WHERE gateway_order_id = p_gateway_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy giao dịch.'; END IF;
  -- Always lock the order before its payment rows, matching begin_momo_payment.
  SELECT * INTO v_order FROM public.orders WHERE id = v_order_id FOR UPDATE;
  SELECT * INTO v_payment FROM public.momo_payments
    WHERE gateway_order_id = p_gateway_order_id FOR UPDATE;
  IF v_payment.request_id IS DISTINCT FROM p_request_id
    OR v_payment.amount IS DISTINCT FROM p_amount
    OR v_order.total_price IS DISTINCT FROM p_amount::numeric THEN
    RAISE EXCEPTION 'Thông tin giao dịch không khớp.';
  END IF;
  IF p_state IS NULL OR p_state NOT IN ('pending','paid','failed') THEN
    RAISE EXCEPTION 'Kết quả giao dịch không hợp lệ.';
  END IF;
  IF p_state = 'paid' AND (p_result_code <> 0 OR nullif(p_transaction_id, '') IS NULL) THEN
    RAISE EXCEPTION 'Thiếu xác nhận giao dịch thành công.';
  END IF;
  IF v_payment.status = 'paid' AND p_state = 'paid'
    AND v_payment.transaction_id IS DISTINCT FROM p_transaction_id THEN
    RAISE EXCEPTION 'Mã giao dịch không khớp.';
  END IF;

  IF v_payment.status <> 'paid' AND
    (p_state <> 'pending' OR v_payment.status = 'pending') THEN
    UPDATE public.momo_payments SET status = p_state,
      result_code = p_result_code, transaction_id = p_transaction_id
      WHERE id = v_payment.id;
  END IF;
  SELECT count(*) FILTER (WHERE status = 'paid'),
         count(*) FILTER (WHERE status = 'pending')
    INTO v_paid, v_pending FROM public.momo_payments WHERE order_id = v_order_id;
  v_status := CASE
    WHEN v_paid > 1 OR (v_paid > 0 AND v_order.status = 'cancelled') THEN 'review_required'
    WHEN v_paid > 0 THEN 'paid'
    WHEN v_pending > 0 THEN 'pending'
    ELSE 'failed' END;
  UPDATE public.orders SET momo_payment_status = v_status WHERE id = v_order_id;
  RETURN v_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_momo_cancellation()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM NEW.status
    AND OLD.payment_method = 'momo'
    AND OLD.momo_payment_status IN ('pending','paid','review_required') THEN
    RAISE EXCEPTION 'Cần kiểm tra giao dịch MoMo trước khi hủy đơn.';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS momo_cancellation_guard ON public.orders;
CREATE TRIGGER momo_cancellation_guard BEFORE UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.guard_momo_cancellation();

REVOKE ALL ON FUNCTION public.get_momo_payment(bigint,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.begin_momo_payment(bigint,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.save_momo_pay_url(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_momo_result(text,text,bigint,text,integer,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_momo_payment(bigint,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.begin_momo_payment(bigint,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.save_momo_pay_url(uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_momo_result(text,text,bigint,text,integer,text) TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
