-- Balances stored in paise (1 Rs = 100 paise) for exact integer arithmetic
CREATE TABLE wallets (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  balance              bigint NOT NULL DEFAULT 0 CHECK (balance >= 0),
  total_deposited      bigint NOT NULL DEFAULT 0,
  total_withdrawn      bigint NOT NULL DEFAULT 0,
  total_won            bigint NOT NULL DEFAULT 0,
  total_tds_deducted   bigint NOT NULL DEFAULT 0,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER wallets_updated_at
  BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Users can only read their own wallet; writes go through functions only
CREATE POLICY "wallets: own read" ON wallets FOR SELECT USING (auth.uid() = user_id);

-- Auto-create wallet when profile is created
CREATE OR REPLACE FUNCTION handle_new_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO wallets (user_id) VALUES (NEW.id) ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_profile_created
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION handle_new_profile();

-- Immutable ledger — every wallet movement recorded here
CREATE TABLE wallet_transactions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type             transaction_type NOT NULL,
  amount           bigint NOT NULL,          -- positive = credit, negative = debit
  balance_after    bigint NOT NULL,          -- wallet balance snapshot after this tx
  reference_id     uuid,                     -- FK to registrations / withdrawals / etc.
  reference_type   text,                     -- 'registration' | 'withdrawal' | 'deposit'
  description      text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wallet_transactions: own read" ON wallet_transactions FOR SELECT USING (auth.uid() = user_id);

-- Indexes for common query patterns
CREATE INDEX wallet_transactions_user_id_idx    ON wallet_transactions(user_id);
CREATE INDEX wallet_transactions_created_at_idx ON wallet_transactions(created_at DESC);
CREATE INDEX wallet_transactions_type_idx       ON wallet_transactions(type);

-- Atomic wallet deduction — deducts amount and records ledger entry in one transaction
-- Returns the new balance in paise. Raises exception if insufficient funds.
CREATE OR REPLACE FUNCTION deduct_wallet(
  p_user_id      uuid,
  p_amount       bigint,
  p_type         transaction_type,
  p_reference_id uuid DEFAULT NULL,
  p_ref_type     text DEFAULT NULL,
  p_description  text DEFAULT NULL
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_balance bigint;
BEGIN
  UPDATE wallets
  SET balance = balance - p_amount
  WHERE user_id = p_user_id AND balance >= p_amount
  RETURNING balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'insufficient_funds';
  END IF;

  INSERT INTO wallet_transactions (user_id, type, amount, balance_after, reference_id, reference_type, description)
  VALUES (p_user_id, p_type, -p_amount, v_new_balance, p_reference_id, p_ref_type, p_description);

  RETURN v_new_balance;
END;
$$;

-- Credit wallet and record ledger entry
CREATE OR REPLACE FUNCTION credit_wallet(
  p_user_id      uuid,
  p_amount       bigint,
  p_type         transaction_type,
  p_reference_id uuid DEFAULT NULL,
  p_ref_type     text DEFAULT NULL,
  p_description  text DEFAULT NULL
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_balance bigint;
BEGIN
  UPDATE wallets
  SET balance = balance + p_amount,
      total_won = CASE WHEN p_type = 'prize' THEN total_won + p_amount ELSE total_won END,
      total_deposited = CASE WHEN p_type = 'deposit' THEN total_deposited + p_amount ELSE total_deposited END
  WHERE user_id = p_user_id
  RETURNING balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'wallet_not_found';
  END IF;

  INSERT INTO wallet_transactions (user_id, type, amount, balance_after, reference_id, reference_type, description)
  VALUES (p_user_id, p_type, p_amount, v_new_balance, p_reference_id, p_ref_type, p_description);

  RETURN v_new_balance;
END;
$$;
