-- Apply this entire file in Supabase SQL Editor before running the updated app.
-- New pricing metadata is nullable for historical orders.
BEGIN;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS service_subtotal numeric(12,2),
  ADD COLUMN IF NOT EXISTS shipping_fee numeric(12,2),
  ADD COLUMN IF NOT EXISTS discount_amount numeric(12,2),
  ADD COLUMN IF NOT EXISTS delivery_type text,
  ADD COLUMN IF NOT EXISTS payment_method text,
  ADD COLUMN IF NOT EXISTS voucher_code text;

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
     or p_payment_method is null or p_payment_method not in ('cod', 'vietqr') then
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

CREATE OR REPLACE FUNCTION public.admin_update_order_status(
  p_order_id bigint, p_new_status text, p_note text DEFAULT ''
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT coalesce(public.is_admin(), false) THEN
    RAISE EXCEPTION 'Chỉ admin đã đăng nhập mới được cập nhật trạng thái.';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy đơn hàng.'; END IF;
  IF p_new_status IS NULL OR NOT (
    (v_order.status = 'pending' AND p_new_status IN ('confirmed', 'cancelled'))
    OR (v_order.status = 'confirmed' AND p_new_status = 'washing')
    OR (v_order.status = 'washing' AND p_new_status = 'delivering')
    OR (v_order.status = 'delivering' AND p_new_status = 'completed')
  ) THEN
    RAISE EXCEPTION 'Chuyển trạng thái đơn hàng không hợp lệ.';
  END IF;

  -- The existing AFTER trigger writes exactly one history row.
  UPDATE public.orders SET status = p_new_status WHERE id = p_order_id;
  UPDATE public.order_status_history
  SET note = coalesce(p_note, '')
  WHERE id = (
    SELECT id FROM public.order_status_history
    WHERE order_id = p_order_id
    ORDER BY id DESC LIMIT 1
  );
  RETURN p_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_role(p_user_id uuid, p_role text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  LOCK TABLE public.profiles IN SHARE ROW EXCLUSIVE MODE;
  IF auth.uid() IS NULL OR NOT coalesce(public.is_admin(), false) THEN
    RAISE EXCEPTION 'Chỉ admin được thay đổi vai trò.';
  END IF;
  IF p_role IS NULL OR p_role NOT IN ('customer', 'admin') THEN
    RAISE EXCEPTION 'Vai trò không hợp lệ.';
  END IF;
  IF p_user_id = auth.uid() AND p_role <> 'admin' THEN
    RAISE EXCEPTION 'Không thể tự hạ quyền tài khoản quản trị đang đăng nhập.';
  END IF;
  UPDATE public.profiles SET role = p_role WHERE id = p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy tài khoản.'; END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.reviews (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  order_id bigint NOT NULL UNIQUE REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text NOT NULL DEFAULT '',
  tags jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(tags) = 'array'),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reviews_select ON public.reviews;
CREATE POLICY reviews_select ON public.reviews FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));
DROP POLICY IF EXISTS reviews_insert ON public.reviews;
CREATE POLICY reviews_insert ON public.reviews FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = reviews.order_id AND o.user_id = (SELECT auth.uid())
      AND o.status = 'completed'
  )
);
DROP POLICY IF EXISTS reviews_update ON public.reviews;
CREATE POLICY reviews_update ON public.reviews FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = reviews.order_id AND o.user_id = (SELECT auth.uid())
      AND o.status = 'completed'
  )
);
REVOKE ALL ON public.reviews FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.reviews TO authenticated;
GRANT USAGE ON SEQUENCE public.reviews_id_seq TO authenticated;

-- Updating a profile must target an existing row. No INSERT permission is added.
DROP POLICY IF EXISTS "Users can cancel their own pending orders" ON public.orders;

REVOKE ALL ON FUNCTION public.create_order_v2(text,text,text,timestamptz,text,jsonb,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_order_v2(text,text,text,timestamptz,text,jsonb,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_update_order_status(bigint,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_order_status(bigint,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_user_role(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
