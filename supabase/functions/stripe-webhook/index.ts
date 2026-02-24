// Supabase Edge Function: stripe-webhook
// Handles Stripe webhook events for payment confirmation
//
// SECURITY: This function:
// - Verifies webhook signature using STRIPE_WEBHOOK_SECRET
// - Creates entitlements ONLY after payment_intent.succeeded
// - Uses service_role to bypass RLS
//
// Deploy with: supabase functions deploy stripe-webhook
// Set secrets:
//   supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx
//   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
//
// Configure webhook in Stripe Dashboard:
//   URL: https://<project>.supabase.co/functions/v1/stripe-webhook
//   Events: payment_intent.succeeded, payment_intent.payment_failed
//
// IMPORTANT: This function MUST return 2xx for all valid webhook calls
// to prevent Stripe from retrying. Errors are logged but don't cause 500s.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") || "";

// Create Supabase client INSIDE handler to ensure fresh env vars on each request
function getSupabaseClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    client: createClient(supabaseUrl, supabaseServiceKey),
    url: supabaseUrl,
    hasKey: !!supabaseServiceKey,
  };
}

// Helper: Return 200 OK response (always use this to acknowledge receipt)
function ok(message = "ok"): Response {
  return new Response(JSON.stringify({ received: true, message }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

// Helper: Return 400 Bad Request (only for signature failures)
function badRequest(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // ========================================
  // REQUEST LOGGING
  // ========================================
  const requestId = crypto.randomUUID().substring(0, 8);
  console.log(`[${requestId}] === STRIPE-WEBHOOK REQUEST ===`);
  console.log(`[${requestId}] Timestamp: ${new Date().toISOString()}`);
  console.log(`[${requestId}] Method: ${req.method}`);

  const { client: supabase, url: supabaseUrl, hasKey: hasServiceKey } = getSupabaseClient();

  console.log(`[${requestId}] Supabase URL configured: ${!!supabaseUrl}`);
  console.log(`[${requestId}] Service Key configured: ${hasServiceKey}`);
  console.log(`[${requestId}] Webhook Secret configured: ${!!webhookSecret}`);

  // Only accept POST requests
  if (req.method !== "POST") {
    console.log(`[${requestId}] Rejected: Method not allowed (${req.method})`);
    return new Response("Method not allowed", { status: 405 });
  }

  // ========================================
  // SIGNATURE VERIFICATION
  // ========================================
  try {
    const body = await req.text();
    const signature = req.headers.get("stripe-signature");

    if (!signature) {
      console.error(`[${requestId}] ERROR: Missing stripe-signature header`);
      return badRequest("Missing stripe-signature header");
    }

    if (!webhookSecret) {
      console.error(`[${requestId}] ERROR: STRIPE_WEBHOOK_SECRET not configured`);
      // Return 200 anyway - we don't want Stripe to keep retrying if config is wrong
      // Admin should check logs and fix the secret
      return ok("Webhook secret not configured - please check server logs");
    }

    // Verify webhook signature
    let event: Stripe.Event;
    try {
      event = await stripe.webhooks.constructEventAsync(
        body,
        signature,
        webhookSecret
      );
    } catch (err) {
      // Signature verification failed - this IS a valid reason to return 400
      // because it might be a malicious request, not a real Stripe event
      console.error(`[${requestId}] ERROR: Signature verification failed:`, err);
      return badRequest(`Webhook signature verification failed`);
    }

    console.log(`[${requestId}] Event verified: ${event.type} (ID: ${event.id})`);

    // ========================================
    // EVENT HANDLING
    // ========================================
    switch (event.type) {
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log(`[${requestId}] Processing payment_intent.succeeded: ${paymentIntent.id}`);

        // Handle payment - errors are caught and logged, never thrown
        await handlePaymentSuccess(requestId, paymentIntent, supabase);
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log(`[${requestId}] Processing payment_intent.payment_failed: ${paymentIntent.id}`);

        // Log failure - no entitlement created
        await handlePaymentFailure(requestId, paymentIntent, supabase);
        break;
      }

      default:
        // Unknown event type - acknowledge receipt but ignore
        console.log(`[${requestId}] Ignoring unhandled event type: ${event.type}`);
    }

    // ========================================
    // ALWAYS RETURN 200
    // ========================================
    console.log(`[${requestId}] Returning 200 OK`);
    return ok();

  } catch (error) {
    // ========================================
    // TOP-LEVEL ERROR HANDLER
    // ========================================
    // Log the error but STILL return 200 to prevent Stripe retries
    // This is intentional - we'd rather miss one event than have Stripe
    // keep retrying forever
    console.error(`[${requestId}] UNEXPECTED ERROR (returning 200 anyway):`, error);
    return ok("Error logged - see server logs for details");
  }
});

/**
 * Handle successful payment - create entitlement
 *
 * IMPORTANT: This function catches all errors internally and never throws.
 * The webhook must always return 200 to prevent Stripe retries.
 */
async function handlePaymentSuccess(
  requestId: string,
  paymentIntent: Stripe.PaymentIntent,
  supabase: ReturnType<typeof createClient>
): Promise<void> {
  console.log(`[${requestId}] === HANDLE PAYMENT SUCCESS ===`);
  console.log(`[${requestId}] Payment ID: ${paymentIntent.id}`);
  console.log(`[${requestId}] Amount: ${paymentIntent.amount} ${paymentIntent.currency}`);
  console.log(`[${requestId}] Status: ${paymentIntent.status}`);
  console.log(`[${requestId}] Metadata: ${JSON.stringify(paymentIntent.metadata)}`);

  try {
    // ========================================
    // VALIDATE METADATA
    // ========================================
    const userId = paymentIntent.metadata?.user_id;
    const audiobookIdStr = paymentIntent.metadata?.audiobook_id;
    const priceUsd = paymentIntent.metadata?.price_usd || paymentIntent.metadata?.price_toman;

    console.log(`[${requestId}] Extracted user_id: ${userId || 'MISSING'}`);
    console.log(`[${requestId}] Extracted audiobook_id: ${audiobookIdStr || 'MISSING'}`);

    if (!userId) {
      console.error(`[${requestId}] ERROR: Missing user_id in metadata`);
      console.error(`[${requestId}] This payment cannot be processed. Manual intervention required.`);
      console.error(`[${requestId}] PaymentIntent ID: ${paymentIntent.id}`);
      return; // Don't throw - return gracefully
    }

    if (!audiobookIdStr) {
      console.error(`[${requestId}] ERROR: Missing audiobook_id in metadata`);
      console.error(`[${requestId}] This payment cannot be processed. Manual intervention required.`);
      console.error(`[${requestId}] PaymentIntent ID: ${paymentIntent.id}`);
      return; // Don't throw - return gracefully
    }

    const audiobookId = parseInt(audiobookIdStr, 10);
    if (isNaN(audiobookId)) {
      console.error(`[${requestId}] ERROR: Invalid audiobook_id: ${audiobookIdStr}`);
      return; // Don't throw - return gracefully
    }

    // ========================================
    // IDEMPOTENCY CHECK 1: By payment_id
    // ========================================
    console.log(`[${requestId}] Checking if payment already processed...`);
    const { data: existingByPaymentId, error: checkError1 } = await supabase
      .from("entitlements")
      .select("id")
      .eq("payment_id", paymentIntent.id)
      .maybeSingle();

    if (checkError1) {
      console.error(`[${requestId}] ERROR checking existing payment:`, checkError1);
      // Continue anyway - we'll try to insert
    }

    if (existingByPaymentId) {
      console.log(`[${requestId}] Payment ${paymentIntent.id} already processed (entitlement exists)`);
      return;
    }

    // ========================================
    // IDEMPOTENCY CHECK 2: By user+audiobook
    // ========================================
    console.log(`[${requestId}] Checking if user already owns audiobook...`);
    const { data: existingEntitlement, error: checkError2 } = await supabase
      .from("entitlements")
      .select("id, payment_id")
      .eq("user_id", userId)
      .eq("audiobook_id", audiobookId)
      .maybeSingle();

    if (checkError2) {
      console.error(`[${requestId}] ERROR checking existing entitlement:`, checkError2);
      // Continue anyway - we'll try to insert
    }

    if (existingEntitlement) {
      console.log(`[${requestId}] User ${userId.substring(0, 8)}... already owns audiobook ${audiobookId}`);
      return;
    }

    // ========================================
    // CREATE ENTITLEMENT
    // ========================================
    console.log(`[${requestId}] Creating entitlement...`);
    console.log(`[${requestId}]   user_id: ${userId}`);
    console.log(`[${requestId}]   audiobook_id: ${audiobookId}`);
    console.log(`[${requestId}]   source: purchase`);
    console.log(`[${requestId}]   payment_id: ${paymentIntent.id}`);

    const { data: insertedData, error: entitlementError } = await supabase
      .from("entitlements")
      .insert({
        user_id: userId,
        audiobook_id: audiobookId,
        source: "purchase",
        payment_id: paymentIntent.id,
      })
      .select()
      .single();

    if (entitlementError) {
      // Handle unique constraint violation gracefully (race condition)
      if (entitlementError.code === "23505") {
        console.log(`[${requestId}] Entitlement already exists (concurrent insert) - OK`);
        return;
      }

      console.error(`[${requestId}] ERROR creating entitlement:`, entitlementError);
      console.error(`[${requestId}] Error code: ${entitlementError.code}`);
      console.error(`[${requestId}] Error message: ${entitlementError.message}`);
      console.error(`[${requestId}] Error details: ${JSON.stringify(entitlementError.details)}`);
      // Don't throw - we've logged the error, admin can investigate
      return;
    }

    console.log(`[${requestId}] SUCCESS: Entitlement created!`);
    console.log(`[${requestId}] Entitlement ID: ${insertedData?.id}`);

    // ========================================
    // INCREMENT PURCHASE COUNT (optional)
    // ========================================
    try {
      const { error: rpcError } = await supabase.rpc("increment_purchase_count", {
        audiobook_id: audiobookId,
      });

      if (rpcError) {
        console.warn(`[${requestId}] WARN: Failed to increment purchase count:`, rpcError);
        // Don't throw - entitlement was created successfully
      } else {
        console.log(`[${requestId}] Purchase count incremented`);
      }
    } catch (rpcErr) {
      console.warn(`[${requestId}] WARN: RPC call failed:`, rpcErr);
    }

    // ========================================
    // CREATE PURCHASE RECORD (optional audit trail)
    // ========================================
    try {
      const { error: purchaseError } = await supabase
        .from("purchases")
        .insert({
          user_id: userId,
          audiobook_id: audiobookId,
          amount: priceUsd ? parseInt(priceUsd, 10) : 0,
          price_toman: priceUsd ? parseInt(priceUsd, 10) : 0,
          payment_method: "stripe",
          payment_reference: paymentIntent.id,
          status: "completed",
        });

      if (purchaseError) {
        console.warn(`[${requestId}] WARN: Purchase record not created:`, purchaseError.message);
      } else {
        console.log(`[${requestId}] Purchase record created`);
      }
    } catch (purchaseErr) {
      console.warn(`[${requestId}] WARN: Purchases table may not exist:`, purchaseErr);
    }

    console.log(`[${requestId}] === PAYMENT PROCESSING COMPLETE ===`);

  } catch (error) {
    // ========================================
    // CATCH-ALL ERROR HANDLER
    // ========================================
    // Log but don't throw - webhook must return 200
    console.error(`[${requestId}] UNEXPECTED ERROR in handlePaymentSuccess:`, error);
    console.error(`[${requestId}] PaymentIntent ID: ${paymentIntent.id}`);
    console.error(`[${requestId}] This payment may need manual processing.`);
  }
}

/**
 * Handle failed payment - log for debugging
 *
 * IMPORTANT: This function catches all errors internally and never throws.
 */
async function handlePaymentFailure(
  requestId: string,
  paymentIntent: Stripe.PaymentIntent,
  supabase: ReturnType<typeof createClient>
): Promise<void> {
  console.log(`[${requestId}] === HANDLE PAYMENT FAILURE ===`);
  console.log(`[${requestId}] Payment ID: ${paymentIntent.id}`);

  const userId = paymentIntent.metadata?.user_id;
  const audiobookIdStr = paymentIntent.metadata?.audiobook_id;
  const priceUsd = paymentIntent.metadata?.price_usd || paymentIntent.metadata?.price_toman;

  console.log(`[${requestId}] Failed payment details:`, {
    paymentIntentId: paymentIntent.id,
    userId: userId || 'unknown',
    audiobookId: audiobookIdStr || 'unknown',
    amount: paymentIntent.amount,
    currency: paymentIntent.currency,
    lastPaymentError: paymentIntent.last_payment_error?.message,
  });

  // Optionally create a failed purchase record for audit
  if (userId && audiobookIdStr) {
    try {
      const { error: purchaseError } = await supabase.from("purchases").insert({
        user_id: userId,
        audiobook_id: parseInt(audiobookIdStr, 10),
        amount: priceUsd ? parseInt(priceUsd, 10) : 0,
        price_toman: priceUsd ? parseInt(priceUsd, 10) : 0,
        payment_method: "stripe",
        payment_reference: paymentIntent.id,
        status: "failed",
      });

      if (purchaseError) {
        console.warn(`[${requestId}] WARN: Failed purchase record not created:`, purchaseError.message);
      }
    } catch (error) {
      console.warn(`[${requestId}] WARN: Purchases table may not exist:`, error);
    }
  }

  console.log(`[${requestId}] === PAYMENT FAILURE LOGGED ===`);
}

// ========================================
// TEST PLAN
// ========================================
/*
MANUAL TEST PLAN FOR STRIPE WEBHOOK

1. STRIPE TEST PURCHASE FLOW:
   a. Create a test user in the app (or use existing)
   b. Select a PAID audiobook and initiate purchase
   c. Use Stripe test card: 4242 4242 4242 4242
   d. Complete payment in Stripe Payment Sheet

   VERIFY IN STRIPE DASHBOARD:
   - Go to Developers > Events
   - Find the payment_intent.succeeded event
   - Check that it shows "Delivered" (2xx response)
   - Click to see the webhook response

   VERIFY IN SUPABASE:
   - Go to Database > entitlements table
   - Look for new row with:
     - user_id matching your test user
     - audiobook_id matching the book you bought
     - source = 'purchase'
     - payment_id = the Stripe PaymentIntent ID

   VERIFY IN APP:
   - Go to کتابخانه (Library)
   - The purchased audiobook should appear
   - You should be able to play all chapters

2. FREE BOOK FLOW:
   a. Find a free audiobook (is_free = true)
   b. Tap "افزودن به کتابخانه" (Add to Library)

   VERIFY IN SUPABASE:
   - New entitlements row with source = 'free'

   VERIFY IN APP:
   - Book appears in کتابخانه
   - All chapters playable

3. ERROR HANDLING:
   a. Cancel payment in Stripe sheet
   - No entitlement should be created
   - App should show appropriate message

   b. Use failing test card: 4000 0000 0000 9995
   - payment_intent.payment_failed event sent
   - No entitlement created
   - Failure logged in Supabase Edge Function logs

4. CHECK LOGS:
   - Go to Supabase Dashboard > Edge Functions > stripe-webhook > Logs
   - Look for [requestId] prefixed log lines
   - Verify each step is logged
   - Check for any ERROR lines

5. VERIFY WEBHOOK SECRET:
   - In Stripe Dashboard > Developers > Webhooks
   - Find the webhook for luhmoqbtscutheafetlr.supabase.co
   - Click to reveal signing secret (starts with whsec_)
   - In Supabase, verify STRIPE_WEBHOOK_SECRET matches exactly
   - Make sure it's the TEST mode secret (not live)
*/
