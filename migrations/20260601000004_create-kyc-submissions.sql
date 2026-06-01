-- KYC document submissions. Holds storage object keys for the uploaded docs plus
-- the review workflow. profiles.kyc_status remains the gate the withdrawal trigger
-- reads; this table is the audit/review record. Writes happen only via the
-- service-role submit-kyc function (and admin review in Phase 10).

CREATE TABLE IF NOT EXISTS public.kyc_submissions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL,
  aadhaar_front    text NOT NULL,   -- storage object key in kyc-documents bucket
  aadhaar_back     text NOT NULL,
  pan_card         text NOT NULL,
  selfie           text NOT NULL,
  status           kyc_status NOT NULL DEFAULT 'submitted',
  rejection_reason text,
  submitted_at     timestamptz NOT NULL DEFAULT now(),
  reviewed_at      timestamptz
);

CREATE INDEX IF NOT EXISTS kyc_submissions_user_idx
  ON public.kyc_submissions (user_id, submitted_at DESC);

ALTER TABLE public.kyc_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kyc: own read" ON public.kyc_submissions;
CREATE POLICY "kyc: own read"
  ON public.kyc_submissions
  FOR SELECT
  USING (auth.uid() = user_id);
