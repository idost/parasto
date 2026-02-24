// Supabase Edge Function: create-payment-intent
// Creates a Stripe PaymentIntent for audiobook purchases
//
// SECURITY: This function:
// - Only accepts audiobook_id from client (no price)
// - Looks up price from database
// - Embeds user_id and audiobook_id in PaymentIntent metadata
// - Webhook will verify payment and create entitlement
//
// Deploy with: supabase functions deploy create-payment-intent
// Set secrets:
//   supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface PaymentRequest {
  audiobook_id: number;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // [DIAGNOSTIC] Log request timestamp for tracing
  console.log("=== CREATE-PAYMENT-INTENT REQUEST ===");
  console.log("[DIAGNOSTIC] Timestamp:", new Date().toISOString());

  try {
    // Get and verify JWT from Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing or invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const jwt = authHeader.replace("Bearer ", "");

    // Create Supabase client with service role to read audiobook price
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      console.error("Auth error:", authError);
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request body - only audiobook_id is accepted
    const { audiobook_id }: PaymentRequest = await req.json();

    // Validate input
    if (!audiobook_id || typeof audiobook_id !== "number") {
      return new Response(
        JSON.stringify({ error: "Invalid request: audiobook_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Look up audiobook price from database
    const { data: audiobook, error: dbError } = await supabase
      .from("audiobooks")
      .select("id, title_fa, price_toman, is_free, status")
      .eq("id", audiobook_id)
      .single();

    if (dbError || !audiobook) {
      console.error("Database error:", dbError);
      return new Response(
        JSON.stringify({ error: "Audiobook not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify audiobook is approved and not free
    if (audiobook.status !== "approved") {
      return new Response(
        JSON.stringify({ error: "Audiobook is not available for purchase" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (audiobook.is_free) {
      return new Response(
        JSON.stringify({ error: "This audiobook is free - no payment required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!audiobook.price_toman || audiobook.price_toman <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid audiobook price" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if user already owns this audiobook
    const { data: existingEntitlement } = await supabase
      .from("entitlements")
      .select("id")
      .eq("user_id", user.id)
      .eq("audiobook_id", audiobook_id)
      .maybeSingle();

    if (existingEntitlement) {
      return new Response(
        JSON.stringify({ error: "You already own this audiobook" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Price is stored as USD in price_toman field (legacy field name)
    // Convert USD to cents for Stripe (minimum 50 cents)
    const amountUsdCents = Math.max(50, Math.round(audiobook.price_toman * 100));

    // Create Payment Intent with user_id and audiobook_id in metadata
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountUsdCents,
      currency: "usd",
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        user_id: user.id,
        audiobook_id: audiobook_id.toString(),
        audiobook_title: audiobook.title_fa || "",
        price_usd: audiobook.price_toman.toString(),
      },
    });

    // [DIAGNOSTIC] Detailed logging for payment intent creation
    console.log("[DIAGNOSTIC] PaymentIntent created successfully:");
    console.log("[DIAGNOSTIC]   - PaymentIntent ID:", paymentIntent.id);
    console.log("[DIAGNOSTIC]   - User ID:", user.id);
    console.log("[DIAGNOSTIC]   - Audiobook ID:", audiobook_id);
    console.log("[DIAGNOSTIC]   - Amount (cents):", amountUsdCents);
    console.log("[DIAGNOSTIC]   - Metadata:", JSON.stringify(paymentIntent.metadata));

    // Return only client_secret (client doesn't need payment intent ID)
    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error creating payment intent:", error);

    // Handle Stripe errors specifically
    if (error instanceof Stripe.errors.StripeError) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
