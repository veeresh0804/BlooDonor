// Supabase Edge Function: Send Cooldown Override Notification (FCM HTTP v1)
// Sends a special notification to a donor who is in their cooldown period.

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
    const { request_id, donor_id, blood_group, hospital_name, patient_story, cooldown_days_remaining } =
      await req.json();

    if (!request_id || !donor_id) {
      return json({ error: "request_id and donor_id are required" }, 400);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Previously an unguarded `.data.user_id` chain (500 on unknown donor). Now a clean 404.
    const { data: profile } = await supabase
      .from("donor_profiles")
      .select("user_id")
      .eq("id", donor_id)
      .maybeSingle();
    if (!profile) return json({ error: "Donor not found" }, 404);

    const { data: user } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", profile.user_id)
      .maybeSingle();
    if (!user?.fcm_token) return json({ error: "Donor FCM token not found" }, 404);

    const result = await sendFcm({
      token: user.fcm_token,
      priority: "high",
      title: `RARE BLOOD SOS: ${blood_group} Needed`,
      body:
        "This is an urgent override request. You are in a cooldown period, but your blood type is critically needed.",
      androidChannelId: "emergency_channel",
      sound: "emergency",
      data: {
        type: "cooldown_override_request",
        request_id,
        blood_group,
        hospital_name,
        patient_story: patient_story ?? "",
        cooldown_days_remaining,
      },
    });

    if (!result.ok) {
      if (isDeadToken(result)) {
        await supabase.from("users").update({ fcm_token: null }).eq("id", profile.user_id);
      }
      return json({ success: false, fcm_error: result.errorCode, fcm: result.raw }, 502);
    }
    return json({ success: true, fcm: result.raw });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});
