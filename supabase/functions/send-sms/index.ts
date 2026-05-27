// Supabase Edge Function: Send SMS
// This function sends an SMS using a third-party service (e.g., Twilio)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID")!;
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN")!;
const TWILIO_PHONE_NUMBER = Deno.env.get("TWILIO_PHONE_NUMBER")!;

serve(async (req) => {
  try {
    const { to, body } = await req.json();

    // In a real app, you would integrate with Twilio or another SMS provider here.
    // For this demo, we'll just log the action.
    console.log(`Sending SMS to ${to}: "${body}"`);

    // Placeholder for Twilio API call
    /*
    const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`, {
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        To: to,
        From: TWILIO_PHONE_NUMBER,
        Body: body,
      }),
    });
    const responseData = await response.json();
    */

    return new Response(
      JSON.stringify({ success: true, message: "SMS sent (mock)" }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});
