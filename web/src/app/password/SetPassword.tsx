"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Notice, Spinner } from "@/components/ui";
import { MIN_PASSWORD, markPasswordOffered, safeNext } from "@/lib/auth";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";
import { useRequireAuth } from "@/lib/useRequireAuth";

// Signed-in guests and staff choose a password here, so later sign-ins don't need an email.
// After a "Forgot password?" email link, AuthProvider sends the guest here to choose a new one.
export function SetPassword() {
  const { t } = useT();
  const { session, isStaff, recovering } = useRequireAuth();
  const [password, setPassword] = useState("");
  const [again, setAgain] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);
  const router = useRouter();
  // Set when we arrive straight after an email sign-in: where to carry on afterwards
  const thenParam = useSearchParams().get("then");
  const then = thenParam ? safeNext(thenParam) : null;

  useEffect(() => {
    if (session && then) markPasswordOffered(session);
  }, [session, then]);

  if (!session) return <Spinner />;

  async function save(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (password.length < MIN_PASSWORD) return setError(t.password.tooShort);
    if (password !== again) return setError(t.password.mismatch);
    setBusy(true);
    // has_password tells the site not to offer this again after an email sign-in
    const { error } = await supabase().auth.updateUser({ password, data: { has_password: true } });
    setBusy(false);
    if (error) return setError(error.message);
    if (then) return router.replace(then);
    setSaved(true);
    setPassword("");
    setAgain("");
  }

  return (
    <div className="card p-7">
      <h1 className="text-3xl font-semibold">{t.password.title}</h1>
      <p className="mt-2 text-muted">{recovering ? t.password.resetIntro : then ? t.password.offerIntro : t.password.intro}</p>
      <p className="mt-1 text-sm text-muted">{session.user.email}</p>

      {saved ? (
        <div className="mt-6 grid gap-4">
          <Notice tone="good">{t.password.saved}</Notice>
          <Link href={isStaff ? "/staff" : "/bookings"} className="btn-primary">{isStaff ? t.nav.staff : t.nav.myStays}</Link>
        </div>
      ) : (
        <form onSubmit={save} className="mt-6 grid gap-4">
          {/* Lets password managers save the pair */}
          <input type="email" value={session.user.email ?? ""} autoComplete="username" readOnly hidden />
          <div>
            <label htmlFor="new-password" className="label">{t.password.new}</label>
            <input id="new-password" type="password" className="field" value={password} onChange={(e) => setPassword(e.target.value)}
              required minLength={MIN_PASSWORD} autoComplete="new-password" autoFocus aria-describedby="pw-hint" />
            <p id="pw-hint" className="mt-1 text-sm text-muted">{t.password.hint}</p>
          </div>
          <div>
            <label htmlFor="again-password" className="label">{t.password.confirm}</label>
            <input id="again-password" type="password" className="field" value={again} onChange={(e) => setAgain(e.target.value)} required autoComplete="new-password" />
          </div>
          <button className="btn-primary" disabled={busy}>{busy ? t.password.saving : t.password.save}</button>
          {then && !recovering && (
            <Link href={then} className="justify-self-center text-sm text-muted hover:text-ink">{t.password.skip}</Link>
          )}
        </form>
      )}
      {error && <div className="mt-4"><Notice tone="error">{error}</Notice></div>}
    </div>
  );
}
