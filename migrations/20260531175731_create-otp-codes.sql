-- OTP codes table — accessed only by edge functions via admin API key, no RLS
-- Expiry and used-flag enforced in the verify-otp edge function
CREATE TABLE otp_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       text NOT NULL,
  code        text NOT NULL,
  expires_at  timestamptz NOT NULL DEFAULT now() + interval '5 minutes',
  used        boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX otp_codes_phone_idx      ON otp_codes(phone);
CREATE INDEX otp_codes_expires_at_idx ON otp_codes(expires_at);

-- Clean up OTPs older than 1 hour automatically on each new insert
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM otp_codes WHERE expires_at < now() - interval '1 hour';
  RETURN NEW;
END;
$$;

CREATE TRIGGER otp_codes_cleanup
  AFTER INSERT ON otp_codes
  FOR EACH STATEMENT EXECUTE FUNCTION cleanup_expired_otps();
