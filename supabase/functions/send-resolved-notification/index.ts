// Supabase Edge Function: Send Resolved Notification (FCM HTTP v1)
// Called by the notify_request_resolved trigger when a request becomes
// fulfilled or cancelled. Tells donors who are still in flight to stand down.
// Payload: { request_id, status }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isDeadToken, sendFcm } from "../_shared/fcm.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Donors who have not finished: they should hear that help is no longer needed.
const IN_FLIGHT = ["notified", "accepted", "on_the_way", "delayed", "arrived", "confirmed"];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

serve(async (req) => {
  try {
    const { request_id, status } = await req.json();
    if (!request_id) return json({ error: "request_id is required" }, 400);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: responses, error: respError } = await supabase
      .from("donor_responses")
      .select("donor_id")
      .eq("request_id", request_id)
      .in("status", IN_FLIGHT);
    if (respError) return json({ error: respError.message }, 500);

    const donorIds = [...new Set((responses ?? []).map((r) => r.donor_id))];
    if (donorIds.length === 0) return json({ success: true, sent: 0 });

    // Separate queries (not a nested join) so we don't depend on join shape.
    const { data: profiles } = await supabase
      .from("donor_profiles").select("id, user_id").in("id", donorIds);
    const userIds = (profiles ?? []).map((p) => p.user_id);
    const { data: users } = await supabase
      .from("users").select("id, fcm_token").in("id", userIds).not("fcm_token", "is", null);

    const body = status === "cancelled"
      ? "This request was cancelled. You don't need to travel — thank you for responding."
      : "This request has been fulfilled. Thank you for being ready to help!";

    let sent = 0;
    let failed = 0;
    for (const u of users ?? []) {
      const result = await sendFcm({
        token: u.fcm_token,
        priority: "high",
        title: "Emergency resolved",
        body,
        data: { type: "emergency_resolved", request_id, status: status ?? "" },
      });
      if (result.ok) sent++;
      else {
        failed++;
        if (isDeadToken(result)) {
          await supabase.from("users").update({ fcm_token: null }).eq("id", u.id);
        }
      }
    }
    return json({ success: true, sent, failed });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});
