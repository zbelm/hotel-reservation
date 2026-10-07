"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { Notice } from "@/components/ui";
import { supabase } from "@/lib/supabase";

function safeNext(value: string | null): string {
  return value && value.startsWith("/") && !value.startsWith("//") ? value : "/bookings";
}

export function Login() {
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const router = useRouter();
  const { session } = useAuth();

  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (session) router.replace(next);
  }, [session, next, router]);

  async function sendCode(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { error } = await supabase().auth.signInWithOtp({
      email,
      options: { emailRedirectTo: `${window.location.origin}${next}` },
    });
    setBusy(false);
    if (error) setError(error.message);
    else setSent(true);
  }

  async function verify(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { error } = await supabase().auth.verifyOtp({ email, token: code.trim(), type: "email" });
    setBusy(false);
    if (error) setError(error.message);
    // On success the auth listener updates the session and the effect above redirects
  }

  async function google() {
    const { error } = await supabase().auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}${next}` },
    });
    if (error) setError(error.message);
  }

  return (
    <div className="card p-7">
      <h1 className="text-3xl font-semibold">Sign in</h1>
      <p className="mt-2 text-muted">No password needed. We&rsquo;ll email you a 6-digit code.</p>

      {!sent ? (
        <form onSubmit={sendCode} className="mt-6 grid gap-4">
          <div>
            <label htmlFor="email" className="label">Email</label>
            <input id="email" type="email" className="field" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" autoFocus />
          </div>
          <button className="btn-primary" disabled={busy}>{busy ? "Sending…" : "Email me a code"}</button>
        </form>
      ) : (
        <form onSubmit={verify} className="mt-6 grid gap-4">
          <Notice>We sent a code to <strong>{email}</strong>. You can also tap the link in that email.</Notice>
          <div>
            <label htmlFor="code" className="label">6-digit code</label>
            <input id="code" inputMode="numeric" autoComplete="one-time-code" className="field text-center font-mono text-2xl tracking-[0.4em]"
              value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))} required autoFocus />
          </div>
          <button className="btn-primary" disabled={busy || code.length < 6}>{busy ? "Checking…" : "Sign in"}</button>
          <button type="button" className="text-sm text-muted hover:text-ink" onClick={() => { setSent(false); setCode(""); }}>
            Use a different email
          </button>
        </form>
      )}

      {error && <div className="mt-4"><Notice tone="error">{error}</Notice></div>}

      <div className="my-6 flex items-center gap-3 text-xs uppercase tracking-wide text-muted">
        <span className="h-px flex-1 bg-line" />or<span className="h-px flex-1 bg-line" />
      </div>
      <button className="btn-quiet w-full" onClick={google}>Continue with Google</button>
    </div>
  );
}
