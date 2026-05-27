-- Function to handle all post-donation logic in a single transaction
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
  -- Get cooldown days from constants
  v_cooldown_days := CASE p_donation_type
    WHEN 'whole_blood' THEN 90
    WHEN 'platelets' THEN 14
    WHEN 'plasma' THEN 28
    WHEN 'double_red_cells' THEN 180
    ELSE 90
  END;

  -- Get associated IDs
  SELECT user_id INTO v_donor_user_id FROM donor_profiles WHERE id = p_donor_id;
  SELECT hospital_id INTO v_hospital_id FROM blood_requests WHERE id = p_request_id;

  -- Start transaction
  BEGIN
    -- 1. Update donor_responses status
    UPDATE public.donor_responses
    SET status = 'donated', donated_at = NOW()
    WHERE request_id = p_request_id AND donor_id = p_donor_id;

    -- 2. Update blood_requests units_fulfilled
    UPDATE public.blood_requests
    SET units_fulfilled = units_fulfilled + p_units_donated
    WHERE id = p_request_id;

    -- 3. Start cooldown for donor
    UPDATE public.donor_profiles
    SET
      last_donation_date = CURRENT_DATE,
      donation_type_last = p_donation_type,
      cooldown_end_date = CURRENT_DATE + v_cooldown_days,
      cooldown_active = true
    WHERE id = p_donor_id;

    -- 4. Create donation certificate record (URL will be generated later)
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

    -- 5. Update donor achievements (simplified for now)
    -- Create achievement record if not exists
    INSERT INTO public.donor_achievements (donor_id, total_donations, lives_saved, points)
    VALUES (p_donor_id, 0, 0, 0)
    ON CONFLICT (donor_id) DO NOTHING;

    -- Update achievements
    UPDATE public.donor_achievements
    SET
      total_donations = total_donations + 1,
      lives_saved = lives_saved + p_units_donated, -- Assuming 1 unit = 1 life saved
      points = points + 100, -- 100 points per donation
      updated_at = NOW()
    WHERE donor_id = p_donor_id;

  -- End transaction
  END;

  -- 6. Trigger edge functions (out of transaction)
  -- For now, this is best called from the client after the RPC returns
  -- to avoid transaction complexities with external calls.

END;
$$;
