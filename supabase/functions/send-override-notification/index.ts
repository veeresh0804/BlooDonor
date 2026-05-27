// Supabase Edge Function: Send Cooldown Override Notification
// Sends a special notification to a donor who is in their cooldown period.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req) => {
  try {
    const { request_id, donor_id, blood_group, hospital_name, patient_story, cooldown_days_remaining } =
      await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get donor's FCM token
    const { data: donor, error: donorError } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", (
        await supabase.from("donor_profiles").select("user_id").eq("id", donor_id).single()
      ).data.user_id)
      .single();

    if (donorError || !donor?.fcm_token) {
      return new Response(
        JSON.stringify({ error: "Donor FCM token not found" }),
        { status: 404 }
      );
    }

    const fcmToken = donor.fcm_token;

    // Send FCM notification
    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: fcmToken,
        priority: "high",
        notification: {
          title: `RARE BLOOD SOS: ${blood_group} Needed`,
          body: `This is an urgent override request. You are in a cooldown period, but your blood type is critically needed.`,
          sound: "emergency",
          channel_id: "emergency_channel",
        },
        data: {
          type: "cooldown_override_request",
          request_id,
          blood_group,
          hospital_name,
          patient_story: patient_story || "",
          cooldown_days_remaining: String(cooldown_days_remaining),
        },
      }),
    });

    const fcmResult = await fcmResponse.json();

    return new Response(
      JSON.stringify({ success: true, fcm: fcmResult }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});
