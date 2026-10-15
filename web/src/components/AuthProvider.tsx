"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import type { Profile } from "@/lib/types";

type AuthState = {
  session: Session | null;
  profile: Profile | null;
  loading: boolean;
  /** True until we've looked up the signed-in person's profile (or found there isn't one) */
  profileLoading: boolean;
  isStaff: boolean;
  refreshProfile: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileFor, setProfileFor] = useState<string | null>(null);

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
    const { data: sub } = supabase().auth.onAuthStateChange((_event, s) => {
      setSession(s);
      setLoading(false);
      // Run outside the auth callback, as Supabase recommends
      setTimeout(() => loadProfile(s), 0);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const value: AuthState = {
    session,
    profile,
    loading,
    profileLoading: Boolean(session && profileFor !== session.user.id),
    isStaff: profile?.role === "admin",
    refreshProfile: () => loadProfile(session),
  };

  return <AuthContext value={value}>{children}</AuthContext>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
