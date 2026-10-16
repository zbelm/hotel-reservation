import type { Session } from "@supabase/supabase-js";

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

/**
 * True when this session came from an email link or code and the account has never saved a
 * password, so the guest would need another email to sign in next time.
 */
export function needsPassword(session: Session): boolean {
  if (session.user.user_metadata?.has_password) return false;
  try {
    const payload = JSON.parse(atob(session.access_token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    const methods: string[] = (payload.amr ?? []).map((a: { method?: string }) => a.method ?? "");
    return methods.some((m) => ["otp", "magiclink", "email/signup", "invite"].includes(m));
  } catch {
    return false;
  }
}
