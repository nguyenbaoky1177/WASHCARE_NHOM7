-- Local test fixture reconstructed from the supplied database audit.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.profiles(
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  full_name text, phone text, role text NOT NULL DEFAULT 'customer'
    CHECK (role IN ('customer','admin')), created_at timestamptz DEFAULT now()
);
CREATE TABLE public.services(
  id bigint PRIMARY KEY, name text, description text, price numeric(12,2),
  unit text, icon text, is_active boolean DEFAULT true
);
CREATE TABLE public.orders(
  id bigserial PRIMARY KEY, user_id uuid REFERENCES public.profiles(id),
  customer_name text, phone text, address text, pickup_time timestamptz, note text,
  total_price numeric(12,2) CHECK(total_price >= 0),
  status text CHECK(status IN ('pending','confirmed','washing','delivering','completed','cancelled')),
  created_at timestamptz DEFAULT now()
);
CREATE TABLE public.order_items(
  id bigserial PRIMARY KEY, order_id bigint REFERENCES public.orders(id),
  service_id bigint REFERENCES public.services(id), quantity numeric CHECK(quantity>0),
  unit_price numeric(12,2), subtotal numeric(12,2)
);
CREATE TABLE public.order_status_history(
  id bigserial PRIMARY KEY, order_id bigint REFERENCES public.orders(id),
  old_status text, new_status text, changed_by uuid REFERENCES auth.users(id), note text
);
CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql
STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin');
$$;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY orders_read ON public.orders FOR SELECT TO authenticated
  USING(user_id=auth.uid() OR public.is_admin());
CREATE POLICY orders_user_cancel_own_pending ON public.orders FOR UPDATE TO authenticated
  USING(user_id=auth.uid() AND status='pending')
  WITH CHECK(user_id=auth.uid() AND status='cancelled');
GRANT SELECT ON public.orders TO authenticated;
GRANT UPDATE(status,note) ON public.orders TO authenticated;
INSERT INTO auth.users VALUES
 ('00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000002');
INSERT INTO public.profiles(id,full_name) VALUES
 ('00000000-0000-4000-8000-000000000001','Customer A'),
 ('00000000-0000-4000-8000-000000000002','Customer B');
INSERT INTO public.services(id,name,price,unit) VALUES(1,'Laundry',80000,'kg');
