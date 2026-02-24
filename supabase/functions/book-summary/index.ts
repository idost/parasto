// Supabase Edge Function: book-summary
// Generates AI-powered 2-line book summaries in Persian using Anthropic Claude
//
// SECURITY:
// - Requires valid Supabase auth token
// - API key is stored in Supabase secrets (never hardcoded)
// - Summaries are cached in DB to reduce API costs
// - Rate limited: 10 new AI generations per user per 24 hours
//
// Deploy with: supabase functions deploy book-summary
// Set secrets:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxx

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface SummaryRequest {
  audiobook_id: number;
  force_refresh?: boolean;
}

interface AnthropicMessage {
  role: string;
  content: string;
}

interface AnthropicResponse {
  content: Array<{ type: string; text: string }>;
  model: string;
  stop_reason: string;
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
      console.error("Unauthorized request: missing or invalid Authorization header");
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const jwt = authHeader.replace("Bearer ", "");

    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

    if (!anthropicApiKey) {
      console.error("ANTHROPIC_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "ai_not_configured" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      console.error("Auth error:", authError);
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = user.id;

    // Parse request body
    let requestBody: SummaryRequest;
    try {
      requestBody = await req.json();
    } catch (parseError) {
      console.error("Failed to parse request body:", parseError);
      return new Response(
        JSON.stringify({ error: "invalid_request_body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { audiobook_id, force_refresh } = requestBody;
    console.log(`Request: audiobook_id=${audiobook_id}, force_refresh=${force_refresh}, user=${userId}`);

    // Validate input
    if (!audiobook_id || typeof audiobook_id !== "number" || audiobook_id <= 0) {
      console.error(`Invalid audiobook_id: ${audiobook_id} (type: ${typeof audiobook_id})`);
      return new Response(
        JSON.stringify({ error: "invalid_audiobook_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check cache first (unless force_refresh)
    console.log(`Checking cache for audiobook ${audiobook_id} (force_refresh=${force_refresh})`);
    if (!force_refresh) {
      const { data: cachedSummary, error: cacheError } = await supabase
        .from("book_summaries")
        .select("summary_fa")
        .eq("audiobook_id", audiobook_id)
        .maybeSingle();

      if (cacheError) {
        console.error(`Cache lookup error for audiobook ${audiobook_id}:`, cacheError);
      }

      if (cachedSummary?.summary_fa) {
        console.log(`CACHE HIT for audiobook ${audiobook_id}, returning cached summary`);
        return new Response(
          JSON.stringify({ summary_fa: cachedSummary.summary_fa, cached: true }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else {
        console.log(`CACHE MISS for audiobook ${audiobook_id}`);
      }
    }

    // Rate limiting: 10 new AI generations per user per 24 hours
    // Only checked when we're about to call Anthropic API (cache miss)
    const RATE_LIMIT_PER_DAY = 10;
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const { count: recentGenerations, error: countError } = await supabase
      .from("book_summaries")
      .select("*", { count: "exact", head: true })
      .eq("generated_by", userId)
      .gte("created_at", twentyFourHoursAgo);

    if (countError) {
      console.error("Error checking rate limit:", countError);
      // Don't block on rate limit check failure, but log it
    } else if (recentGenerations !== null && recentGenerations >= RATE_LIMIT_PER_DAY) {
      console.log(`Rate limit exceeded for user ${userId}: ${recentGenerations}/${RATE_LIMIT_PER_DAY}`);
      return new Response(
        JSON.stringify({ error: "rate_limit_exceeded", limit: RATE_LIMIT_PER_DAY }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch audiobook details
    console.log(`Fetching audiobook details for id=${audiobook_id}`);
    const { data: audiobook, error: dbError } = await supabase
      .from("audiobooks")
      .select("id, title_fa, description_fa, author_fa")
      .eq("id", audiobook_id)
      .single();

    if (dbError || !audiobook) {
      console.error(`Audiobook not found for id=${audiobook_id}:`, dbError);
      return new Response(
        JSON.stringify({ error: "audiobook_not_found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log(`Found audiobook: title="${audiobook.title_fa?.substring(0, 30)}..."`)

    // Validate we have enough data to summarize
    const title = audiobook.title_fa || "";
    const description = audiobook.description_fa || "";
    const author = audiobook.author_fa || "";

    if (!title && !description) {
      console.error(`Insufficient data to summarize audiobook ${audiobook_id}`);
      return new Response(
        JSON.stringify({ error: "insufficient_data" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build the prompt for Claude
    const systemPrompt = `تو یک دستیار کتاب صوتی فارسی هستی که برای اپلیکیشن پرستو (Parasto) کار می‌کنی.
وظیفه‌ات این است که خلاصه‌ای کوتاه و جذاب از کتاب‌ها بنویسی.

قوانین:
- دقیقاً ۲ خط بنویس (نه بیشتر، نه کمتر)
- فارسی سلیس و روان بنویس
- هیچ اسپویلری نده
- تبلیغاتی ننویس
- فقط محتوای کتاب را توضیح بده
- خط اول: موضوع اصلی کتاب
- خط دوم: چرا این کتاب جذاب است یا چه چیزی یاد می‌دهد`;

    const userPrompt = `این کتاب صوتی را در دو خط خلاصه کن:

عنوان: ${title}
${author ? `نویسنده: ${author}` : ""}
${description ? `توضیحات: ${description}` : ""}`;

    // Call Anthropic API with timeout
    console.log(`Calling Anthropic API for audiobook ${audiobook_id}...`);
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000); // 15 second timeout

    let anthropicResponse: Response;
    try {
      anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": anthropicApiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-3-haiku-20240307", // Cheapest, fastest model
          max_tokens: 200, // Short response, 2 lines max
          messages: [
            { role: "user", content: userPrompt }
          ],
          system: systemPrompt,
        }),
        signal: controller.signal,
      });
    } catch (fetchError) {
      clearTimeout(timeoutId);
      if (fetchError instanceof Error && fetchError.name === "AbortError") {
        console.error("Anthropic API timeout");
        return new Response(
          JSON.stringify({ error: "ai_timeout" }),
          { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      throw fetchError;
    }

    clearTimeout(timeoutId);

    if (!anthropicResponse.ok) {
      const errorBody = await anthropicResponse.text();
      console.error("Anthropic API error:", anthropicResponse.status, errorBody);
      // Return more specific error based on status
      const errorCode = anthropicResponse.status === 401 ? "ai_auth_failed"
        : anthropicResponse.status === 429 ? "ai_rate_limit"
        : anthropicResponse.status >= 500 ? "ai_server_error"
        : "ai_request_failed";
      return new Response(
        JSON.stringify({ error: errorCode, status: anthropicResponse.status, debug: errorBody.substring(0, 200) }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result: AnthropicResponse = await anthropicResponse.json();

    if (!result.content || result.content.length === 0 || !result.content[0].text) {
      console.error("Empty response from Anthropic");
      return new Response(
        JSON.stringify({ error: "ai_empty_response" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const summaryText = result.content[0].text.trim();
    const modelUsed = result.model || "claude-3-haiku";

    // Defensive guard: validate summary quality before caching
    // - Must be at least 20 characters (minimum meaningful Persian text)
    // - Must not be excessively long (max 500 chars for 2 lines)
    // - Must contain some Persian characters
    const persianRegex = /[\u0600-\u06FF]/;
    const isValidSummary =
      summaryText.length >= 20 &&
      summaryText.length <= 500 &&
      persianRegex.test(summaryText);

    if (!isValidSummary) {
      console.error(`Invalid summary generated for audiobook ${audiobook_id}: length=${summaryText.length}, hasPersian=${persianRegex.test(summaryText)}`);
      // Return the summary but don't cache it - let user retry
      return new Response(
        JSON.stringify({ summary_fa: summaryText, cached: false, validation_warning: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Generated summary for audiobook ${audiobook_id}: ${summaryText.substring(0, 50)}...`);

    // Cache the summary (upsert)
    const { error: upsertError } = await supabase
      .from("book_summaries")
      .upsert(
        {
          audiobook_id: audiobook_id,
          summary_fa: summaryText,
          model: modelUsed,
          generated_by: userId,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
        { onConflict: "audiobook_id" }
      );

    if (upsertError) {
      // Log but don't fail - we can still return the summary
      console.error("Failed to cache summary:", upsertError);
    }

    console.log(`=== SUCCESS: Returning summary for audiobook ${audiobook_id} ===`);
    return new Response(
      JSON.stringify({ summary_fa: summaryText, cached: false }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Unexpected error in book-summary:", error);
    // Include error details for debugging
    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;
    console.error("Error details:", { message: errorMessage, stack: errorStack });
    return new Response(
      JSON.stringify({ error: "internal_error", debug: errorMessage }),
      { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
