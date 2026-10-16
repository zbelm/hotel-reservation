// Sends every sign-in email (code, link, sign-up confirmation, password reset) through EmailJS
// instead of Supabase's built-in mail, which only allows a couple of emails an hour.
// Supabase calls this as its "Send Email" auth hook (Authentication → Hooks).
// Deploy with JWT verification off (Supabase signs the hook request instead):
//   supabase functions deploy send-email --no-verify-jwt
//
// Secrets:
//   SEND_EMAIL_HOOK_SECRET  v1,whsec_... shown when the hook is created
//   EMAILJS_PRIVATE_KEY     EmailJS Account → Security (needed when strict mode is on)
// Optional overrides: EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, EMAILJS_PUBLIC_KEY
//
// The EmailJS template uses {{to_email}}, {{otp}}, {{time}}, {{link}} and {{subject}}.

import { Webhook } from "npm:standardwebhooks@1.0.0";

const SERVICE_ID = Deno.env.get("EMAILJS_SERVICE_ID") ?? "service_520iltn";
const TEMPLATE_ID = Deno.env.get("EMAILJS_TEMPLATE_ID") ?? "template_37ruhko";
const PUBLIC_KEY = Deno.env.get("EMAILJS_PUBLIC_KEY") ?? "sq1Z56zVbrX-BeM8g";
const PRIVATE_KEY = Deno.env.get("EMAILJS_PRIVATE_KEY");
// Keeps only the base64 part, so a value pasted with spaces, quotes, line breaks or
// the "v1,whsec_" prefix still works
const rawSecret = (Deno.env.get("SEND_EMAIL_HOOK_SECRET") ?? "").replace(/\s+/g, "");
const HOOK_SECRET = (rawSecret.match(/whsec_([A-Za-z0-9+/=]+)/)?.[1] ?? rawSecret)
  .replace(/^["']|["']$/g, "");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// Matches Authentication → Providers → Email → Email OTP Expiration
const VALID_MINUTES = Number(Deno.env.get("OTP_VALID_MINUTES") ?? "60");

const SUBJECTS: Record<string, string> = {
  signup: "Confirm your Macrotel account",
  magiclink: "Your Macrotel sign-in code",
  recovery: "Reset your Macrotel password",
  invite: "You're invited to Macrotel",
  email_change: "Confirm your new email for Macrotel",
  reauthentication: "Your Macrotel confirmation code",
};

type HookPayload = {
  user: { email: string; new_email?: string };
  email_data: {
    token: string;
    token_hash: string;
    redirect_to: string;
    email_action_type: string;
    site_url: string;
    token_new?: string;
    token_hash_new?: string;
  };
};

// Supabase reads { error: { http_code, message } } and shows the message to the app
const fail = (status: number, message: string) =>
  new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });

async function send(to: string, otp: string, link: string, action: string) {
  const time = new Date(Date.now() + VALID_MINUTES * 60_000).toLocaleTimeString("en-PH", {
    timeZone: "Asia/Manila", hour: "numeric", minute: "2-digit",
  });
  const res = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      service_id: SERVICE_ID,
      template_id: TEMPLATE_ID,
      user_id: PUBLIC_KEY,
      ...(PRIVATE_KEY ? { accessToken: PRIVATE_KEY } : {}),
      template_params: { to_email: to, otp, time, link, subject: SUBJECTS[action] ?? "Your Macrotel code" },
    }),
  });
  if (!res.ok) throw new Error(`EmailJS ${res.status}: ${await res.text()}`);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail(405, "Method not allowed");
  if (!HOOK_SECRET) return fail(500, "SEND_EMAIL_HOOK_SECRET is not set");

  const body = await req.text();
  let payload: HookPayload;
  try {
    payload = new Webhook(HOOK_SECRET).verify(body, Object.fromEntries(req.headers)) as HookPayload;
  } catch (e) {
    console.error("Hook signature check failed:", (e as Error).message);
    return fail(401, "Invalid hook signature");
  }

  const { user, email_data: d } = payload;
  const verifyLink = (hash: string) =>
    `${SUPABASE_URL}/auth/v1/verify?token=${hash}&type=${d.email_action_type}` +
    `&redirect_to=${encodeURIComponent(d.redirect_to || d.site_url)}`;

  try {
    if (d.email_action_type === "email_change" && user.new_email && d.token_hash_new) {
      // Secure email change sends one email to each address
      await send(user.email, d.token, verifyLink(d.token_hash_new), d.email_action_type);
      await send(user.new_email, d.token_new ?? d.token, verifyLink(d.token_hash), d.email_action_type);
    } else {
      await send(user.email, d.token, verifyLink(d.token_hash), d.email_action_type);
    }
  } catch (e) {
    console.error(e);
    return fail(502, "We couldn't send the email. Please try again in a minute.");
  }
  return new Response("{}", { headers: { "Content-Type": "application/json" } });
});
