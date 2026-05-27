-- Fix: Add unique constraint on donor_id so upserts in confirm_donation_complete work
ALTER TABLE donor_achievements ADD CONSTRAINT donor_achievements_donor_id_key UNIQUE (donor_id);

-- Enable RLS for auxiliary tables
ALTER TABLE donor_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE donation_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE donor_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_analytics ENABLE ROW LEVEL SECURITY;

-- RLS: Read access for achievements, certificates, ratings
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

-- Add missing columns for donor_ratings (align with Flutter rate_donor_screen.dart)
-- The schema has rating_score, punctual, professional, helpful
-- But the Flutter app sends: stars, tags, comment
-- Add the columns the Flutter app expects
ALTER TABLE donor_ratings ADD COLUMN IF NOT EXISTS stars INTEGER CHECK (stars >= 1 AND stars <= 5);
ALTER TABLE donor_ratings ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE donor_ratings ADD COLUMN IF NOT EXISTS comment TEXT;
ALTER TABLE donor_ratings ADD COLUMN IF NOT EXISTS request_id UUID REFERENCES blood_requests(id);

-- Also add first_responder flag to achievements for badge system
ALTER TABLE donor_achievements ADD COLUMN IF NOT EXISTS first_responder BOOLEAN DEFAULT false;
