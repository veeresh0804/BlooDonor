-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ENUM types
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

-- Core users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  email TEXT,
  role user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Hospital profiles
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

-- Donor profiles
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

-- NGO profiles
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

-- Blood requests
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

-- Donor responses
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

-- Donor achievements
CREATE TABLE donor_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  total_donations INTEGER DEFAULT 0,
  lives_saved INTEGER DEFAULT 0,
  badges TEXT[] DEFAULT '{}',
  points INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Donation certificates
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

-- Donor ratings
CREATE TABLE donor_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_response_id UUID REFERENCES donor_responses(id),
  hospital_id UUID REFERENCES hospitals(id),
  donor_id UUID REFERENCES donor_profiles(id),
  punctual BOOLEAN,
  professional BOOLEAN,
  helpful BOOLEAN,
  rating_score INTEGER CHECK (rating_score >= 1 AND rating_score <= 5),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- NGO-Donor links
CREATE TABLE ngo_donors (
  ngo_id UUID REFERENCES ngos(id) ON DELETE CASCADE,
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  is_trained_verified BOOLEAN DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (ngo_id, donor_id)
);

-- Camps
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

-- Leads (unregistered donors)
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

-- Request analytics
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

-- Login streaks
CREATE TABLE donor_login_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_id UUID REFERENCES donor_profiles(id) ON DELETE CASCADE,
  last_login_date DATE,
  current_streak INTEGER DEFAULT 0,
  points_earned_today BOOLEAN DEFAULT false
);

-- Indexes
CREATE INDEX idx_donor_profiles_blood_group ON donor_profiles(blood_group, rh_factor);
CREATE INDEX idx_donor_profiles_availability ON donor_profiles(availability, dnd_mode, cooldown_active);
CREATE INDEX idx_blood_requests_status ON blood_requests(status);
CREATE INDEX idx_blood_requests_hospital ON blood_requests(hospital_id);
CREATE INDEX idx_donor_responses_request ON donor_responses(request_id);
CREATE INDEX idx_donor_responses_donor ON donor_responses(donor_id);

-- Enable RLS (Row Level Security)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE blood_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_responses ENABLE ROW LEVEL SECURITY;
