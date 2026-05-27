-- RLS Policies

-- Users: can read own profile
CREATE POLICY "Users can read own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Hospitals: can read all (for matching), can write own
CREATE POLICY "Anyone can read hospitals" ON hospitals
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own hospital" ON hospitals
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own hospital" ON hospitals
  FOR UPDATE USING (auth.uid() = user_id);

-- Donor profiles: can read all (for matching), can write own
CREATE POLICY "Anyone can read donor profiles" ON donor_profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own donor profile" ON donor_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own donor profile" ON donor_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- Blood requests: anyone can read active, hospitals can write own
CREATE POLICY "Anyone can read blood requests" ON blood_requests
  FOR SELECT USING (true);

CREATE POLICY "Hospitals can insert own requests" ON blood_requests
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM hospitals WHERE id = hospital_id AND user_id = auth.uid())
  );

CREATE POLICY "Hospitals can update own requests" ON blood_requests
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM hospitals WHERE id = hospital_id AND user_id = auth.uid())
  );

-- Donor responses: donors can read/write own, hospitals can read for their requests
CREATE POLICY "Donors can read own responses" ON donor_responses
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM donor_profiles WHERE id = donor_id AND user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM blood_requests br
      JOIN hospitals h ON h.id = br.hospital_id
      WHERE br.id = request_id AND h.user_id = auth.uid()
    )
  );

CREATE POLICY "Donors can insert own responses" ON donor_responses
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM donor_profiles WHERE id = donor_id AND user_id = auth.uid())
  );

CREATE POLICY "Donors can update own responses" ON donor_responses
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM donor_profiles WHERE id = donor_id AND user_id = auth.uid())
  );
