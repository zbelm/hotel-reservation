// Receives PayMongo webhooks and confirms paid bookings.
// Deploy with JWT verification off (PayMongo cannot send a Supabase token):
//   supabase functions deploy paymongo-webhook --no-verify-jwt
//
// Secret: PAYMONGO_WEBHOOK_SECRET  (whsk_..., returned when you create the webhook)
// Subscribe the webhook to: checkout_session.payment.paid

import { createClient } from "npm:@supabase/supabase-js@2";

const encoder = new TextEncoder();

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Header looks like: t=1496734173,te=<test signature>,li=<live signature>
function parseSignature(header: string): Record<string, string> {
  return Object.fromEntries(
    header.split(",").map((part) => {
      const i = part.indexOf("=");
      return [part.slice(0, i).trim(), part.slice(i + 1).trim()];
    }),
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const secret = Deno.env.get("PAYMONGO_WEBHOOK_SECRET");
  if (!secret) return new Response("Webhook secret not set", { status: 500 });

  const raw = await req.text();
  const header = req.headers.get("Paymongo-Signature") ?? "";
  const sig = parseSignature(header);

  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  const livemode = Boolean(event?.data?.attributes?.livemode);
  const expected = await hmacHex(secret, `${sig.t}.${raw}`);
  const given = livemode ? sig.li : sig.te;
  if (!sig.t || !given || !timingSafeEqual(expected, given)) {
    return new Response("Invalid signature", { status: 401 });
  }

  const type: string = event.data.attributes.type;
  const resource = event.data.attributes.data;

  // Anything we don't handle still gets a 200 so PayMongo stops retrying
  if (type !== "checkout_session.payment.paid") {
    return new Response(JSON.stringify({ ignored: type }), { status: 200 });
  }

  const sessionId: string = resource.id;
  // deno-lint-ignore no-explicit-any
  const payments: any[] = resource.attributes?.payments ?? [];
  const paid = payments.filter((p) => p?.attributes?.status === "paid");
  const centavos = paid.reduce((sum, p) => sum + Number(p.attributes.amount ?? 0), 0);
  const method: string | null =
    paid[0]?.attributes?.source?.type ?? resource.attributes?.payment_method_used ?? null;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: result, error } = await admin.rpc("confirm_payment", {
    p_provider_ref: sessionId,
    p_amount: centavos / 100,
    p_method: method,
    p_raw: event,
  });

  if (error) {
    console.error("confirm_payment failed", error);
    return new Response("Database error", { status: 500 }); // PayMongo will retry
  }

  console.log(`checkout ${sessionId}: ${result}`);
  return new Response(JSON.stringify({ result }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
