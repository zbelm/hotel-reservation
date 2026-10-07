// Creates a PayMongo hosted checkout for a held booking and returns its URL.
// Called by the web and mobile apps with the signed-in guest's token.
//
// Secrets (supabase secrets set ...):
//   PAYMONGO_SECRET_KEY  sk_test_... or sk_live_...
//   APP_URL              where guests return after paying, e.g. https://your-app.vercel.app
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

const PAYMONGO_API = "https://api.paymongo.com/v1/checkout_sessions";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY");
  const appUrl = (Deno.env.get("APP_URL") ?? "").replace(/\/$/, "");
  if (!secretKey || !appUrl) {
    return json({ error: "Payments are not set up yet (missing PAYMONGO_SECRET_KEY or APP_URL)" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Please sign in" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: userData } = await userClient.auth.getUser();
  if (!userData?.user) return json({ error: "Please sign in" }, 401);

  let bookingId: string | undefined;
  try {
    ({ booking_id: bookingId } = await req.json());
  } catch {
    return json({ error: "Send JSON with booking_id" }, 400);
  }
  if (!bookingId) return json({ error: "booking_id is required" }, 400);

  // Row Level Security makes sure guests can only load their own booking
  const { data: booking, error } = await userClient
    .from("bookings")
    .select("id, code, status, hold_expires_at, total, currency, check_in, check_out, guest_name, guest_email, guest_phone, booking_rooms(room_types(name), rate_plans(name))")
    .eq("id", bookingId)
    .maybeSingle();

  if (error) return json({ error: error.message }, 400);
  if (!booking) return json({ error: "Booking not found" }, 404);
  if (booking.status !== "held") return json({ error: `This booking is ${booking.status}` }, 409);
  if (!booking.hold_expires_at || new Date(booking.hold_expires_at) <= new Date()) {
    return json({ error: "Your hold on this room has ended. Please book again." }, 409);
  }

  // deno-lint-ignore no-explicit-any
  const room = (booking.booking_rooms as any[])?.[0];
  const roomName = room?.room_types?.name ?? "Room";
  const planName = room?.rate_plans?.name ?? "";
  const amountCentavos = Math.round(Number(booking.total) * 100);

  const body = {
    data: {
      attributes: {
        line_items: [{
          name: `${roomName}${planName ? ` (${planName})` : ""}, ${booking.check_in} to ${booking.check_out}`,
          amount: amountCentavos,
          currency: booking.currency ?? "PHP",
          quantity: 1,
        }],
        payment_method_types: ["gcash", "paymaya", "grab_pay", "card", "qrph"],
        description: `Hotel booking ${booking.code}`,
        reference_number: booking.code,
        send_email_receipt: true,
        show_description: true,
        show_line_items: true,
        billing: {
          name: booking.guest_name,
          email: booking.guest_email,
          ...(booking.guest_phone ? { phone: booking.guest_phone } : {}),
        },
        success_url: `${appUrl}/payment/success?booking=${booking.id}`,
        cancel_url: `${appUrl}/payment/cancelled?booking=${booking.id}`,
        metadata: { booking_id: booking.id, booking_code: booking.code },
      },
    },
  };

  const pmRes = await fetch(PAYMONGO_API, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: `Basic ${btoa(`${secretKey}:`)}`,
    },
    body: JSON.stringify(body),
  });
  const pm = await pmRes.json();
  if (!pmRes.ok) {
    console.error("PayMongo error", JSON.stringify(pm));
    const detail = pm?.errors?.[0]?.detail ?? "Could not start payment";
    return json({ error: detail }, 502);
  }

  const sessionId: string = pm.data.id;
  const checkoutUrl: string = pm.data.attributes.checkout_url;

  const { error: payErr } = await admin.from("payments").insert({
    booking_id: booking.id,
    amount: booking.total,
    currency: booking.currency ?? "PHP",
    provider: "paymongo",
    provider_ref: sessionId,
    checkout_url: checkoutUrl,
    status: "pending",
  });
  if (payErr) {
    console.error("Could not save payment", payErr);
    return json({ error: "Could not save payment" }, 500);
  }

  return json({ checkout_url: checkoutUrl, hold_expires_at: booking.hold_expires_at });
});
