// Supabase Edge Function: Send Emergency Notification (FCM HTTP v1)
// Called by the handle_new_blood_request trigger, one call per matched donor.
// Payload: { request_id, donor_id, blood_group, hospital_name, patient_story, distance_km }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isDeadToken, sendFcm } from "../_shared/fcm.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

serve(async (req) => {
  try {
    const { request_id, donor_id, blood_group, hospital_name, patient_story, distance_km } =
      await req.json();

    if (!request_id || !donor_id) {
      return json({ error: "request_id and donor_id are required" }, 400);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: profile, error: profileError } = await supabase
      .from("donor_profiles")
      .select("user_id")
      .eq("id", donor_id)
      .maybeSingle();
    if (profileError || !profile) return json({ error: "Donor not found" }, 404);

    const { data: user, error: userError } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", profile.user_id)
      .maybeSingle();
    if (userError || !user?.fcm_token) {
      return json({ error: "Donor FCM token not found" }, 404);
    }

    const story = typeof patient_story === "string" ? patient_story : "";
    const result = await sendFcm({
      token: user.fcm_token,
      priority: "high",
      title: `EMERGENCY: ${blood_group} Needed`,
      body: story
        ? (story.length > 100 ? `${story.substring(0, 100)}...` : story)
        : `${hospital_name} needs ${blood_group} blood. You are ${distance_km}km away.`,
      androidChannelId: "emergency_channel",
      sound: "emergency",
      data: {
        type: "emergency_request",
        request_id,
        blood_group,
        hospital_name,
        patient_story: story,
        distance_km,
      },
    });

    if (!result.ok) {
      if (isDeadToken(result)) {
        // Stale token: clear it so we stop targeting a dead device.
        await supabase.from("users").update({ fcm_token: null }).eq("id", profile.user_id);
      }
      return json({ success: false, fcm_error: result.errorCode, fcm: result.raw }, 502);
    }
    return json({ success: true, fcm: result.raw });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});
