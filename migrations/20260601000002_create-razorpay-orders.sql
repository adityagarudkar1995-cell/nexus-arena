-- Razorpay order tracking for wallet top-ups.
-- Writes happen ONLY via service-role edge functions; clients get read-only RLS,
-- matching the project convention (auth.uid() = user_id, no client write policies).

CREATE TABLE IF NOT EXISTS public.razorpay_orders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  razorpay_order_id   text NOT NULL UNIQUE,
  razorpay_payment_id text UNIQUE,                       -- set on capture; NULL allows many rows
  receipt             text NOT NULL,
  amount_paise        bigint NOT NULL CHECK (amount_paise > 0),
  status              text NOT NULL DEFAULT 'created'
                        CHECK (status IN ('created', 'paid', 'failed')),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS razorpay_orders_user_idx
  ON public.razorpay_orders (user_id, created_at DESC);

ALTER TABLE public.razorpay_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "razorpay_orders: own read" ON public.razorpay_orders;
CREATE POLICY "razorpay_orders: own read"
  ON public.razorpay_orders
  FOR SELECT
  USING (auth.uid() = user_id);
