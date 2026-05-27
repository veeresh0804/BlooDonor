-- =============================================
-- STEP 1: Extensions
-- =============================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- =============================================
-- STEP 2: ENUM types
-- =============================================
CREATE TYPE user_role AS ENUM ('hospital', 'donor', 'ngo');
CREATE TYPE blood_group AS ENUM ('a', 'b', 'ab', 'o');
CREATE TYPE rh_factor AS ENUM ('positive', 'negative');
CREATE TYPE urgency_level AS ENUM ('critical', 'urgent', 'normal');
CREATE TYPE request_status AS ENUM ('active', 'fulfilled', 'cancelled', 'escalating');
CREATE TYPE donor_response_status AS ENUM (
  'notified', 'accepted', 'on_the_way', 'delayed', 'arrived',
  'confirmed', 'donated', 'stepped_back', 'accident', 'missed', 'cooldown_override'
);
CREATE TYPE donation_type AS ENUM ('whole_blood', 'platelets', 'plasma', 'double_red_cells');
CREATE TYPE lead_status AS ENUM ('pending', 'contacted', 'donated', 'not_available');

-- =============================================
-- STEP 3: Core tables (no FK deps)
-- =============================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  email TEXT,
  role user_role NOT NULL,
  fcm_token TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE hospitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  hospital_name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT DEFAULT 'Hyderabad',
  lat DECIMAL,
  lng DECIMAL,
  verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE donor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  blood_group blood_group NOT NULL,
  rh_factor rh_factor NOT NULL,
  city TEXT DEFAULT 'Hyderabad',
  lat DECIMAL,
  lng DECIMAL,
  radius_km INTEGER DEFAULT 10,
  availability BOOLEAN DEFAULT true,
  dnd_mode BOOLEAN DEFAULT false,
  last_donation_date DATE,
  donation_type_last donation_type,
  cooldown_end_date DATE,
  cooldown_active BOOLEAN DEFAULT false,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  points INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE ngos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ngo_name TEXT NOT NULL,
  registration_no TEXT,
  city TEXT DEFAULT 'Hyderabad',
  lat DECIMAL,
  lng DECIMAL,
  verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- STEP 4: Tables with FK deps on above
-- =============================================
CREATE TABLE blood_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID REFERENCES hospitals(id) ON DELETE CASCADE,
  blood_group blood_group NOT NULL,
  rh_factor rh_factor NOT NULL,
  units INTEGER NOT NULL DEFAULT 1,
  units_fulfilled INTEGER DEFAULT 0,
  urgency urgency_level NOT NULL DEFAULT 'urgent',
  status request_status DEFAULT 'active',
  city TEXT DEFAULT 'Hyderabad',
  lat DECIMAL,
  lng DECIMAL,
  patient_story TEXT,
  description TEXT,
  cancel_reason TEXT,
  current_radius_km INTEGER DEFAULT 10,
  donors_notified INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  fulfilled_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE donor_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES blood_requests(id) ON DELETE CASCADE,
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  status donor_response_status NOT NULL DEFAULT 'notified',
  is_cooldown_override BOOLEAN DEFAULT false,
  cooldown_days_remaining INTEGER,
  health_check_passed BOOLEAN,
  family_notified BOOLEAN DEFAULT false,
  accepted_at TIMESTAMP WITH TIME ZONE,
  arrived_at TIMESTAMP WITH TIME ZONE,
  donated_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE donor_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  total_donations INTEGER DEFAULT 0,
  lives_saved INTEGER DEFAULT 0,
  badges TEXT[] DEFAULT '{}',
  points INTEGER DEFAULT 0,
  first_responder BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT donor_achievements_donor_id_key UNIQUE (donor_id)  -- included here, not as ALTER
);

CREATE TABLE donation_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_response_id UUID REFERENCES donor_responses(id),
  donor_id UUID REFERENCES donor_profiles(id),
  hospital_id UUID REFERENCES hospitals(id),
  blood_group TEXT,
  donation_type donation_type,
  units_donated INTEGER,
  hospital_name TEXT,
  city TEXT,
  donated_at DATE,
  certificate_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE donor_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_response_id UUID REFERENCES donor_responses(id),
  request_id UUID REFERENCES blood_requests(id),
  hospital_id UUID REFERENCES hospitals(id),
  donor_id UUID REFERENCES donor_profiles(id),
  punctual BOOLEAN,
  professional BOOLEAN,
  helpful BOOLEAN,
  rating_score INTEGER CHECK (rating_score >= 1 AND rating_score <= 5),
  stars INTEGER CHECK (stars >= 1 AND stars <= 5),
  tags TEXT[],
  comment TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE ngo_donors (
  ngo_id UUID REFERENCES ngos(id) ON DELETE CASCADE,
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  is_trained_verified BOOLEAN DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (ngo_id, donor_id)
);

CREATE TABLE camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ngo_id UUID REFERENCES ngos(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  city TEXT DEFAULT 'Hyderabad',
  lat DECIMAL,
  lng DECIMAL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES blood_requests(id),
  referred_by_donor_id UUID REFERENCES donor_profiles(id),
  referred_name TEXT,
  referred_phone TEXT,
  blood_group TEXT,
  status lead_status DEFAULT 'pending',
  hospital_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE request_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID REFERENCES hospitals(id),
  request_id UUID REFERENCES blood_requests(id),
  blood_group TEXT,
  urgency TEXT,
  donors_notified INTEGER,
  donors_responded INTEGER,
  response_time_minutes INTEGER,
  fulfilled BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE donor_login_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  last_login_date DATE,
  current_streak INTEGER DEFAULT 0,
  points_earned_today BOOLEAN DEFAULT false
);

-- =============================================
-- STEP 5: Indexes
-- =============================================
CREATE INDEX idx_donor_profiles_blood_group ON donor_profiles(blood_group, rh_factor);
CREATE INDEX idx_donor_profiles_availability ON donor_profiles(availability, dnd_mode, cooldown_active);
CREATE INDEX idx_blood_requests_status ON blood_requests(status);
CREATE INDEX idx_blood_requests_hospital ON blood_requests(hospital_id);
CREATE INDEX idx_donor_responses_request ON donor_responses(request_id);
CREATE INDEX idx_donor_responses_donor ON donor_responses(donor_id);

-- =============================================
-- STEP 6: RLS enable
-- =============================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE blood_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE donation_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_analytics ENABLE ROW LEVEL SECURITY;

-- =============================================
-- STEP 7: RLS Policies
-- =============================================
CREATE POLICY "Users can read own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Anyone can read hospitals" ON hospitals FOR SELECT USING (true);
CREATE POLICY "Users can insert own hospital" ON hospitals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own hospital" ON hospitals FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read donor profiles" ON donor_profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert own donor profile" ON donor_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own donor profile" ON donor_profiles FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read blood requests" ON blood_requests FOR SELECT USING (true);
CREATE POLICY "Hospitals can insert own requests" ON blood_requests FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM hospitals WHERE id = hospital_id AND user_id = auth.uid())
);
CREATE POLICY "Hospitals can update own requests" ON blood_requests FOR UPDATE USING (
  EXISTS (SELECT 1 FROM hospitals WHERE id = hospital_id AND user_id = auth.uid())
);

CREATE POLICY "Donors can read own responses" ON donor_responses FOR SELECT USING (
  EXISTS (SELECT 1 FROM donor_profiles WHERE id = donor_id AND user_id = auth.uid())
  OR EXISTS (
    SELECT 1 FROM blood_requests br
    JOIN hospitals h ON h.id = br.hospital_id
    WHERE br.id = request_id AND h.user_id = auth.uid()
  )
);
CREATE POLICY "Donors can insert own responses" ON donor_responses FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM donor_profiles WHERE id = donor_id AND user_id = auth.uid())
);
CREATE POLICY "Donors can update own responses" ON donor_responses FOR UPDATE USING (
  EXISTS (SELECT 1 FROM donor_profiles WHERE id = donor_id AND user_id = auth.uid())
);

CREATE POLICY "Anyone can read achievements" ON donor_achievements FOR SELECT USING (true);
CREATE POLICY "System can manage achievements" ON donor_achievements FOR ALL USING (true);

CREATE POLICY "Anyone can read certificates" ON donation_certificates FOR SELECT USING (true);
CREATE POLICY "System can manage certificates" ON donation_certificates FOR ALL USING (true);

CREATE POLICY "Anyone can read ratings" ON donor_ratings FOR SELECT USING (true);
CREATE POLICY "Hospitals can insert ratings" ON donor_ratings FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can read leads" ON leads FOR SELECT USING (true);
CREATE POLICY "Donors can insert leads" ON leads FOR INSERT WITH CHECK (true);
CREATE POLICY "Hospitals can update leads" ON leads FOR UPDATE USING (true);

CREATE POLICY "Anyone can read analytics" ON request_analytics FOR SELECT USING (true);
CREATE POLICY "System can manage analytics" ON request_analytics FOR ALL USING (true);

-- =============================================
-- STEP 8: Functions (before trigger)
-- =============================================
CREATE OR REPLACE FUNCTION find_compatible_donors(
  recipient_blood_group blood_group,
  recipient_rh_factor rh_factor,
  hospital_lat DECIMAL,
  hospital_lng DECIMAL,
  radius_km INTEGER DEFAULT 10
)
RETURNS SETOF donor_profiles
LANGUAGE plpgsql
AS $$
DECLARE
  recipient_label TEXT;
  compatible_groups TEXT[];
BEGIN
  recipient_label := UPPER(recipient_blood_group::text) ||
    CASE WHEN recipient_rh_factor = 'positive' THEN '+' ELSE '-' END;

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
      6371 * acos(
        cos(radians(hospital_lat)) * cos(radians(dp.lat::float))
        * cos(radians(dp.lng::float) - radians(hospital_lng))
        + sin(radians(hospital_lat)) * sin(radians(dp.lat::float))
      )
    ) <= radius_km
    AND (dp.blood_group::text || '-' ||
         CASE WHEN dp.rh_factor = 'positive' THEN 'positive' ELSE 'negative' END)
        = ANY(compatible_groups)
  ORDER BY
    6371 * acos(
      cos(radians(hospital_lat)) * cos(radians(dp.lat::float))
      * cos(radians(dp.lng::float) - radians(hospital_lng))
      + sin(radians(hospital_lat)) * sin(radians(dp.lat::float))
    ) ASC;
END;
$$;

CREATE OR REPLACE FUNCTION find_cooldown_donors(
  recipient_blood_group blood_group,
  recipient_rh_factor rh_factor,
  hospital_lat DECIMAL,
  hospital_lng DECIMAL,
  radius_km INTEGER DEFAULT 30
)
RETURNS SETOF donor_profiles
LANGUAGE plpgsql
AS $$
DECLARE
  recipient_label TEXT;
  compatible_groups TEXT[];
BEGIN
  recipient_label := UPPER(recipient_blood_group::text) ||
    CASE WHEN recipient_rh_factor = 'positive' THEN '+' ELSE '-' END;

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
        cos(radians(hospital_lat)) * cos(radians(dp.lat::float))
        * cos(radians(dp.lng::float) - radians(hospital_lng))
        + sin(radians(hospital_lat)) * sin(radians(dp.lat::float))
      )
    ) <= radius_km
    AND (dp.blood_group::text || '-' ||
         CASE WHEN dp.rh_factor = 'positive' THEN 'positive' ELSE 'negative' END)
        = ANY(compatible_groups)
  ORDER BY dp.cooldown_end_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION confirm_donation_complete(
  p_request_id UUID,
  p_donor_id UUID,
  p_donation_type donation_type,
  p_units_donated INTEGER
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cooldown_days INTEGER;
  v_donor_user_id UUID;
  v_hospital_id UUID;
BEGIN
  v_cooldown_days := CASE p_donation_type
    WHEN 'whole_blood'     THEN 90
    WHEN 'platelets'       THEN 14
    WHEN 'plasma'          THEN 28
    WHEN 'double_red_cells' THEN 180
    ELSE 90
  END;

  SELECT user_id INTO v_donor_user_id FROM donor_profiles WHERE id = p_donor_id;
  SELECT hospital_id INTO v_hospital_id FROM blood_requests WHERE id = p_request_id;

  UPDATE public.donor_responses
  SET status = 'donated', donated_at = NOW()
  WHERE request_id = p_request_id AND donor_id = p_donor_id;

  UPDATE public.blood_requests
  SET units_fulfilled = units_fulfilled + p_units_donated
  WHERE id = p_request_id;

  UPDATE public.donor_profiles
  SET
    last_donation_date = CURRENT_DATE,
    donation_type_last = p_donation_type,
    cooldown_end_date  = CURRENT_DATE + v_cooldown_days,
    cooldown_active    = true
  WHERE id = p_donor_id;

  INSERT INTO public.donation_certificates (
    donor_response_id, donor_id, hospital_id, blood_group, donation_type,
    units_donated, hospital_name, city, donated_at, certificate_url
  )
  SELECT
    dr.id, p_donor_id, v_hospital_id,
    br.blood_group || '-' || br.rh_factor,
    p_donation_type, p_units_donated, h.hospital_name, h.city, CURRENT_DATE, NULL
  FROM donor_responses dr
  JOIN blood_requests br ON dr.request_id = br.id
  JOIN hospitals h ON br.hospital_id = h.id
  WHERE dr.request_id = p_request_id AND dr.donor_id = p_donor_id;

  INSERT INTO public.donor_achievements (donor_id, total_donations, lives_saved, points)
  VALUES (p_donor_id, 0, 0, 0)
  ON CONFLICT (donor_id) DO NOTHING;

  UPDATE public.donor_achievements
  SET
    total_donations = total_donations + 1,
    lives_saved     = lives_saved + p_units_donated,
    points          = points + 100,
    updated_at      = NOW()
  WHERE donor_id = p_donor_id;
END;
$$;

CREATE OR REPLACE FUNCTION handle_new_blood_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  donor_record          RECORD;
  request_record        RECORD;
  jwt                   TEXT;
  project_url           TEXT;
  service_key           TEXT;
  donors_found          BOOLEAN := FALSE;
  cooldown_donors_found BOOLEAN := FALSE;
BEGIN
  request_record := NEW;

  SELECT decrypted_secret INTO project_url FROM vault.decrypted_secrets WHERE name = 'SUPABASE_URL';
  SELECT decrypted_secret INTO service_key FROM vault.decrypted_secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY';
  jwt := 'Bearer ' || service_key;

  -- Tier 1: available donors
  FOR donor_record IN
    SELECT * FROM find_compatible_donors(
      request_record.blood_group, request_record.rh_factor,
      request_record.lat, request_record.lng, request_record.current_radius_km
    )
  LOOP
    donors_found := TRUE;
    INSERT INTO public.donor_responses (request_id, donor_id, status)
    VALUES (request_record.id, donor_record.id, 'notified');

    PERFORM net.http_post(
      url     := project_url || '/functions/v1/send-emergency-notification',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', jwt),
      body    := jsonb_build_object(
        'request_id',   request_record.id,
        'donor_id',     donor_record.id,
        'blood_group',  request_record.blood_group::text || CASE WHEN request_record.rh_factor = 'positive' THEN '+' ELSE '-' END,
        'hospital_name', (SELECT hospital_name FROM hospitals WHERE id = request_record.hospital_id),
        'patient_story', request_record.patient_story,
        'distance_km',  (6371 * acos(
          cos(radians(request_record.lat)) * cos(radians(donor_record.lat::float))
          * cos(radians(donor_record.lng::float) - radians(request_record.lng))
          + sin(radians(request_record.lat)) * sin(radians(donor_record.lat::float))
        ))::int
      )
    );
  END LOOP;

  -- Tier 3: cooldown override
  IF NOT donors_found THEN
    FOR donor_record IN
      SELECT * FROM find_cooldown_donors(
        request_record.blood_group, request_record.rh_factor,
        request_record.lat, request_record.lng, 30
      )
    LOOP
      cooldown_donors_found := TRUE;
      INSERT INTO public.donor_responses (request_id, donor_id, status, is_cooldown_override)
      VALUES (request_record.id, donor_record.id, 'notified', true);

      PERFORM net.http_post(
        url     := project_url || '/functions/v1/send-override-notification',
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', jwt),
        body    := jsonb_build_object(
          'request_id',            request_record.id,
          'donor_id',              donor_record.id,
          'blood_group',           request_record.blood_group::text || CASE WHEN request_record.rh_factor = 'positive' THEN '+' ELSE '-' END,
          'hospital_name',         (SELECT hospital_name FROM hospitals WHERE id = request_record.hospital_id),
          'patient_story',         request_record.patient_story,
          'cooldown_days_remaining', (donor_record.cooldown_end_date - CURRENT_DATE)
        )
      );
    END LOOP;
  END IF;

  -- Tier 2: community SOS
  IF NOT donors_found AND NOT cooldown_donors_found THEN
    PERFORM net.http_post(
      url     := project_url || '/functions/v1/send-community-sos',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', jwt),
      body    := jsonb_build_object(
        'request_id',  request_record.id,
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

-- =============================================
-- STEP 9: Trigger (after function exists)
-- =============================================
CREATE TRIGGER on_new_blood_request_trigger
AFTER INSERT ON public.blood_requests
FOR EACH ROW EXECUTE FUNCTION handle_new_blood_request();

-- =============================================
-- STEP 10: Realtime
-- =============================================
ALTER TABLE donor_responses REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime FOR TABLE donor_responses;
  ELSE
    ALTER PUBLICATION supabase_realtime ADD TABLE donor_responses;
  END IF;
EXCEPTION
  WHEN duplicate_object OR duplicate_table THEN
    NULL;
  WHEN OTHERS THEN
    NULL;
END $$;
