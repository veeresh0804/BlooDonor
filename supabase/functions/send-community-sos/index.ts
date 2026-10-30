// Supabase Edge Function: Send Community SOS (FCM HTTP v1)
// Broadcasts to the `hyderabad_donors` topic. Devices must subscribe to that topic
// (NotificationService.initialize does this).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { sendFcm } from "../_shared/fcm.ts";

const SOS_TOPIC = "hyderabad_donors";

serve(async (req) => {
  try {
    const { request_id, blood_group } = await req.json();

    const result = await sendFcm({
      topic: SOS_TOPIC,
      priority: "normal",
      title: `Community SOS: ${blood_group} Needed`,
      body:
        `A patient urgently needs ${blood_group} blood in Hyderabad. If you know someone who can help, please open the app to submit their details.`,
      sound: "default",
      data: { type: "community_sos", request_id, blood_group },
    });

    return new Response(
      JSON.stringify(result.ok
        ? { success: true, fcm: result.raw }
        : { success: false, fcm_error: result.errorCode, fcm: result.raw }),
      { status: result.ok ? 200 : 502, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
