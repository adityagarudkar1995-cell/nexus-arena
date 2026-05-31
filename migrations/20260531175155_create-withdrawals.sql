-- Max withdrawal: Rs10000/day, KYC must be approved
CREATE TABLE withdrawals (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount            bigint NOT NULL CHECK (amount > 0),   -- paise
  upi_id            text NOT NULL,
  status            withdrawal_status NOT NULL DEFAULT 'pending',
  rejection_reason  text,
  requested_at      timestamptz NOT NULL DEFAULT now(),
  processed_at      timestamptz,
  transaction_id    uuid REFERENCES wallet_transactions(id)
);

ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;

CREATE INDEX withdrawals_user_id_idx     ON withdrawals(user_id);
CREATE INDEX withdrawals_status_idx      ON withdrawals(status);
CREATE INDEX withdrawals_requested_at_idx ON withdrawals(requested_at DESC);

-- Users can read their own withdrawals
CREATE POLICY "withdrawals: own read" ON withdrawals FOR SELECT USING (auth.uid() = user_id);

-- Enforce daily limit (Rs10000 = 1000000 paise) and KYC before inserting a withdrawal request
CREATE OR REPLACE FUNCTION check_withdrawal_limits()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_kyc      kyc_status;
  v_today    bigint;
BEGIN
  -- KYC check
  SELECT kyc_status INTO v_kyc FROM profiles WHERE id = NEW.user_id;
  IF v_kyc != 'approved' THEN
    RAISE EXCEPTION 'kyc_not_approved';
  END IF;

  -- Daily withdrawal total (only completed + pending count toward limit)
  SELECT COALESCE(SUM(amount), 0) INTO v_today
  FROM withdrawals
  WHERE user_id = NEW.user_id
    AND requested_at >= CURRENT_DATE
    AND status NOT IN ('failed', 'rejected');

  IF v_today + NEW.amount > 1000000 THEN
    RAISE EXCEPTION 'daily_limit_exceeded';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER before_withdrawal_insert
  BEFORE INSERT ON withdrawals
  FOR EACH ROW EXECUTE FUNCTION check_withdrawal_limits();
