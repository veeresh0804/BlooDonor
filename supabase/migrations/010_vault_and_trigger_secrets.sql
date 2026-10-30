-- =============================================================
-- 010_vault_and_trigger_secrets.sql
--
-- handle_new_blood_request() reads SUPABASE_URL and
-- SUPABASE_SERVICE_ROLE_KEY from vault.decrypted_secrets at runtime,
-- but no migration ever enabled the vault extension or created the
-- secrets. On a clean database the trigger throws on EVERY
-- blood_requests insert, so Tier 1/2/3 fan-out never runs.
--
-- This migration enables the extension and checks the secrets,
-- failing loudly (WARNING, not silently) when they are absent.
--
-- One-time setup (Supabase SQL editor, values redacted here):
--   SELECT vault.create_secret('<SUPABASE_URL>', 'SUPABASE_URL',
--     'project URL for edge-function fan-out');
--   SELECT vault.create_secret('<SERVICE_ROLE_KEY>',
--     'SUPABASE_SERVICE_ROLE_KEY', 'service_role for edge fan-out');
-- To rotate: vault.update_secret(...) with the same names.
--
-- NOTE: edge-function secrets (FCM_SERVICE_ACCOUNT_JSON,
-- SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) are set via
-- `supabase secrets set` / dashboard Edge Functions settings,
-- NOT via vault. Deno.env in the functions reads those.
-- =============================================================

CREATE EXTENSION IF NOT EXISTS supabase_vault;

DO $$
DECLARE
  missing TEXT[];
BEGIN
  SELECT array_agg(want.name) INTO missing
  FROM (VALUES ('SUPABASE_URL'), ('SUPABASE_SERVICE_ROLE_KEY')) AS want(name)
  WHERE NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets d WHERE d.name = want.name
  );

  IF missing IS NOT NULL THEN
    RAISE WARNING '010: vault secrets missing: % — create them or the blood-request trigger cannot fan out (see file header).',
      array_to_string(missing, ', ');
  ELSE
    RAISE NOTICE '010: vault secrets present (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY).';
  END IF;
END
$$;
