"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { Notice } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";

// Turn on in Vercel with NEXT_PUBLIC_GOOGLE_LOGIN=1 after enabling Google in Supabase Auth → Providers
const googleEnabled = process.env.NEXT_PUBLIC_GOOGLE_LOGIN === "1";

function safeNext(value: string | null): string {
  return value && value.startsWith("/") && !value.startsWith("//") ? value : "/bookings";
}

export function Login() {
  const { t } = useT();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const router = useRouter();
  const { session } = useAuth();

  const [mode, setMode] = useState<"password" | "link">("password");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (session) router.replace(next);
  }, [session, next, router]);

  function explain(message: string) {
    if (/invalid login credentials/i.test(message)) return t.login.wrong;
    if (/rate limit|too many/i.test(message)) return t.login.tooMany;
    return message;
  }

  async function signInWithPassword(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { error } = await supabase().auth.signInWithPassword({ email: email.trim(), password });
    setBusy(false);
    if (error) setError(explain(error.message));
    // On success the auth listener updates the session and the effect above redirects
  }

  async function sendCode(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { error } = await supabase().auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: `${window.location.origin}${next}` },
    });
    setBusy(false);
    if (error) setError(explain(error.message));
    else setSent(true);
  }

  async function verify(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { error } = await supabase().auth.verifyOtp({ email: email.trim(), token: code.trim(), type: "email" });
    setBusy(false);
    if (error) setError(explain(error.message));
  }

  async function google() {
    const { error } = await supabase().auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}${next}` },
    });
    if (error) setError(error.message);
  }

  function switchTo(m: "password" | "link") {
    setMode(m);
    setSent(false);
    setCode("");
    setError("");
  }

  const emailField = (
    <div>
      <label htmlFor="email" className="label">{t.login.email}</label>
      <input id="email" type="email" className="field" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" autoFocus />
    </div>
  );

  return (
    <div className="card p-7">
      <h1 className="text-3xl font-semibold">{t.login.title}</h1>
      <p className="mt-2 text-muted">{mode === "password" ? t.login.intro : t.login.linkIntro}</p>

      {mode === "password" ? (
        <>
          <form onSubmit={signInWithPassword} className="mt-6 grid gap-4">
            {emailField}
            <div>
              <label htmlFor="password" className="label">{t.login.password}</label>
              <input id="password" type="password" className="field" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" />
            </div>
            <button className="btn-primary" disabled={busy}>{busy ? t.login.checking : t.login.signIn}</button>
          </form>
          <p className="mt-5 text-sm text-muted">
            {t.login.noPassword}{" "}
            <button type="button" className="font-semibold text-sea hover:underline" onClick={() => switchTo("link")}>{t.login.useLink}</button>
          </p>
        </>
      ) : !sent ? (
        <>
          <form onSubmit={sendCode} className="mt-6 grid gap-4">
            {emailField}
            <button className="btn-primary" disabled={busy}>{busy ? t.login.sending : t.login.send}</button>
          </form>
          <button type="button" className="mt-5 text-sm font-semibold text-sea hover:underline" onClick={() => switchTo("password")}>{t.login.backToPassword}</button>
        </>
      ) : (
        <form onSubmit={verify} className="mt-6 grid gap-4">
          <Notice>{t.login.check(email.trim())}</Notice>
          <div>
            <label htmlFor="code" className="label">{t.login.code}</label>
            <input id="code" inputMode="numeric" autoComplete="one-time-code" className="field text-center font-mono text-2xl tracking-[0.4em]"
              value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))} required autoFocus />
          </div>
          <button className="btn-primary" disabled={busy || code.length < 6}>{busy ? t.login.checking : t.login.signIn}</button>
          <button type="button" className="text-sm text-muted hover:text-ink" onClick={() => { setSent(false); setCode(""); }}>
            {t.login.other}
          </button>
        </form>
      )}

      {error && <div className="mt-4"><Notice tone="error">{error}</Notice></div>}

      {googleEnabled && (
        <>
          <div className="my-6 flex items-center gap-3 text-sm text-muted">
            <span className="h-px flex-1 bg-line" />{t.login.or}<span className="h-px flex-1 bg-line" />
          </div>
          <button className="btn-quiet w-full" onClick={google}>{t.login.google}</button>
        </>
      )}
    </div>
  );
}
