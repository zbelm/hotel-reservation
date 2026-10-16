import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";

// Shortest password Supabase Auth accepts for this project (Authentication → Policies)
export const MIN_PASSWORD = 8;

/**
 * Reads the error Supabase puts on the address when an email link has expired, was
 * already used, or was opened in another browser (in the #hash or the ?query).
 * Returns its description, or null when the address carries no auth error.
 */
export function readLinkError(): string | null {
  if (typeof window === "undefined") return null;
  const hash = new URLSearchParams(window.location.hash.slice(1));
  const query = new URLSearchParams(window.location.search);
  const code = hash.get("error_code") ?? query.get("error_code") ?? hash.get("error") ?? query.get("error");
  if (!code) return null;
  return hash.get("error_description") ?? query.get("error_description") ?? code;
}

/** Keeps a redirect on this site: anything else (//host, /\\host, full URLs) becomes /bookings */
export function safeNext(value: string | null): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || value.includes("\\")) return "/bookings";
  try {
    const url = new URL(value, "https://hotel.local");
    return url.origin === "https://hotel.local" ? url.pathname + url.search + url.hash : "/bookings";
  } catch {
    return "/bookings";
  }
}

const EMAIL_METHODS = ["otp", "magiclink", "email/signup", "invite"];
// Only a sign-in this recent counts as "just signed in": later SIGNED_IN events (tab focus,
// other tabs) carry the same older sign-in time and are ignored
const FRESH_SECONDS = 120;

const offeredKey = (session: Session) => `pw-offered:${session.user.id}`;

/** Called when the password offer is on screen, so later sign-in events don't show it again */
export function markPasswordOffered(session: Session) {
  try {
    localStorage.setItem(offeredKey(session), String(Math.floor(Date.now() / 1000)));
  } catch {}
}

/**
 * Where to send a guest who just signed in from an email link or code and has no password,
 * so the next sign-in is email and password instead of another email. Null when there is
 * nothing to offer, or it was already offered for this sign-in (in any tab).
 */
export async function passwordOffer(session: Session, then: string): Promise<string | null> {
  if (session.user.user_metadata?.has_password || document.visibilityState !== "visible") return null;
  const { data } = await supabase().auth.mfa.getAuthenticatorAssuranceLevel();
  const now = Date.now() / 1000;
  // Older tokens list methods as bare strings with no time; those never count as fresh
  const signIn = data?.currentAuthenticationMethods
    .filter((a) => typeof a === "object")
    .find((a) => EMAIL_METHODS.includes(a.method) && now - a.timestamp < FRESH_SECONDS);
  if (!signIn) return null;
  try {
    if (Number(localStorage.getItem(offeredKey(session))) >= signIn.timestamp) return null;
  } catch {
    return null; // can't remember the offer, so don't risk repeating it
  }
  // Accounts from before has_password existed may still have a password saved
  const { data: hasPassword } = await supabase().rpc("account_has_password");
  if (hasPassword === true) return null;
  return `/password?then=${encodeURIComponent(safeNext(then))}`;
}
