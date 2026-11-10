BEGIN;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cod_collected_at timestamptz,
  ADD COLUMN IF NOT EXISTS cod_collected_by uuid,
  ADD COLUMN IF NOT EXISTS cod_collected_amount numeric;

CREATE OR REPLACE FUNCTION public.guard_cod_collection()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.cod_collected_at IS NOT NULL OR NEW.cod_collected_by IS NOT NULL
      OR NEW.cod_collected_amount IS NOT NULL THEN
      RAISE EXCEPTION 'Use the admin COD collection function.' USING ERRCODE = '42501';
    END IF;
  ELSIF (NEW.cod_collected_at, NEW.cod_collected_by, NEW.cod_collected_amount)
      IS DISTINCT FROM (OLD.cod_collected_at, OLD.cod_collected_by, OLD.cod_collected_amount) THEN
    RAISE EXCEPTION 'Use the admin COD collection function.' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_cod_collection ON public.orders;
CREATE TRIGGER guard_cod_collection
BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.guard_cod_collection();

CREATE OR REPLACE FUNCTION public.admin_confirm_cod_collection(p_order_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_admin uuid := auth.uid();
  v_order public.orders%ROWTYPE;
BEGIN
  IF v_admin IS NULL OR NOT coalesce(public.is_admin(), false) THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found.'; END IF;

  IF coalesce(v_order.payment_method, 'cod') <> 'cod'
    OR v_order.status IS DISTINCT FROM 'completed'
    OR v_order.total_price IS NULL OR v_order.total_price <= 0 THEN
    RAISE EXCEPTION 'Only completed COD orders with a positive total can be confirmed.';
  END IF;

  IF v_order.cod_collected_at IS NULL THEN
    UPDATE public.orders
    SET cod_collected_at = now(),
        cod_collected_by = v_admin,
        cod_collected_amount = v_order.total_price
    WHERE id = p_order_id
    RETURNING * INTO v_order;
  END IF;

  RETURN jsonb_build_object(
    'cod_collected_at', v_order.cod_collected_at,
    'cod_collected_by', v_order.cod_collected_by,
    'cod_collected_amount', v_order.cod_collected_amount
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_confirm_cod_collection(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_confirm_cod_collection(bigint) TO authenticated;

COMMIT;
