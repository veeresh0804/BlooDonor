-- Function: Find compatible donors within radius
-- Uses Haversine formula for distance calculation
-- Applies blood compatibility, availability, cooldown, and DND filters

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
  -- Build recipient label (e.g., 'O+')
  recipient_label := UPPER(recipient_blood_group::text) ||
    CASE WHEN recipient_rh_factor = 'positive' THEN '+' ELSE '-' END;

  -- Determine compatible donor blood groups based on the matrix
  -- O- can give to everyone
  -- O+ can give to O+, A+, B+, AB+
  -- A- can give to A-, A+, AB-, AB+
  -- A+ can give to A+, AB+
  -- B- can give to B-, B+, AB-, AB+
  -- B+ can give to B+, AB+
  -- AB- can give to AB-, AB+
  -- AB+ can give to AB+ only
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
      -- Haversine formula for distance in km
      6371 * acos(
        cos(radians(hospital_lat))
        * cos(radians(dp.lat::float))
        * cos(radians(dp.lng::float) - radians(hospital_lng))
        + sin(radians(hospital_lat))
        * sin(radians(dp.lat::float))
      )
    ) <= radius_km
    AND (dp.blood_group::text || '-' ||
         CASE WHEN dp.rh_factor = 'positive' THEN 'positive' ELSE 'negative' END)
        = ANY(compatible_groups)
  ORDER BY
    -- Sort by distance (nearest first)
    6371 * acos(
      cos(radians(hospital_lat))
      * cos(radians(dp.lat::float))
      * cos(radians(dp.lng::float) - radians(hospital_lng))
      + sin(radians(hospital_lat))
      * sin(radians(dp.lat::float))
    ) ASC;
END;
$$;

-- Function: Find cooldown donors for emergency override (Tier 3)
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
        cos(radians(hospital_lat))
        * cos(radians(dp.lat::float))
        * cos(radians(dp.lng::float) - radians(hospital_lng))
        + sin(radians(hospital_lat))
        * sin(radians(dp.lat::float))
      )
    ) <= radius_km
    AND (dp.blood_group::text || '-' ||
         CASE WHEN dp.rh_factor = 'positive' THEN 'positive' ELSE 'negative' END)
        = ANY(compatible_groups)
  ORDER BY dp.cooldown_end_date ASC;
END;
$$;
