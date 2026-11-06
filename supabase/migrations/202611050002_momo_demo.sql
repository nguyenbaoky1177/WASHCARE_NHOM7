-- Apply after 202611050001_align_order_workflow.sql.
BEGIN;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS demo_payment_status text NOT NULL DEFAULT 'unpaid'
    CHECK (demo_payment_status IN ('unpaid', 'succeeded'));

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
     or p_payment_method is null or p_payment_method not in ('cod', 'momo_demo') then
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

CREATE OR REPLACE FUNCTION public.record_momo_demo_payment(p_order_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Bạn cần đăng nhập để thử thanh toán.';
  END IF;
  SELECT * INTO v_order FROM public.orders
    WHERE id = p_order_id AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy đơn hàng của bạn.';
  END IF;
  IF v_order.payment_method IS DISTINCT FROM 'momo_demo' THEN
    RAISE EXCEPTION 'Đơn hàng không sử dụng MoMo mô phỏng.';
  END IF;
  IF v_order.status = 'cancelled' THEN
    RAISE EXCEPTION 'Đơn hàng đã hủy.';
  END IF;

  -- Repeated requests return the same simulated result.
  IF v_order.demo_payment_status <> 'succeeded' THEN
    UPDATE public.orders SET demo_payment_status = 'succeeded'
      WHERE id = p_order_id;
  END IF;
  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'demo_payment_status', 'succeeded',
    'total_price', v_order.total_price
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_momo_demo_payment(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_momo_demo_payment(bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
