"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import type { Session } from "@supabase/supabase-js";
import { readLinkError } from "@/lib/auth";
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
      // Run outside the auth callback, as Supabase recommends
      setTimeout(() => loadProfile(s), 0);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

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
