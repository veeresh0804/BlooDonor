// Supabase Edge Function: Send Emergency Notification
// This function sends FCM push notifications to matched donors

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req) => {
  try {
    const { request_id, donor_id, blood_group, hospital_name, patient_story, distance_km } =
      await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get donor's FCM token
    const { data: donor, error: donorError } = await supabase
      .from("donor_profiles")
      .select("user_id, users(fcm_token)")
      .eq("id", donor_id)
      .single();

    if (donorError || !donor?.users?.fcm_token) {
      return new Response(
        JSON.stringify({ error: "Donor FCM token not found" }),
        { status: 404 }
      );
    }

    const fcmToken = donor.users.fcm_token;

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
          title: `EMERGENCY: ${blood_group} Needed`,
          body: patient_story
            ? `${patient_story.substring(0, 100)}...`
            : `${hospital_name} needs ${blood_group} blood. You are ${distance_km}km away.`,
          sound: "emergency",
          channel_id: "emergency_channel",
          android_channel_id: "emergency_channel",
        },
        data: {
          type: "emergency_request",
          request_id,
          blood_group,
          hospital_name,
          patient_story: patient_story || "",
          distance_km: String(distance_km),
        },
        android: {
          priority: "high",
          notification: {
            channel_id: "emergency_channel",
            sound: "emergency",
            default_vibrate_timings: true,
            default_sound: false,
            icon: "ic_notification",
            color: "#D32F2F",
          },
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
