"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import type { Session } from "@supabase/supabase-js";
import { needsPassword, readLinkError } from "@/lib/auth";
import { supabase } from "@/lib/supabase";
import type { Profile } from "@/lib/types";

type AuthState = {
  session: Session | null;
  profile: Profile | null;
  loading: boolean;
  /** True until we've looked up the signed-in person's profile (or found there isn't one) */
  profileLoading: boolean;
  isStaff: boolean;
  /** True after a "Forgot password?" link signed the guest in: they should choose a new password */
  recovering: boolean;
  /** Set when the page was opened from an email link that expired or was already used */
  linkError: string | null;
  /** Hides linkError once the guest has moved on (tried again or signed in) */
  dismissLinkError: () => void;
  refreshProfile: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

// Read when this module first loads in the browser, before the Supabase client starts and
// tidies the address bar. Only the sign-in page shows it, and that page renders in the browser.
const initialLinkError = readLinkError();

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileFor, setProfileFor] = useState<string | null>(null);
  const [recovering, setRecovering] = useState(false);
  const [linkError, setLinkError] = useState(initialLinkError);
  const router = useRouter();
  const pathname = usePathname();

  async function loadProfile(s: Session | null) {
    if (!s) {
      setProfile(null);
      return;
    }
    const { data } = await supabase()
      .from("profiles")
      .select("id, full_name, phone, role")
      .eq("id", s.user.id)
      .maybeSingle();
    setProfile((data as Profile) ?? null);
    setProfileFor(s.user.id);
  }

  useEffect(() => {
    // onAuthStateChange also fires INITIAL_SESSION with the stored session (or the one
    // in an email link), so this one listener covers page load, sign-in and sign-out.
    const { data: sub } = supabase().auth.onAuthStateChange((event, s) => {
      setSession(s);
      setLoading(false);
      if (event === "PASSWORD_RECOVERY") setRecovering(true);
      // New password saved, or signed out: the reset is over
      if (event === "USER_UPDATED" || event === "SIGNED_OUT") setRecovering(false);
      if (event === "SIGNED_IN") setLinkError(null);
      // Run outside the auth callback, as Supabase recommends. After a sign-in, first apply
      // any waiting staff invite (the database checks the person signed in from their inbox).
      setTimeout(async () => {
        if (event === "SIGNED_IN" && s) await supabase().rpc("claim_staff_invite");
        loadProfile(s);
        // Signed in from an email with no password yet: offer one right away, once per session,
        // so the next sign-in is just email and password instead of another email
        if (event === "SIGNED_IN" && s && needsPassword(s) && window.location.pathname !== "/password") {
          const key = `pw-offered:${s.user.id}`;
          try {
            if (sessionStorage.getItem(key)) return;
            sessionStorage.setItem(key, "1");
          } catch {}
          const back = window.location.pathname === "/login"
            ? new URLSearchParams(window.location.search).get("next") ?? "/bookings"
            : window.location.pathname + window.location.search;
          router.replace(`/password?then=${encodeURIComponent(back)}`);
        }
      }, 0);
    });
    return () => sub.subscription.unsubscribe();
  }, [router]);

  // A reset link can land on any page; send the guest to choose a new password
  useEffect(() => {
    if (recovering && pathname !== "/password") router.replace("/password");
  }, [recovering, pathname, router]);

  const value: AuthState = {
    session,
    profile,
    loading,
    profileLoading: Boolean(session && profileFor !== session.user.id),
    isStaff: profile?.role === "admin",
    recovering,
    linkError,
    dismissLinkError: () => setLinkError(null),
    refreshProfile: () => loadProfile(session),
  };

  return <AuthContext value={value}>{children}</AuthContext>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
