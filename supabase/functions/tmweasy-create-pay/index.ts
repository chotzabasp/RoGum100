import { createClient } from "npm:@supabase/supabase-js@2";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    },
  });
}

async function fetchWithTimeout(url: URL, timeoutMs = 15000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { method: "GET", signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const apiUrl = Deno.env.get("TMWEASY_API_URL") ?? "";
    const username = Deno.env.get("TMWEASY_USERNAME") ?? "";
    const password = Deno.env.get("TMWEASY_PASSWORD") ?? "";
    const conId = Deno.env.get("TMWEASY_CON_ID") ?? "";
    const promptpayId = Deno.env.get("TMWEASY_PROMPTPAY_ID") ?? "";
    const promptpayType = Deno.env.get("TMWEASY_PROMPTPAY_TYPE") ?? "";

    if (!supabaseUrl || !serviceRoleKey || !apiUrl || !username || !password || !conId || !promptpayId || !promptpayType) {
      console.error("Missing server configuration");
      return json({ ok: false, error: "Server configuration error" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ ok: false, error: "Unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await admin.auth.getUser(authHeader.slice(7));
    if (userError || !user) return json({ ok: false, error: "Unauthorized" }, 401);

    const body = await req.json();
    const amount = Number(body.amount);
    if (!Number.isInteger(amount) || amount < 20 || amount > 100000) {
      return json({ ok: false, error: "จำนวนเงินต้องอยู่ระหว่าง 20 - 100,000 บาท" }, 400);
    }
    const points = amount;

    const { data: tx, error: txError } = await admin.from("topup_transactions").insert({
      user_id: user.id,
      requested_amount: amount,
      points,
      provider: "tmweasy",
      status: "pending",
    }).select("id, ref1").single();

    if (txError || !tx) {
      console.error("Create transaction failed:", txError?.message);
      return json({ ok: false, error: "ไม่สามารถสร้างรายการเติมเงินได้" }, 500);
    }

    const forwarded = req.headers.get("x-forwarded-for") ?? "";
    const clientIp = forwarded.split(",")[0]?.trim() || "127.0.0.1";
    const createUrl = new URL(apiUrl);
    createUrl.searchParams.set("username", username);
    createUrl.searchParams.set("password", password);
    createUrl.searchParams.set("con_id", conId);
    createUrl.searchParams.set("amount", String(amount));
    createUrl.searchParams.set("ref1", tx.ref1);
    createUrl.searchParams.set("ip", clientIp);
    createUrl.searchParams.set("method", "create_pay");

    const createRes = await fetchWithTimeout(createUrl);
    const createText = await createRes.text();
    let createPay: any = null;
    try { createPay = JSON.parse(createText); } catch { /* handled below */ }

    if (!createRes.ok || !createPay || Number(createPay.status) !== 1 || !createPay.id_pay) {
      await admin.from("topup_transactions").update({
        status: "failed",
        provider_payload: { stage: "create_pay", response: createPay ?? createText },
        updated_at: new Date().toISOString(),
      }).eq("id", tx.id);
      return json({ ok: false, error: createPay?.msg ?? "TMWEASY create_pay failed" }, 502);
    }

    const idPay = String(createPay.id_pay);
    const detailUrl = new URL(apiUrl);
    detailUrl.searchParams.set("username", username);
    detailUrl.searchParams.set("password", password);
    detailUrl.searchParams.set("con_id", conId);
    detailUrl.searchParams.set("id_pay", idPay);
    detailUrl.searchParams.set("promptpay_id", promptpayId);
    detailUrl.searchParams.set("type", promptpayType);
    detailUrl.searchParams.set("method", "detail_pay");

    const detailRes = await fetchWithTimeout(detailUrl);
    const detailText = await detailRes.text();
    let detail: any = null;
    try { detail = JSON.parse(detailText); } catch { /* handled below */ }

    if (!detailRes.ok || !detail || Number(detail.status) !== 1 || !detail.qr_image_base64) {
      await admin.from("topup_transactions").update({
        provider_payment_id: idPay,
        status: "failed",
        provider_payload: { stage: "detail_pay", response: detail ?? detailText },
        updated_at: new Date().toISOString(),
      }).eq("id", tx.id);
      return json({ ok: false, error: detail?.msg ?? "TMWEASY detail_pay failed" }, 502);
    }

    await admin.from("topup_transactions").update({
      provider_payment_id: idPay,
      provider_payload: {
        stage: "qr_created",
        ref1: detail.ref1,
        amount_check: detail.amount_check,
        time_out: detail.time_out,
      },
      updated_at: new Date().toISOString(),
    }).eq("id", tx.id);

    return json({
      ok: true,
      transaction_id: tx.id,
      ref1: tx.ref1,
      id_pay: idPay,
      amount,
      points,
      qr_image_base64: detail.qr_image_base64,
      time_out: Number(detail.time_out ?? 0),
    });
  } catch (error) {
    console.error("tmweasy-create-pay error:", error instanceof Error ? error.message : "Unknown error");
    return json({ ok: false, error: "Internal server error" }, 500);
  }
});
