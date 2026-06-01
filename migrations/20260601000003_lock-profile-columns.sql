-- SECURITY FIX
-- Before this migration, anon/authenticated held UPDATE on ALL profile columns,
-- so a user could PATCH their own row to kyc_status='approved' and bypass the
-- KYC gate enforced by check_withdrawal_limits() — then withdraw real money.
--
-- RLS can't restrict columns, so we use column-level privileges: revoke table-wide
-- UPDATE and grant it back only on the user-editable columns. kyc_status (and
-- id/phone/created_at/updated_at) become writable by project_admin (service role)
-- only. updated_at is maintained by the profiles_updated_at trigger.

REVOKE UPDATE ON public.profiles FROM anon, authenticated;
GRANT UPDATE (display_name, game_uid, upi_id, avatar_url) ON public.profiles TO authenticated;
