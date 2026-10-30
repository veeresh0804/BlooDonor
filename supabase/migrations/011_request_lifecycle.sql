-- Request lifecycle: auto-fulfil, resolved push, one hospital row per user.
-- Deliberately does NOT redefine confirm_donation_complete or any function from
-- earlier migrations, so it is safe to apply on top of a hardened 009.

-- 1) Auto-fulfil -----------------------------------------------------------
-- confirm_donation_complete bumps units_fulfilled but never changed status.
-- Do it in a BEFORE UPDATE trigger so it works for any writer.
CREATE OR REPLACE FUNCTION public.blood_request_auto_fulfill()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status IN ('active', 'escalating')
     AND NEW.units > 0
     AND COALESCE(NEW.units_fulfilled, 0) >= NEW.units THEN
    NEW.status := 'fulfilled';
  END IF;

  IF NEW.status = 'fulfilled' AND NEW.fulfilled_at IS NULL THEN
    NEW.fulfilled_at := NOW();
  END IF;

  IF NEW.status = 'cancelled' AND NEW.cancelled_at IS NULL THEN
    NEW.cancelled_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS blood_request_auto_fulfill_trigger ON public.blood_requests;
CREATE TRIGGER blood_request_auto_fulfill_trigger
BEFORE UPDATE ON public.blood_requests
FOR EACH ROW
EXECUTE FUNCTION public.blood_request_auto_fulfill();

-- 2) Resolved push ---------------------------------------------------------
-- When a request becomes fulfilled/cancelled, tell donors who are still
-- in flight. Failures here must NEVER roll back the status change.
CREATE OR REPLACE FUNCTION public.notify_request_resolved()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  project_url TEXT;
  service_key TEXT;
BEGIN
  BEGIN
    SELECT decrypted_secret INTO project_url
      FROM vault.decrypted_secrets WHERE name = 'SUPABASE_URL';
    SELECT decrypted_secret INTO service_key
      FROM vault.decrypted_secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY';

    IF project_url IS NULL OR service_key IS NULL THEN
      RAISE WARNING 'notify_request_resolved: vault secrets missing, skipping push';
      RETURN NEW;
    END IF;

    PERFORM net.http_post(
      url := project_url || '/functions/v1/send-resolved-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := jsonb_build_object('request_id', NEW.id, 'status', NEW.status::text)
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'notify_request_resolved failed: %', SQLERRM;
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_request_resolved_trigger ON public.blood_requests;
CREATE TRIGGER notify_request_resolved_trigger
AFTER UPDATE ON public.blood_requests
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status
      AND NEW.status IN ('fulfilled', 'cancelled'))
EXECUTE FUNCTION public.notify_request_resolved();

-- Trigger functions are not meant to be called directly.
REVOKE EXECUTE ON FUNCTION public.notify_request_resolved() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.blood_request_auto_fulfill() FROM PUBLIC;

-- 3) One hospital row per user --------------------------------------------
-- saveHospitalProfile used upsert() with no conflict target, so every save
-- inserted a NEW row and getHospitalProfile's maybeSingle() then failed.
-- Existing duplicates are NOT deleted here (blood_requests reference them):
-- if any exist, this raises a notice and skips; resolve them by hand, then re-run.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.hospitals
    WHERE user_id IS NOT NULL
    GROUP BY user_id HAVING count(*) > 1
  ) THEN
    RAISE NOTICE 'hospitals has duplicate user_id rows; UNIQUE(user_id) NOT added. Merge duplicates, then re-run this statement.';
  ELSIF NOT EXISTS (
    -- Skip if 009 (or anything else) already made user_id unique, under any name.
    SELECT 1
    FROM pg_index i
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
    WHERE i.indrelid = 'public.hospitals'::regclass
      AND i.indisunique
      AND i.indnatts = 1
      AND a.attname = 'user_id'
  ) THEN
    ALTER TABLE public.hospitals ADD CONSTRAINT hospitals_user_id_key UNIQUE (user_id);
  END IF;
END $$;
