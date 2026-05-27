// Supabase Edge Function: Send Community SOS
// Sends a notification to all donors in Hyderabad via a topic subscription.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;
const SOS_TOPIC = "hyderabad_donors"; // All donors should be subscribed to this topic

serve(async (req) => {
  try {
    const { request_id, blood_group } = await req.json();

    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: `/topics/${SOS_TOPIC}`,
        priority: "normal",
        notification: {
          title: `Community SOS: ${blood_group} Needed`,
          body: `A patient urgently needs ${blood_group} blood in Hyderabad. If you know someone who can help, please open the app to submit their details.`,
          sound: "default",
        },
        data: {
          type: "community_sos",
          request_id,
          blood_group,
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
