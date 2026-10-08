"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import { useAuth } from "@/components/AuthProvider";
import { Notice, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { niceDate } from "@/lib/format";
import type { Role } from "@/lib/types";
import { ROLE_LABEL } from "./StaffShell";

type Member = {
  user_id: string | null; email: string; full_name: string | null; role: Role;
  status: "active" | "invited"; last_sign_in: string | null; added_at: string;
};

const STAFF_ROLES: { value: Role; label: string; can: string }[] = [
  { value: "front_desk", label: "Front desk", can: "Bookings, check-in and check-out, payments, room calendar, reports" },
  { value: "housekeeping", label: "Housekeeping", can: "Rooms page only: mark rooms dirty, cleaning or clean" },
  { value: "manager", label: "Manager", can: "Everything front desk can do, plus hiding reviews and managing this team" },
  { value: "admin", label: "Admin", can: "Same as manager, and can make other admins" },
];

export function TeamTab() {
  const { profile, session } = useAuth();
  const isAdmin = profile?.role === "admin";
  const myEmail = session?.user.email?.toLowerCase();
  const [members, setMembers] = useState<Member[] | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [form, setForm] = useState({ email: "", name: "", role: "front_desk" as Role });

  const load = useCallback(() => {
    supabase().rpc("list_staff").then(({ data, error }) => {
      if (error) setError(error.message);
      else setMembers((data as Member[]) ?? []);
    });
  }, []);
  useEffect(load, [load]);

  async function setRole(email: string, role: Role, name?: string) {
    setBusy(email);
    setError("");
    setNotice("");
    const { data, error } = await supabase().rpc("set_staff_role", { p_email: email, p_role: role, p_full_name: name ?? null });
    setBusy(null);
    setConfirmRemove(null);
    if (error) return setError(error.message);
    const status = (data as { status: string }).status;
    setNotice(
      status === "invited"
        ? `${email} is added as ${ROLE_LABEL[role].toLowerCase()}. They get access the first time they sign in on the website with this email.`
        : status === "removed"
          ? `${email} no longer has staff access.`
          : `${email} is now ${ROLE_LABEL[role].toLowerCase()}.`,
    );
    load();
  }

  async function add(e: FormEvent) {
    e.preventDefault();
    await setRole(form.email.trim(), form.role, form.name.trim());
    setForm({ email: "", name: "", role: form.role });
  }

  const choices = STAFF_ROLES.filter((r) => isAdmin || r.value !== "admin");

  return (
    <div className="grid gap-10">
      {error && <Notice tone="error">{error}</Notice>}
      {notice && <Notice tone="good">{notice}</Notice>}

      <section>
        <h2 className="mb-3 text-xl font-semibold">Add a staff member</h2>
        <form onSubmit={add} className="card grid gap-4 p-5 sm:grid-cols-[1.3fr_1fr_0.9fr_auto] sm:items-end sm:p-6">
          <div>
            <label className="label" htmlFor="t-email">Email</label>
            <input id="t-email" type="email" required className="field" value={form.email} autoComplete="off"
              onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="name@example.com" />
          </div>
          <div>
            <label className="label" htmlFor="t-name">Name (optional)</label>
            <input id="t-name" className="field" value={form.name} autoComplete="off" onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <div>
            <label className="label" htmlFor="t-role">Role</label>
            <select id="t-role" className="field" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as Role })}>
              {choices.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
            </select>
          </div>
          <button className="btn-primary" disabled={busy !== null}>{busy === form.email.trim() ? "Adding…" : "Add"}</button>
          <p className="text-sm text-muted sm:col-span-4">
            They sign in on the website with this email (no password needed). If they already have an account, access starts right away.
          </p>
        </form>
      </section>

      <section>
        <h2 className="mb-3 flex items-baseline gap-2 text-xl font-semibold">
          Staff <span className="text-base font-normal text-muted tabular-nums">{members?.length ?? ""}</span>
        </h2>
        {!members ? (
          error ? null : <Spinner />
        ) : members.length === 0 ? (
          <p className="rounded-xl border border-dashed border-line px-4 py-6 text-sm text-muted">No staff yet. Add the first person above.</p>
        ) : (
          <ul className="card divide-y divide-line">
            {members.map((m) => {
              const me = m.email.toLowerCase() === myEmail;
              const locked = me || (m.role === "admin" && !isAdmin);
              return (
                <li key={m.email} className="grid gap-3 p-4 sm:grid-cols-[minmax(0,1fr)_12rem_auto] sm:items-center sm:p-5">
                  <div className="min-w-0">
                    <p className="flex flex-wrap items-center gap-2 font-semibold">
                      <span className="truncate">{m.full_name || m.email}</span>
                      {me && <span className="rounded-full bg-sea-tint px-2 py-0.5 text-xs font-semibold text-sea">You</span>}
                      {m.status === "invited" && <span className="rounded-full bg-sun-tint px-2 py-0.5 text-xs font-semibold text-sun">Not signed in yet</span>}
                    </p>
                    {m.full_name && <p className="truncate text-sm text-muted">{m.email}</p>}
                    <p className="text-xs text-muted">
                      {m.status === "invited"
                        ? `Added ${niceDate(m.added_at.slice(0, 10), true)}`
                        : m.last_sign_in ? `Last signed in ${niceDate(m.last_sign_in.slice(0, 10), true)}` : "Has not signed in"}
                    </p>
                  </div>
                  <div>
                    <label className="sr-only" htmlFor={`role-${m.email}`}>Role for {m.email}</label>
                    <select id={`role-${m.email}`} className="field py-2! text-sm" value={m.role} disabled={locked || busy === m.email}
                      onChange={(e) => setRole(m.email, e.target.value as Role)}>
                      {(locked ? STAFF_ROLES : choices).map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
                    </select>
                  </div>
                  <div className="flex justify-end">
                    {locked ? (
                      <span className="text-xs text-muted">{me ? "Another manager can change your role" : "Only an admin can change this"}</span>
                    ) : confirmRemove === m.email ? (
                      <span className="flex items-center gap-2">
                        <button className="btn-danger px-3! py-1.5! text-sm" disabled={busy === m.email} onClick={() => setRole(m.email, "guest")}>Remove access</button>
                        <button className="text-sm text-muted hover:text-ink" onClick={() => setConfirmRemove(null)}>Keep</button>
                      </span>
                    ) : (
                      <button className="text-sm font-medium text-bad hover:underline" onClick={() => setConfirmRemove(m.email)}>Remove</button>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section>
        <h2 className="mb-3 text-xl font-semibold">What each role can do</h2>
        <dl className="grid gap-3 sm:grid-cols-2">
          {STAFF_ROLES.map((r) => (
            <div key={r.value} className="rounded-xl border border-line bg-paper p-4">
              <dt className="font-semibold">{r.label}</dt>
              <dd className="mt-1 text-sm text-muted">{r.can}</dd>
            </div>
          ))}
        </dl>
        <p className="mt-3 text-sm text-muted">Removing someone keeps their account as a guest, so their own bookings stay in My stays.</p>
      </section>
    </div>
  );
}
