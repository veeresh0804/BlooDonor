-- Enable pg_net extension for outbound HTTP requests
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function to be called by trigger on new blood request
CREATE OR REPLACE FUNCTION handle_new_blood_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- To access pg_net and service_role keys
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
  -- Get the newly inserted request
  request_record := NEW;

  -- Get project URL and service role key from vault
  SELECT decrypted_secret INTO project_url FROM vault.decrypted_secrets WHERE name = 'SUPABASE_URL';
  SELECT decrypted_secret INTO service_key FROM vault.decrypted_secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY';

  jwt := 'Bearer ' || service_key;

  -- Tier 1: Find available, eligible donors
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
    -- Create 'notified' record and invoke edge function
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
        'distance_km', (6371 * acos(cos(radians(request_record.lat)) * cos(radians(donor_record.lat::float)) * cos(radians(donor_record.lng::float) - radians(request_record.lng)) + sin(radians(request_record.lat)) * sin(radians(donor_record.lat::float))))::int
      )
    );
  END LOOP;

  -- Tier 3: If no donors found, find cooldown donors
  IF NOT donors_found THEN
    FOR donor_record IN
      SELECT * FROM find_cooldown_donors(
        request_record.blood_group,
        request_record.rh_factor,
        request_record.lat,
        request_record.lng,
        30 -- Wider radius for override
      )
    LOOP
      cooldown_donors_found := TRUE;
      -- Create 'notified' record and invoke OVERRIDE edge function
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

  -- Tier 2: If still no donors, trigger Community SOS
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

  -- Update the donors_notified count on the request
  UPDATE public.blood_requests
  SET donors_notified = (SELECT count(*) FROM donor_responses WHERE request_id = request_record.id)
  WHERE id = request_record.id;

  RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_new_blood_request_trigger
AFTER INSERT ON public.blood_requests
FOR EACH ROW
EXECUTE FUNCTION handle_new_blood_request();
