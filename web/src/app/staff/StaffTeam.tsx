"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import { useAuth } from "@/components/AuthProvider";
import { Notice, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { niceDate } from "@/lib/format";

// Everyone on the team is an admin: they can see and manage every reservation.
type Member = {
  user_id: string | null; email: string; full_name: string | null;
  status: "active" | "invited"; last_sign_in: string | null; added_at: string;
};

export function TeamTab() {
  const { session } = useAuth();
  const myEmail = session?.user.email?.toLowerCase();
  const [members, setMembers] = useState<Member[] | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [form, setForm] = useState({ email: "", name: "" });

  const load = useCallback(() => {
    supabase().rpc("list_staff").then(({ data, error }) => {
      if (error) setError(error.message);
      else setMembers((data as Member[]) ?? []);
    });
  }, []);
  useEffect(load, [load]);

  // role "admin" adds someone; role "guest" takes their access away
  async function setAccess(email: string, role: "admin" | "guest", name?: string): Promise<boolean> {
    setBusy(email);
    setError("");
    setNotice("");
    const { data, error } = await supabase().rpc("set_staff_role", { p_email: email, p_role: role, p_full_name: name ?? null });
    setBusy(null);
    setConfirmRemove(null);
    if (error) {
      setError(error.message);
      return false;
    }
    const status = (data as { status: string }).status;
    setNotice(
      status === "invited"
        ? `${email} is added. To get access they sign in on the website with “Email me a sign-in link”, which proves the address is theirs.`
        : status === "removed"
          ? `${email} no longer has access to the staff portal.`
          : `${email} now has access to the staff portal.`,
    );
    load();
    return true;
  }

  async function add(e: FormEvent) {
    e.preventDefault();
    // Keep what was typed if it didn't work, so it can be fixed and sent again
    if (await setAccess(form.email.trim(), "admin", form.name.trim())) setForm({ email: "", name: "" });
  }

  return (
    <div className="grid gap-10">
      {error && <Notice tone="error">{error}</Notice>}
      {notice && <Notice tone="good">{notice}</Notice>}

      <section>
        <h2 className="mb-3 text-xl font-semibold">Add someone</h2>
        <form onSubmit={add} className="card grid gap-4 p-5 sm:grid-cols-[1.4fr_1fr_auto] sm:items-end sm:p-6">
          <div>
            <label className="label" htmlFor="t-email">Email</label>
            <input id="t-email" type="email" required className="field" value={form.email} autoComplete="off"
              onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="name@example.com" />
          </div>
          <div>
            <label className="label" htmlFor="t-name">Name (optional)</label>
            <input id="t-name" className="field" value={form.name} autoComplete="off" onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <button className="btn-primary" disabled={busy !== null}>{busy === form.email.trim() ? "Adding…" : "Add"}</button>
          <p className="text-sm text-muted sm:col-span-3">
            They sign in on the website with this email: the first time with an emailed link, then they can set a password.
          </p>
        </form>
      </section>

      <section>
        <h2 className="mb-3 flex items-baseline gap-2 text-xl font-semibold">
          Team <span className="text-base font-normal text-muted tabular-nums">{members?.length ?? ""}</span>
        </h2>
        {!members ? (
          error ? null : <Spinner />
        ) : members.length === 0 ? (
          <p className="rounded-xl border border-dashed border-line px-4 py-6 text-sm text-muted">Nobody yet. Add the first person above.</p>
        ) : (
          <ul className="card divide-y divide-line">
            {members.map((m) => {
              const me = m.email.toLowerCase() === myEmail;
              return (
                <li key={m.email} className="flex flex-wrap items-center justify-between gap-3 p-4 sm:p-5">
                  <div className="min-w-0">
                    <p className="flex flex-wrap items-center gap-2 font-semibold">
                      <span className="truncate">{m.full_name || m.email}</span>
                      {me && <span className="rounded-full bg-sea-tint px-2 py-0.5 text-xs font-semibold text-sea">You</span>}
                      {m.status === "invited" && <span className="rounded-full bg-sun-tint px-2 py-0.5 text-xs font-semibold text-sun">Waiting for email sign-in</span>}
                    </p>
                    {m.full_name && <p className="truncate text-sm text-muted">{m.email}</p>}
                    <p className="text-xs text-muted">
                      {m.status === "invited"
                        ? `Added ${niceDate(m.added_at.slice(0, 10), true)}`
                        : m.last_sign_in ? `Last signed in ${niceDate(m.last_sign_in.slice(0, 10), true)}` : "Has not signed in"}
                    </p>
                  </div>
                  {me ? (
                    <span className="text-xs text-muted">Another admin can remove you</span>
                  ) : confirmRemove === m.email ? (
                    <span className="flex items-center gap-2">
                      <button className="btn-danger px-3! py-1.5! text-sm" disabled={busy === m.email} onClick={() => setAccess(m.email, "guest")}>Remove access</button>
                      <button className="text-sm text-muted hover:text-ink" onClick={() => setConfirmRemove(null)}>Keep</button>
                    </span>
                  ) : (
                    <button className="text-sm font-medium text-bad hover:underline" onClick={() => setConfirmRemove(m.email)}>Remove</button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
        <p className="mt-3 text-sm text-muted">Removing someone keeps their account as a guest, so their own bookings stay in My stays.</p>
      </section>
    </div>
  );
}
