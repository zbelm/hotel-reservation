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
