"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { Notice } from "@/components/ui";
import { MIN_PASSWORD } from "@/lib/auth";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";

// Turn on in Vercel with NEXT_PUBLIC_GOOGLE_LOGIN=1 after enabling Google in Supabase Auth → Providers
const googleEnabled = process.env.NEXT_PUBLIC_GOOGLE_LOGIN === "1";

type Mode = "signin" | "signup" | "forgot" | "link";
// What a passwordless sign-in emails: a link to tap, or a code to type here
type Via = "link" | "code";

// Only ever return to a page on this site (blocks tricks like "//evil.com" or "/\\evil.com")
function safeNext(value: string | null): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || value.includes("\\")) return "/bookings";
  try {
    const url = new URL(value, "https://hotel.local");
    return url.origin === "https://hotel.local" ? url.pathname + url.search + url.hash : "/bookings";
  } catch {
    return "/bookings";
  }
}

export function Login() {
  const { t } = useT();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const router = useRouter();
  const { session, linkError, dismissLinkError } = useAuth();

  const [mode, setMode] = useState<Mode>(params.get("mode") === "signup" ? "signup" : "signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [via, setVia] = useState<Via>("link");
  const [code, setCode] = useState("");
  const [codeOpen, setCodeOpen] = useState(false); // chose a link, but typing the code from the same email
  const [sent, setSent] = useState<string>(""); // the confirmation message once an email has gone out
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  // Opened from an expired or used email link: say so until they try again
  const shownError = error || (linkError ? t.login.linkExpired : "");

  // Signed in (here, or from an email link): go where they were headed. This is the one
  // place that navigates after sign-in, so the handlers below only report errors.
  useEffect(() => {
    if (session) router.replace(next);
  }, [session, next, router]);

  function explain(message: string) {
    if (/invalid login credentials/i.test(message)) return t.login.wrong;
    if (/email not confirmed/i.test(message)) return t.login.unconfirmed;
    if (/already registered|already exists/i.test(message)) return t.login.exists;
    if (/rate limit|too many/i.test(message)) return t.login.tooMany;
    if (/token has expired|otp.*(expired|invalid)|invalid.*(token|otp)/i.test(message)) return t.login.codeWrong;
    return message;
  }

  // Clears what was typed for the last email, keeping the address itself
  function startOver() {
    dismissLinkError();
    setSent("");
    setCode("");
    setCodeOpen(false);
    setPassword("");
    setError("");
  }

  function switchTo(m: Mode) {
    setMode(m);
    startOver();
  }

  // Runs one auth call with the shared busy/error handling
  async function run(action: () => Promise<string | void>) {
    setBusy(true);
    setError("");
    dismissLinkError();
    try {
      const problem = await action();
      if (problem) setError(problem);
    } catch (err) {
      setError(explain(err instanceof Error ? err.message : String(err)));
    } finally {
      setBusy(false);
    }
  }

  const redirectTo = () => `${window.location.origin}${next}`;

  function signIn(e: FormEvent) {
    e.preventDefault();
    run(async () => {
      const { error } = await supabase().auth.signInWithPassword({ email: email.trim(), password });
      if (error) return explain(error.message);
    });
  }

  function signUp(e: FormEvent) {
    e.preventDefault();
    if (password.length < MIN_PASSWORD) return setError(t.login.tooShort);
    run(async () => {
      const address = email.trim();
      const { data, error } = await supabase().auth.signUp({
        email: address,
        password,
        options: { emailRedirectTo: redirectTo() },
      });
      if (error) return explain(error.message);
      // Supabase hides existing accounts by returning a user with no identities
      if (data.user && data.user.identities?.length === 0) return t.login.exists;
      // With email confirmation off there is a session already, and the effect above redirects
      if (!data.session) setSent(t.login.confirmSent(address));
    });
  }

  function sendReset(e: FormEvent) {
    e.preventDefault();
    run(async () => {
      const address = email.trim();
      const { error } = await supabase().auth.resetPasswordForEmail(address, {
        redirectTo: `${window.location.origin}/password`,
      });
      if (error) return explain(error.message);
      setSent(t.login.resetSent(address));
    });
  }

  function sendLink(e?: FormEvent) {
    e?.preventDefault();
    run(async () => {
      const address = email.trim();
      const { error } = await supabase().auth.signInWithOtp({ email: address, options: { emailRedirectTo: redirectTo() } });
      if (error) return explain(error.message);
      setCode("");
      setSent(via === "code" ? t.login.checkCode(address) : t.login.check(address));
    });
  }

  function verifyCode(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    run(async () => {
      const { error } = await supabase().auth.verifyOtp({ email: email.trim(), token: code.trim(), type: "email" });
      if (error) return explain(error.message);
    });
  }

  async function google() {
    const { error } = await supabase().auth.signInWithOAuth({ provider: "google", options: { redirectTo: redirectTo() } });
    if (error) setError(error.message);
  }

  const heading = {
    signin: [t.login.title, t.login.intro],
    signup: [t.login.signUpTitle, t.login.signUpIntro],
    forgot: [t.login.forgotTitle, t.login.forgotIntro],
    link: [t.login.title, t.login.linkIntro],
  }[mode];

  const emailField = (
    <div>
      <label htmlFor="email" className="label">{t.login.email}</label>
      <input id="email" type="email" className="field" value={email} onChange={(e) => setEmail(e.target.value)}
        required autoComplete="email" autoFocus />
    </div>
  );

  const passwordField = (isNew: boolean) => (
    <div>
      <div className="flex items-baseline justify-between">
        <label htmlFor="password" className="label">{isNew ? t.login.newPassword : t.login.password}</label>
        {!isNew && (
          <button type="button" className="text-sm font-semibold text-sea hover:underline" onClick={() => switchTo("forgot")}>
            {t.login.forgot}
          </button>
        )}
      </div>
      <div className="relative">
        <input id="password" type={showPassword ? "text" : "password"} className="field pr-20" value={password}
          onChange={(e) => setPassword(e.target.value)} required minLength={isNew ? MIN_PASSWORD : undefined}
          autoComplete={isNew ? "new-password" : "current-password"} aria-describedby={isNew ? "pw-hint" : undefined} />
        <button type="button" className="absolute inset-y-0 right-3 my-auto h-fit text-sm font-medium text-muted hover:text-ink"
          onClick={() => setShowPassword((v) => !v)} aria-pressed={showPassword}>
          {showPassword ? t.login.hide : t.login.show}
        </button>
      </div>
      {isNew && <p id="pw-hint" className="mt-1 text-sm text-muted">{t.login.passwordHint}</p>}
    </div>
  );

  return (
    <div className="card p-7">
      {(mode === "signin" || mode === "signup") && (
        <div role="tablist" className="mb-6 grid grid-cols-2 rounded-full border border-line bg-paper p-1 text-sm font-semibold">
          {(["signin", "signup"] as const).map((m) => (
            <button key={m} type="button" role="tab" aria-selected={mode === m} onClick={() => switchTo(m)}
              className={`rounded-full px-4 py-2 transition-colors ${mode === m ? "bg-sea text-paper" : "text-muted hover:text-ink"}`}>
              {m === "signin" ? t.login.tabSignIn : t.login.tabSignUp}
            </button>
          ))}
        </div>
      )}

      <h1 className="text-3xl font-semibold">{heading[0]}</h1>
      <p className="mt-2 text-muted">{heading[1]}</p>

      {sent ? (
        <div className="mt-6 grid gap-4">
          <Notice tone="good">{sent}</Notice>
          {mode === "link" && via === "link" && !codeOpen && (
            <button type="button" className="justify-self-start text-sm font-semibold text-sea hover:underline" onClick={() => setCodeOpen(true)}>
              {t.login.haveCode}
            </button>
          )}
          {mode === "link" && (via === "code" || codeOpen) && (
            <form onSubmit={verifyCode} className="grid gap-4">
              <div>
                <label htmlFor="code" className="label">{t.login.code}</label>
                <input id="code" inputMode="numeric" autoComplete="one-time-code" className="field text-center font-mono text-2xl tracking-[0.4em]"
                  value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))} required autoFocus />
              </div>
              <button className="btn-primary" disabled={busy || code.length < 6}>{busy ? t.login.checking : t.login.signIn}</button>
            </form>
          )}
          <div className="flex flex-wrap gap-x-5 gap-y-2 text-sm">
            {mode === "link" && (
              <button type="button" className="text-muted hover:text-ink disabled:opacity-60" disabled={busy} onClick={() => sendLink()}>{t.login.resend}</button>
            )}
            <button type="button" className="text-muted hover:text-ink" onClick={startOver}>{t.login.other}</button>
          </div>
        </div>
      ) : mode === "signin" ? (
        <form onSubmit={signIn} className="mt-6 grid gap-4">
          {emailField}
          {passwordField(false)}
          <button className="btn-primary" disabled={busy}>{busy ? t.login.checking : t.login.signIn}</button>
          {/* Accounts made with an email link have no password they know, so this sits right under Sign in */}
          <button type="button" className="btn-quiet" onClick={() => switchTo("link")}>{t.login.noPassword}</button>
        </form>
      ) : mode === "signup" ? (
        <form onSubmit={signUp} className="mt-6 grid gap-4">
          {emailField}
          {passwordField(true)}
          <button className="btn-primary" disabled={busy}>{busy ? t.login.creating : t.login.signUp}</button>
        </form>
      ) : mode === "forgot" ? (
        <form onSubmit={sendReset} className="mt-6 grid gap-4">
          {emailField}
          <button className="btn-primary" disabled={busy}>{busy ? t.login.sending : t.login.sendReset}</button>
        </form>
      ) : (
        <form onSubmit={sendLink} className="mt-6 grid gap-4">
          <div role="radiogroup" aria-label={t.login.linkIntro} className="grid grid-cols-2 rounded-full border border-line bg-paper p-1 text-sm font-semibold">
            {(["link", "code"] as const).map((v) => (
              <button key={v} type="button" role="radio" aria-checked={via === v} onClick={() => setVia(v)}
                className={`rounded-full px-4 py-2 transition-colors ${via === v ? "bg-sea text-paper" : "text-muted hover:text-ink"}`}>
                {v === "link" ? t.login.viaLink : t.login.viaCode}
              </button>
            ))}
          </div>
          {emailField}
          <button className="btn-primary" disabled={busy}>{busy ? t.login.sending : via === "code" ? t.login.sendCode : t.login.send}</button>
        </form>
      )}

      {shownError && <div className="mt-4"><Notice tone="error">{shownError}</Notice></div>}

      <div className="mt-5 grid justify-items-start gap-2 text-sm">
        {mode === "forgot" || mode === "link" ? (
          <button type="button" className="font-semibold text-sea hover:underline" onClick={() => switchTo("signin")}>{t.login.backToSignIn}</button>
        ) : mode === "signup" ? (
          <button type="button" className="font-semibold text-sea hover:underline" onClick={() => switchTo("link")}>{t.login.useLink}</button>
        ) : null}
      </div>

      {googleEnabled && (mode === "signin" || mode === "signup") && (
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
