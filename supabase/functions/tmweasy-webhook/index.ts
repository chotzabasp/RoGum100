import md5 from "npm:md5@2.3.0";
import { createClient } from "npm:@supabase/supabase-js@2";

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ status: 0, error: "Method not allowed" }, 405);

  try {
    const tmwApiKey = Deno.env.get("TMWEASY_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    if (!tmwApiKey || !supabaseUrl) {
      console.error("Missing server configuration");
      return json({ status: 0, error: "Server configuration error" }, 500);
    }

    let supabaseSecret = "";
    const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
    if (secretKeysRaw) {
      try { supabaseSecret = JSON.parse(secretKeysRaw)?.default ?? ""; } catch { /* fallback below */ }
    }
    if (!supabaseSecret) supabaseSecret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseSecret) {
      console.error("Missing Supabase secret key");
      return json({ status: 0, error: "Server configuration error" }, 500);
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseSecret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let data = "";
    let signature = "";
    const contentType = req.headers.get("content-type") ?? "";
    if (contentType.includes("application/x-www-form-urlencoded") || contentType.includes("multipart/form-data")) {
      const form = await req.formData();
      data = String(form.get("data") ?? "");
      signature = String(form.get("signature") ?? "");
    } else {
      const body = await req.json();
      data = typeof body.data === "string" ? body.data : JSON.stringify(body.data ?? "");
      signature = String(body.signature ?? "");
    }
    if (!data || !signature) return json({ status: 0, error: "Missing data or signature" }, 400);

    const expectedSignature = md5(`${data}:${tmwApiKey}`).toLowerCase();
    if (!safeEqual(expectedSignature, signature.toLowerCase())) {
      console.warn("Invalid TMWEASY signature");
      return json({ status: 0, error: "Invalid signature" }, 401);
    }

    let payment: Record<string, unknown>;
    try { payment = JSON.parse(data); } catch { return json({ status: 0, error: "Invalid payment JSON" }, 400); }

    const idPay = String(payment.id_pay ?? "");
    const ref1 = String(payment.ref1 ?? "");
    const amount = Number(payment.amount);
    const amountCheck = Number(payment.amount_check);
    if (!idPay || !ref1 || !Number.isFinite(amount) || amount <= 0 || !Number.isFinite(amountCheck)) {
      return json({ status: 0, error: "Invalid payment payload" }, 400);
    }

    const { data: creditResult, error: creditError } = await supabaseAdmin.rpc("credit_tmweasy_topup", {
      p_ref1: ref1,
      p_provider_payment_id: idPay,
      p_received_amount: amount,
      p_provider_payload: payment,
    });
    if (creditError) {
      console.error("credit_tmweasy_topup failed:", creditError.message);
      return json({ status: 0, error: "Database processing failed" }, 500);
    }

    console.log("TMWEASY payment result:", creditResult?.status ?? "unknown");
    if (creditResult?.ok === true && (creditResult?.status === "credited" || creditResult?.status === "already_credited")) {
      return json({ status: 1 });
    }

    console.warn("TMWEASY payment requires review:", creditResult?.status ?? "unknown");
    return json({ status: 0, result: creditResult?.status ?? "manual_review" });
  } catch (error) {
    console.error("Unhandled TMWEASY webhook error:", error instanceof Error ? error.message : "Unknown error");
    return json({ status: 0, error: "Invalid request" }, 500);
  }
});
