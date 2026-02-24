// Supabase Edge Function: verify-gift-recipient
// Verifies that a recipient email exists in Parasto before gift payment
//
// SECURITY:
// - Requires valid Supabase auth token
// - Does NOT return user_id (privacy)
// - Only returns ok: true/false
//
// Deploy with: supabase functions deploy verify-gift-recipient

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface VerifyRequest {
  recipient_email: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get and verify JWT from Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ ok: false, reason: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const jwt = authHeader.replace("Bearer ", "");

    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ ok: false, reason: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    let requestBody: VerifyRequest;
    try {
      requestBody = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ ok: false, reason: "invalid_request" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { recipient_email } = requestBody;

    // Validate email format
    if (!recipient_email || typeof recipient_email !== "string") {
      return new Response(
        JSON.stringify({ ok: false, reason: "invalid_email" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const emailLower = recipient_email.trim().toLowerCase();

    // Check if email exists in profiles table (case-insensitive)
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id")
      .ilike("email", emailLower)
      .maybeSingle();

    if (profileError) {
      console.error("Error checking profile:", profileError);
      return new Response(
        JSON.stringify({ ok: false, reason: "server_error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (profile) {
      // Email found - don't return user_id for privacy
      return new Response(
        JSON.stringify({ ok: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Email not found
    return new Response(
      JSON.stringify({ ok: false, reason: "not_found" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ ok: false, reason: "server_error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
