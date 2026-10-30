-- =============================================================
-- 009_security_hardening.sql
--
-- Purpose:
--   1. Close the confirm_donation_complete privilege escalation
--      (SECURITY DEFINER + EXECUTE TO PUBLIC, no ownership check).
--   2. Replace over-broad RLS policies (USING (true) on PII tables,
--      "System can manage" FOR ALL policies that apply to anon).
--   3. Enable RLS on ngos, ngo_donors, camps, donor_login_streaks.
--   4. Lock down EXECUTE on all RPC/trigger functions.
--   5. Fix the duplicate points counter (donor_profiles.points vs
--      donor_achievements.points) with a backfill + sync trigger.
--   6. Clamp acos() inputs in the Haversine calculations.
--   7. Fix misleading comments (compatibility matrix + tier numbering).
--
-- Authority note:
--   Numbered migrations (001-009) are authoritative. The
--   supabase/consolidated_migration.sql snapshot is STALE after this
--   file — regenerate it from a migrated database, do not apply both.
--
-- Apply:  supabase db push   (or psql against the project)
-- Safe to re-run: all statements are idempotent (IF EXISTS / OR REPLACE).
-- =============================================================

-- =============================================================
-- SECTION 1: Hardened matching functions
--
-- Changes vs 002:
--   * SECURITY DEFINER + pinned search_path so they keep working
--     after donor_profiles loses its public-read policy (RLS bypass
--     is intentional here; access is gated by the ownership check
--     and EXECUTE grants in Section 8 instead).
--   * Callers must own a hospital profile (service_role and direct
--     SQL without a JWT bypass the check). Previously any client —
--     including anon — could enumerate every donor by passing a
--     huge radius_km. radius_km is now also clamped.
--   * acos() argument clamped to [-1, 1] (float rounding threw
--     "input is out of range" for coincident coordinates).
--   * Header comments corrected: the matrix answers "which DONORS
--     can serve this RECIPIENT" (recipient perspective). The old
--     comments described donor->recipient rules, which was backwards
--     as documentation (the CASE branches themselves were correct).
-- =============================================================

CREATE OR REPLACE FUNCTION public.find_compatible_donors(
  recipient_blood_group blood_group,
  recipient_rh_factor rh_factor,
  hospital_lat DECIMAL,
  hospital_lng DECIMAL,
  radius_km INTEGER DEFAULT 10
)
RETURNS SETOF donor_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recipient_label TEXT;
  compatible_groups TEXT[];
  -- Clamp the search radius so one RPC cannot harvest the whole table.
  effective_radius INTEGER := LEAST(GREATEST(radius_km, 1), 50);
BEGIN
  -- Only hospitals may run donor discovery (anon/jwt-less direct SQL
  -- and service_role are handled by the role check: NULL role means
  -- no JWT is present, e.g. trigger context internals / direct SQL).
  IF auth.role() IN ('anon', 'authenticated')
    AND NOT EXISTS (SELECT 1 FROM public.hospitals WHERE user_id = auth.uid())
  THEN
    RAISE EXCEPTION 'Only hospitals can search for donors';
  END IF;

  -- Build recipient label (e.g. 'O+').
  recipient_label := UPPER(recipient_blood_group::text) ||
    CASE WHEN recipient_rh_factor = 'positive' THEN '+' ELSE '-' END;

  -- Compatible DONOR groups for the given RECIPIENT (recipient view):
  -- O- receives from O- only; AB+ (universal recipient) receives all.
  compatible_groups := CASE recipient_label
    WHEN 'O-'  THEN ARRAY['o-negative']
    WHEN 'O+'  THEN ARRAY['o-negative', 'o-positive']
    WHEN 'A-'  THEN ARRAY['o-negative', 'a-negative']
    WHEN 'A+'  THEN ARRAY['o-negative', 'o-positive', 'a-negative', 'a-positive']
    WHEN 'B-'  THEN ARRAY['o-negative', 'b-negative']
    WHEN 'B+'  THEN ARRAY['o-negative', 'o-positive', 'b-negative', 'b-positive']
    WHEN 'AB-' THEN ARRAY['o-negative', 'a-negative', 'b-negative', 'ab-negative']
    WHEN 'AB+' THEN ARRAY['o-negative', 'o-positive', 'a-negative', 'a-positive', 'b-negative', 'b-positive', 'ab-negative', 'ab-positive']
    ELSE ARRAY[]::TEXT[]
  END;

  RETURN QUERY
  SELECT dp.*
  FROM donor_profiles dp
  WHERE dp.availability = true
    AND dp.dnd_mode = false
    AND dp.cooldown_active = false
    AND dp.lat IS NOT NULL
    AND dp.lng IS NOT NULL
    AND (
      -- Haversine distance in km; LEAST/GREATEST guards acos() domain.
      6371 * acos(
        LEAST(1.0::float8, GREATEST(-1.0::float8,
          cos(radians(hospital_lat))
          * cos(radians(dp.lat::float))
          * cos(radians(dp.lng::float) - radians(hospital_lng))
          + sin(radians(hospital_lat))
          * sin(radians(dp.lat::float))
        ))
      )
    ) <= effective_radius
    AND (dp.blood_group::text || '-' ||
         CASE WHEN dp.rh_factor = 'positive' THEN 'positive' ELSE 'negative' END)
        = ANY(compatible_groups)
  ORDER BY
    6371 * acos(
      LEAST(1.0::float8, GREATEST(-1.0::float8,
        cos(radians(hospital_lat))
        * cos(radians(dp.lat::float))
        * cos(radians(dp.lng::float) - radians(hospital_lng))
        + sin(radians(hospital_lat))
        * sin(radians(dp.lat::float))
      ))
    ) ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.find_cooldown_donors(
  recipient_blood_group blood_group,
  recipient_rh_factor rh_factor,
  hospital_lat DECIMAL,
  hospital_lng DECIMAL,
  radius_km INTEGER DEFAULT 30
)
RETURNS SETOF donor_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recipient_label TEXT;
  compatible_groups TEXT[];
  effective_radius INTEGER := LEAST(GREATEST(radius_km, 1), 100);
BEGIN
  IF auth.role() IN ('anon', 'authenticated')
    AND NOT EXISTS (SELECT 1 FROM public.hospitals WHERE user_id = auth.uid())
  THEN
    RAISE EXCEPTION 'Only hospitals can search for donors';
  END IF;

  recipient_label := UPPER(recipient_blood_group::text) ||
    CASE WHEN recipient_rh_factor = 'positive' THEN '+' ELSE '-' END;

  -- Same recipient-view matrix as find_compatible_donors.
  compatible_groups := CASE recipient_label
    WHEN 'O-'  THEN ARRAY['o-negative']
    WHEN 'O+'  THEN ARRAY['o-negative', 'o-positive']
    WHEN 'A-'  THEN ARRAY['o-negative', 'a-negative']
    WHEN 'A+'  THEN ARRAY['o-negative', 'o-positive', 'a-negative', 'a-positive']
    WHEN 'B-'  THEN ARRAY['o-negative', 'b-negative']
    WHEN 'B+'  THEN ARRAY['o-negative', 'o-positive', 'b-negative', 'b-positive']
    WHEN 'AB-' THEN ARRAY['o-negative', 'a-negative', 'b-negative', 'ab-negative']
    WHEN 'AB+' THEN ARRAY['o-negative', 'o-positive', 'a-negative', 'a-positive', 'b-negative', 'b-positive', 'ab-negative', 'ab-positive']
    ELSE ARRAY[]::TEXT[]
  END;

  RETURN QUERY
  SELECT dp.*
  FROM donor_profiles dp
  WHERE dp.cooldown_active = true
    AND dp.cooldown_end_date IS NOT NULL
    AND dp.lat IS NOT NULL
    AND dp.lng IS NOT NULL
    AND (
      6371 * acos(
        LEAST(1.0::float8, GREATEST(-1.0::float8,
          cos(radians(hospital_lat))
          * cos(radians(dp.lat::float))
          * cos(radians(dp.lng::float) - radians(hospital_lng))
          + sin(radians(hospital_lat))
          * sin(radians(dp.lat::float))
        ))
      )
    ) <= effective_radius
    AND (dp.blood_group::text || '-' ||
         CASE WHEN dp.rh_factor = 'positive' THEN 'positive' ELSE 'negative' END)
        = ANY(compatible_groups)
  ORDER BY dp.cooldown_end_date ASC;
END;
$$;

-- =============================================================
-- SECTION 2: confirm_donation_complete — close priv-esc
--
-- Changes vs 007:
--   * Ownership check: the caller must own the hospital that filed
--     the request (service_role / JWT-less direct SQL bypass).
--   * Input validation on units.
--   * Idempotency guards: request must be active/escalating and the
--     response must not already be 'donated' (prevents double
--     counting units/points/certificates). Rows are locked FOR
--     UPDATE so concurrent calls serialize instead of double-apply.
--   * Points fix: updates BOTH donor_achievements.points (source of
--     truth) AND donor_profiles.points (cached copy read by the UI),
--     keeping the two counters in sync going forward.
-- =============================================================

CREATE OR REPLACE FUNCTION public.confirm_donation_complete(
  p_request_id UUID,
  p_donor_id UUID,
  p_donation_type donation_type,
  p_units_donated INTEGER
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cooldown_days INTEGER;
  v_hospital_id UUID;
  v_request_status request_status;
  v_response_status donor_response_status;
BEGIN
  IF p_request_id IS NULL OR p_donor_id IS NULL THEN
    RAISE EXCEPTION 'request and donor are required';
  END IF;
  IF p_units_donated IS NULL OR p_units_donated < 1 THEN
    RAISE EXCEPTION 'units must be >= 1';
  END IF;

  -- Authorization: only the hospital that owns the request may
  -- confirm (the Flutter app calls this from the hospital side).
  IF auth.role() IN ('anon', 'authenticated')
    AND NOT EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = p_request_id AND h.user_id = auth.uid()
    )
  THEN
    RAISE EXCEPTION 'Only the requesting hospital can confirm a donation';
  END IF;

  v_cooldown_days := CASE p_donation_type
    WHEN 'whole_blood' THEN 90
    WHEN 'platelets' THEN 14
    WHEN 'plasma' THEN 28
    WHEN 'double_red_cells' THEN 180
    ELSE 90
  END;

  SELECT hospital_id INTO v_hospital_id FROM public.blood_requests WHERE id = p_request_id;
  IF v_hospital_id IS NULL THEN
    RAISE EXCEPTION 'blood request not found';
  END IF;

  -- Lock + validate the request: only active/escalating requests
  -- can accept a donation confirmation.
  SELECT status INTO v_request_status
  FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF v_request_status NOT IN ('active', 'escalating') THEN
    RAISE EXCEPTION 'request is not active (status=%)', v_request_status;
  END IF;

  -- Lock + validate the response: must exist and not be donated yet.
  SELECT status INTO v_response_status
  FROM public.donor_responses
  WHERE request_id = p_request_id AND donor_id = p_donor_id FOR UPDATE;
  IF v_response_status IS NULL THEN
    RAISE EXCEPTION 'donor is not matched to this request';
  END IF;
  IF v_response_status = 'donated' THEN
    RAISE EXCEPTION 'donation already recorded for this donor and request';
  END IF;

  -- 1. Mark response donated.
  UPDATE public.donor_responses
  SET status = 'donated', donated_at = NOW()
  WHERE request_id = p_request_id AND donor_id = p_donor_id;

  -- 2. Credit fulfilled units.
  UPDATE public.blood_requests
  SET units_fulfilled = units_fulfilled + p_units_donated
  WHERE id = p_request_id;

  -- 3. Start donor cooldown.
  UPDATE public.donor_profiles
  SET
    last_donation_date = CURRENT_DATE,
    donation_type_last = p_donation_type,
    cooldown_end_date = CURRENT_DATE + v_cooldown_days,
    cooldown_active = true
  WHERE id = p_donor_id;

  -- 4. Mint the certificate row (URL filled in later by edge fn).
  INSERT INTO public.donation_certificates (
    donor_response_id, donor_id, hospital_id, blood_group, donation_type,
    units_donated, hospital_name, city, donated_at, certificate_url
  )
  SELECT
    dr.id, p_donor_id, v_hospital_id, br.blood_group || '-' || br.rh_factor,
    p_donation_type, p_units_donated, h.hospital_name, h.city, CURRENT_DATE, NULL
  FROM donor_responses dr
  JOIN blood_requests br ON dr.request_id = br.id
  JOIN hospitals h ON br.hospital_id = h.id
  WHERE dr.request_id = p_request_id AND dr.donor_id = p_donor_id;

  -- 5. Update achievements (source of truth for points).
  INSERT INTO public.donor_achievements (donor_id, total_donations, lives_saved, points)
  VALUES (p_donor_id, 0, 0, 0)
  ON CONFLICT (donor_id) DO NOTHING;

  UPDATE public.donor_achievements
  SET
    total_donations = total_donations + 1,
    lives_saved = lives_saved + p_units_donated, -- 1 unit = 1 life saved
    points = points + 100, -- 100 points per donation
    updated_at = NOW()
  WHERE donor_id = p_donor_id;

  -- 6. Mirror points into donor_profiles (cached copy read by the UI).
  UPDATE public.donor_profiles dp
  SET points = da.points
  FROM public.donor_achievements da
  WHERE da.donor_id = p_donor_id AND dp.id = p_donor_id;
END;
$$;

-- =============================================================
-- SECTION 3: handle_new_blood_request trigger refresh
--
-- Same fan-out behavior as 005, plus:
--   * pinned search_path (required hygiene for SECURITY DEFINER);
--   * clamped acos() in the distance_km payload;
--   * corrected tier comments (Tier 1 = available, Tier 2 = cooldown
--     override, Tier 3 = community SOS);
--   * skips non-active inserts so cancelled/fulfilled rows created by
--     backfills never page donors.
-- NOTE: the per-donor net.http_post loop still runs inside the
-- INSERT transaction — move to an async queue (pgmq) as follow-up.
-- =============================================================

CREATE OR REPLACE FUNCTION public.handle_new_blood_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  donor_record RECORD;
  request_record RECORD;
  jwt TEXT;
  project_url TEXT;
  service_key TEXT;
  donors_found BOOLEAN := FALSE;
  cooldown_donors_found BOOLEAN := FALSE;
BEGIN
  request_record := NEW;

  -- Only fan out for live requests.
  IF request_record.status IS DISTINCT FROM 'active' THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret INTO project_url FROM vault.decrypted_secrets WHERE name = 'SUPABASE_URL';
  SELECT decrypted_secret INTO service_key FROM vault.decrypted_secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY';

  jwt := 'Bearer ' || service_key;

  -- Tier 1: available, eligible donors.
  FOR donor_record IN
    SELECT * FROM find_compatible_donors(
      request_record.blood_group,
      request_record.rh_factor,
      request_record.lat,
      request_record.lng,
      request_record.current_radius_km
    )
  LOOP
    donors_found := TRUE;
    INSERT INTO public.donor_responses (request_id, donor_id, status)
    VALUES (request_record.id, donor_record.id, 'notified');

    PERFORM net.http_post(
      url := project_url || '/functions/v1/send-emergency-notification',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', jwt),
      body := jsonb_build_object(
        'request_id', request_record.id, 'donor_id', donor_record.id,
        'blood_group', request_record.blood_group::text || CASE WHEN request_record.rh_factor = 'positive' THEN '+' ELSE '-' END,
        'hospital_name', (SELECT hospital_name FROM hospitals WHERE id = request_record.hospital_id),
        'patient_story', request_record.patient_story,
        'distance_km', (6371 * acos(
          LEAST(1.0::float8, GREATEST(-1.0::float8,
            cos(radians(request_record.lat)) * cos(radians(donor_record.lat::float))
            * cos(radians(donor_record.lng::float) - radians(request_record.lng))
            + sin(radians(request_record.lat)) * sin(radians(donor_record.lat::float))
          ))
        ))::int
      )
    );
  END LOOP;

  -- Tier 2: cooldown donors (emergency override, wider radius).
  IF NOT donors_found THEN
    FOR donor_record IN
      SELECT * FROM find_cooldown_donors(
        request_record.blood_group,
        request_record.rh_factor,
        request_record.lat,
        request_record.lng,
        30
      )
    LOOP
      cooldown_donors_found := TRUE;
      INSERT INTO public.donor_responses (request_id, donor_id, status, is_cooldown_override)
      VALUES (request_record.id, donor_record.id, 'notified', true);

      PERFORM net.http_post(
        url := project_url || '/functions/v1/send-override-notification',
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', jwt),
        body := jsonb_build_object(
          'request_id', request_record.id, 'donor_id', donor_record.id,
          'blood_group', request_record.blood_group::text || CASE WHEN request_record.rh_factor = 'positive' THEN '+' ELSE '-' END,
          'hospital_name', (SELECT hospital_name FROM hospitals WHERE id = request_record.hospital_id),
          'patient_story', request_record.patient_story,
          'cooldown_days_remaining', (donor_record.cooldown_end_date - CURRENT_DATE)
        )
      );
    END LOOP;
  END IF;

  -- Tier 3: community SOS broadcast.
  IF NOT donors_found AND NOT cooldown_donors_found THEN
    PERFORM net.http_post(
      url := project_url || '/functions/v1/send-community-sos',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', jwt),
      body := jsonb_build_object(
        'request_id', request_record.id,
        'blood_group', request_record.blood_group::text || CASE WHEN request_record.rh_factor = 'positive' THEN '+' ELSE '-' END
      )
    );
  END IF;

  UPDATE public.blood_requests
  SET donors_notified = (SELECT count(*) FROM donor_responses WHERE request_id = request_record.id)
  WHERE id = request_record.id;

  RETURN NEW;
END;
$$;

-- =============================================================
-- SECTION 4: Today's-heroes RPC (preserves the Heroes Wall)
--
-- DonorAchievementsService.getTodaysHeroes used to scan all of
-- donor_responses + embed blood_requests, which stops working once
-- base-table reads are restricted (Section 6). This definer returns
-- only the leaderboard columns, granted to authenticated users.
-- App change: call rpc('get_todays_heroes') instead of the raw scan.
-- =============================================================

CREATE OR REPLACE FUNCTION public.get_todays_heroes(p_limit INTEGER DEFAULT 20)
RETURNS TABLE (
  donor_id UUID,
  blood_group TEXT,
  rh_factor TEXT,
  donated_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT dr.donor_id,
         br.blood_group::text,
         br.rh_factor::text,
         dr.donated_at
  FROM public.donor_responses dr
  JOIN public.blood_requests br ON br.id = dr.request_id
  WHERE dr.status = 'donated'
    AND dr.donated_at >= date_trunc('day', now())
  ORDER BY dr.donated_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 50);
$$;

-- =============================================================
-- SECTION 5: Points sync — backfill + trigger
--
-- donor_achievements.points is the source of truth;
-- donor_profiles.points is the cached copy rendered by DonorHome.
-- (Companion app fix: DonorService.saveDonorProfile must stop
-- upserting 'points': 0, which reset the cached copy on every save.)
-- =============================================================

-- One-time backfill: achievements -> profiles.
UPDATE public.donor_profiles dp
SET points = da.points
FROM public.donor_achievements da
WHERE da.donor_id = dp.id
  AND dp.points IS DISTINCT FROM da.points;

-- Ongoing sync: mirror every achievements.points write into profiles.
CREATE OR REPLACE FUNCTION public.sync_donor_profile_points()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.donor_profiles
  SET points = NEW.points
  WHERE id = NEW.donor_id
    AND points IS DISTINCT FROM NEW.points;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_donor_profile_points ON public.donor_achievements;
CREATE TRIGGER trg_sync_donor_profile_points
AFTER INSERT OR UPDATE OF points ON public.donor_achievements
FOR EACH ROW EXECUTE FUNCTION public.sync_donor_profile_points();

-- =============================================================
-- SECTION 6: RLS — enable on the four missing tables
-- =============================================================

ALTER TABLE public.ngos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ngo_donors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.camps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donor_login_streaks ENABLE ROW LEVEL SECURITY;

-- =============================================================
-- SECTION 7: RLS — replace over-broad policies
--
-- Principles applied:
--   * Directory-style reads (hospitals, ngos, camps) stay readable
--     but move from PUBLIC to authenticated (blocks anon scraping).
--   * donor_profiles loses global read: own row + hospitals reading
--     donors matched to their requests only. Matching still works
--     because the RPCs in Section 1 are SECURITY DEFINER.
--   * blood_requests loses global read (patient_story is health
--     data): owning hospital + matched donors only.
--   * "System can manage" FOR ALL USING (true) policies are dropped:
--     with no write policy left, writes are denied to anon/
--     authenticated and only possible via SECURITY DEFINER
--     functions or service_role (which bypasses RLS).
--   * UPDATE policies gain WITH CHECK so rows cannot be moved to
--     another user's ownership.
-- =============================================================

-- ---- users: add WITH CHECK to update (insert/select unchanged) ----
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ---- hospitals: directory read stays, but authenticated-only ----
DROP POLICY IF EXISTS "Anyone can read hospitals" ON public.hospitals;
DROP POLICY IF EXISTS "Users can insert own hospital" ON public.hospitals;
DROP POLICY IF EXISTS "Users can update own hospital" ON public.hospitals;

CREATE POLICY "Authenticated can read hospitals" ON public.hospitals
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert own hospital" ON public.hospitals
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own hospital" ON public.hospitals
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---- donor_profiles: drop global read (PII: emergency contacts + exact geo) ----
DROP POLICY IF EXISTS "Anyone can read donor profiles" ON public.donor_profiles;
DROP POLICY IF EXISTS "Users can insert own donor profile" ON public.donor_profiles;
DROP POLICY IF EXISTS "Users can update own donor profile" ON public.donor_profiles;

CREATE POLICY "Donors can read own profile" ON public.donor_profiles
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
-- Hospitals see only donors with a response on one of their requests
-- (covers RequestLiveTracker which embeds donor_profiles(*)).
CREATE POLICY "Hospitals can read responding donors" ON public.donor_profiles
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.donor_responses dr
      JOIN public.blood_requests br ON br.id = dr.request_id
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE dr.donor_id = donor_profiles.id AND h.user_id = auth.uid()
    )
  );
CREATE POLICY "Users can insert own donor profile" ON public.donor_profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own donor profile" ON public.donor_profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---- blood_requests: drop global read (patient_story is health data) ----
DROP POLICY IF EXISTS "Anyone can read blood requests" ON public.blood_requests;
DROP POLICY IF EXISTS "Hospitals can insert own requests" ON public.blood_requests;
DROP POLICY IF EXISTS "Hospitals can update own requests" ON public.blood_requests;

CREATE POLICY "Hospitals can read own requests" ON public.blood_requests
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.hospitals h
            WHERE h.id = blood_requests.hospital_id AND h.user_id = auth.uid())
  );
-- Matched donors can read the requests they were notified for
-- (covers MatchingService.getBloodRequestById + donation history embeds).
CREATE POLICY "Donors can read matched requests" ON public.blood_requests
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.donor_responses dr
      JOIN public.donor_profiles dp ON dp.id = dr.donor_id
      WHERE dr.request_id = blood_requests.id AND dp.user_id = auth.uid()
    )
  );
CREATE POLICY "Hospitals can insert own requests" ON public.blood_requests
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.hospitals WHERE id = hospital_id AND user_id = auth.uid())
  );
CREATE POLICY "Hospitals can update own requests" ON public.blood_requests
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.hospitals WHERE id = hospital_id AND user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.hospitals WHERE id = hospital_id AND user_id = auth.uid())
  );

-- ---- donor_responses: tighten insert/update with role + WITH CHECK ----
DROP POLICY IF EXISTS "Donors can insert own responses" ON public.donor_responses;
DROP POLICY IF EXISTS "Donors can update own responses" ON public.donor_responses;

CREATE POLICY "Donors can insert own responses" ON public.donor_responses
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.donor_profiles WHERE id = donor_id AND user_id = auth.uid())
  );
CREATE POLICY "Donors can update own responses" ON public.donor_responses
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.donor_profiles WHERE id = donor_id AND user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.donor_profiles WHERE id = donor_id AND user_id = auth.uid())
  );
-- (Select policy from 003 is already least-privilege: own donors +
--  owning hospitals. Left untouched. No DELETE policy: responses are
--  append-only history.)

-- ---- donor_achievements: drop open "System can manage" ----
DROP POLICY IF EXISTS "Anyone can read achievements" ON public.donor_achievements;
DROP POLICY IF EXISTS "System can manage achievements" ON public.donor_achievements;

CREATE POLICY "Authenticated can read achievements" ON public.donor_achievements
  FOR SELECT TO authenticated USING (true);
-- No INSERT/UPDATE/DELETE policies: writes only via
-- confirm_donation_complete (definer) or service_role.

-- ---- donation_certificates: drop open policies, scope reads ----
DROP POLICY IF EXISTS "Anyone can read certificates" ON public.donation_certificates;
DROP POLICY IF EXISTS "System can manage certificates" ON public.donation_certificates;

CREATE POLICY "Donors can read own certificates" ON public.donation_certificates
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.donor_profiles dp
            WHERE dp.id = donation_certificates.donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Hospitals can read own certificates" ON public.donation_certificates
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.hospitals h
            WHERE h.id = donation_certificates.hospital_id AND h.user_id = auth.uid())
  );
-- No write policies: certificates are minted by
-- confirm_donation_complete / generate-certificate (service_role).

-- ---- donor_ratings: scope reads + ownership-checked insert ----
DROP POLICY IF EXISTS "Anyone can read ratings" ON public.donor_ratings;
DROP POLICY IF EXISTS "Hospitals can insert ratings" ON public.donor_ratings;

CREATE POLICY "Donors can read own ratings" ON public.donor_ratings
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.donor_profiles dp
            WHERE dp.id = donor_ratings.donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Hospitals can read ratings for own requests" ON public.donor_ratings
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = donor_ratings.request_id AND h.user_id = auth.uid()
    )
  );
CREATE POLICY "Hospitals can rate donors for own requests" ON public.donor_ratings
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = donor_ratings.request_id AND h.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.donor_responses dr
      WHERE dr.request_id = donor_ratings.request_id
        AND dr.donor_id = donor_ratings.donor_id
    )
  );
-- No UPDATE/DELETE: ratings are immutable.

-- ---- leads: drop open policies (referred PII), scope everything ----
DROP POLICY IF EXISTS "Anyone can read leads" ON public.leads;
DROP POLICY IF EXISTS "Donors can insert leads" ON public.leads;
DROP POLICY IF EXISTS "Hospitals can update leads" ON public.leads;

CREATE POLICY "Donors can insert own referrals" ON public.leads
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.donor_profiles dp
            WHERE dp.id = leads.referred_by_donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Donors can read own referrals" ON public.leads
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.donor_profiles dp
            WHERE dp.id = leads.referred_by_donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Hospitals can read leads for own requests" ON public.leads
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = leads.request_id AND h.user_id = auth.uid()
    )
  );
CREATE POLICY "Hospitals can manage leads for own requests" ON public.leads
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = leads.request_id AND h.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = leads.request_id AND h.user_id = auth.uid()
    )
  );
CREATE POLICY "Hospitals can delete leads for own requests" ON public.leads
  FOR DELETE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.blood_requests br
      JOIN public.hospitals h ON h.id = br.hospital_id
      WHERE br.id = leads.request_id AND h.user_id = auth.uid()
    )
  );

-- ---- request_analytics: drop open policies, owner-only read ----
DROP POLICY IF EXISTS "Anyone can read analytics" ON public.request_analytics;
DROP POLICY IF EXISTS "System can manage analytics" ON public.request_analytics;

CREATE POLICY "Hospitals can read own analytics" ON public.request_analytics
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.hospitals h
            WHERE h.id = request_analytics.hospital_id AND h.user_id = auth.uid())
  );
-- No write policies: analytics written by service_role jobs only.

-- ---- ngos: directory read (authenticated) + own writes ----
DROP POLICY IF EXISTS "Authenticated can read ngos" ON public.ngos;
DROP POLICY IF EXISTS "Users can insert own ngo" ON public.ngos;
DROP POLICY IF EXISTS "Users can update own ngo" ON public.ngos;

CREATE POLICY "Authenticated can read ngos" ON public.ngos
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert own ngo" ON public.ngos
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own ngo" ON public.ngos
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---- ngo_donors: visible only to the linked NGO or donor ----
DROP POLICY IF EXISTS "Members can read ngo links" ON public.ngo_donors;
DROP POLICY IF EXISTS "Members can manage ngo links" ON public.ngo_donors;
DROP POLICY IF EXISTS "Members can delete ngo links" ON public.ngo_donors;

CREATE POLICY "Members can read ngo links" ON public.ngo_donors
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = ngo_donors.ngo_id AND n.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.donor_profiles dp
               WHERE dp.id = ngo_donors.donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Members can manage ngo links" ON public.ngo_donors
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = ngo_donors.ngo_id AND n.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.donor_profiles dp
               WHERE dp.id = ngo_donors.donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Members can delete ngo links" ON public.ngo_donors
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = ngo_donors.ngo_id AND n.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.donor_profiles dp
               WHERE dp.id = ngo_donors.donor_id AND dp.user_id = auth.uid())
  );

-- ---- camps: public-to-app events, writes by owning NGO ----
DROP POLICY IF EXISTS "Authenticated can read camps" ON public.camps;
DROP POLICY IF EXISTS "Ngos can insert own camps" ON public.camps;
DROP POLICY IF EXISTS "Ngos can manage own camps" ON public.camps;
DROP POLICY IF EXISTS "Ngos can delete own camps" ON public.camps;

CREATE POLICY "Authenticated can read camps" ON public.camps
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Ngos can insert own camps" ON public.camps
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = camps.ngo_id AND n.user_id = auth.uid())
  );
CREATE POLICY "Ngos can manage own camps" ON public.camps
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = camps.ngo_id AND n.user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = camps.ngo_id AND n.user_id = auth.uid())
  );
CREATE POLICY "Ngos can delete own camps" ON public.camps
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM public.ngos n
            WHERE n.id = camps.ngo_id AND n.user_id = auth.uid())
  );

-- ---- donor_login_streaks: strictly own donor ----
DROP POLICY IF EXISTS "Donors can read own streaks" ON public.donor_login_streaks;
DROP POLICY IF EXISTS "Donors can manage own streaks" ON public.donor_login_streaks;

CREATE POLICY "Donors can read own streaks" ON public.donor_login_streaks
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.donor_profiles dp
            WHERE dp.id = donor_login_streaks.donor_id AND dp.user_id = auth.uid())
  );
CREATE POLICY "Donors can manage own streaks" ON public.donor_login_streaks
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.donor_profiles dp
            WHERE dp.id = donor_login_streaks.donor_id AND dp.user_id = auth.uid())
  );
-- Streak updates go through the same INSERT policy path (upsert by the
-- app uses onConflict on donor_id); no separate UPDATE policy keeps
-- the table append-shaped. Tighten later if direct updates are needed.

-- =============================================================
-- SECTION 8: Function EXECUTE grants
--
-- Default EXECUTE TO PUBLIC is revoked everywhere; only the roles
-- that need each function keep it. Owners always retain access, so
-- triggers and internal calls are unaffected.
-- =============================================================

REVOKE ALL ON FUNCTION public.find_compatible_donors(public.blood_group, public.rh_factor, numeric, numeric, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_compatible_donors(public.blood_group, public.rh_factor, numeric, numeric, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.find_cooldown_donors(public.blood_group, public.rh_factor, numeric, numeric, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_cooldown_donors(public.blood_group, public.rh_factor, numeric, numeric, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.confirm_donation_complete(uuid, uuid, public.donation_type, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_donation_complete(uuid, uuid, public.donation_type, integer) TO authenticated, service_role;

-- Trigger-only: no client role may execute directly.
REVOKE ALL ON FUNCTION public.handle_new_blood_request() FROM PUBLIC;

REVOKE ALL ON FUNCTION public.get_todays_heroes(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_todays_heroes(integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.sync_donor_profile_points() FROM PUBLIC;

-- =============================================================
-- SECTION 9: One profile per user (makes app upserts safe)
--
-- DonorService/HospitalService upsert by user_id; without a unique
-- constraint those upserts silently create duplicates. Add the
-- constraints, but refuse to guess if duplicates already exist.
-- =============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'donor_profiles_user_id_key') THEN
    IF EXISTS (SELECT user_id FROM public.donor_profiles GROUP BY user_id HAVING COUNT(*) > 1) THEN
      RAISE NOTICE '009: skipping UNIQUE on donor_profiles.user_id — duplicate profiles exist; dedupe, then re-run the ALTER.';
    ELSE
      ALTER TABLE public.donor_profiles ADD CONSTRAINT donor_profiles_user_id_key UNIQUE (user_id);
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hospitals_user_id_key') THEN
    IF EXISTS (SELECT user_id FROM public.hospitals GROUP BY user_id HAVING COUNT(*) > 1) THEN
      RAISE NOTICE '009: skipping UNIQUE on hospitals.user_id — duplicate profiles exist; dedupe, then re-run the ALTER.';
    ELSE
      ALTER TABLE public.hospitals ADD CONSTRAINT hospitals_user_id_key UNIQUE (user_id);
    END IF;
  END IF;
END
$$;

-- =============================================================
-- SECTION 10: Post-apply verification (read-only NOTICEs)
-- =============================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  -- Any remaining wide-open write policies on sensitive tables?
  FOR r IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('donor_achievements', 'donation_certificates',
                        'request_analytics', 'leads', 'donor_ratings',
                        'donor_profiles', 'blood_requests')
      AND (cmd = 'ALL' OR with_check = 'true')
      AND (qual = 'true' OR with_check = 'true')
      AND policyname LIKE '%System can manage%'
  LOOP
    RAISE NOTICE '009 WARNING: open policy still present: %.%', r.tablename, r.policyname;
  END LOOP;

  -- RLS enabled everywhere it should be?
  FOR r IN
    SELECT c.relname AS t
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN ('users', 'hospitals', 'donor_profiles', 'ngos',
                        'blood_requests', 'donor_responses', 'donor_achievements',
                        'donation_certificates', 'donor_ratings', 'ngo_donors',
                        'camps', 'leads', 'request_analytics', 'donor_login_streaks')
      AND NOT c.relrowsecurity
  LOOP
    RAISE NOTICE '009 WARNING: RLS not enabled on %', r.t;
  END LOOP;

  RAISE NOTICE '009 security hardening applied.';
END
$$;
