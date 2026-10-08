"use client";

import Link from "next/link";
import { useCallback, useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { BookingBadge, Notice, PageTitle, RoomBadge, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { addDays, money, niceDate, roomStatusLabel, todayManila } from "@/lib/format";
import { useToday } from "@/lib/useToday";
import { arrivalLabel } from "@/lib/hotel";
import { BOOKING_SELECT, type Booking, type Room, type RoomStatus } from "@/lib/types";
import { StaffGate } from "./StaffGate";
import { CalendarTab, DashboardTab, ReviewsTab } from "./StaffInsights";

const TABS = [
  { key: "today", label: "Today", frontDesk: true },
  { key: "calendar", label: "Room calendar", frontDesk: true },
  { key: "rooms", label: "Rooms", frontDesk: false },
  { key: "find", label: "Find booking", frontDesk: true },
  { key: "walkin", label: "Walk-in", frontDesk: true },
  { key: "dashboard", label: "Dashboard", frontDesk: true },
  { key: "reviews", label: "Reviews", frontDesk: true },
] as const;

export function StaffHome() {
  return (
    <StaffGate>
      <Dashboard />
    </StaffGate>
  );
}

function Dashboard() {
  const { profile } = useAuth();
  const params = useSearchParams();
  const router = useRouter();
  const isHousekeeping = profile?.role === "housekeeping";
  const tabs = TABS.filter((t) => !isHousekeeping || !t.frontDesk);
  const tab = (params.get("tab") ?? tabs[0].key) as (typeof TABS)[number]["key"];

  return (
    <>
      <PageTitle eyebrow={profile?.role.replace("_", " ")} title="Front office" />
      <div className="mb-8 flex gap-1 overflow-x-auto border-b border-line">
        {tabs.map((t) => (
          <button key={t.key} onClick={() => router.replace(`/staff?tab=${t.key}`)}
            className={`-mb-px whitespace-nowrap border-b-2 px-4 py-2.5 text-sm font-semibold transition-colors ${tab === t.key ? "border-sea text-sea" : "border-transparent text-muted hover:text-ink"}`}>
            {t.label}
          </button>
        ))}
      </div>
      {tab === "today" && !isHousekeeping && <Today />}
      {(tab === "rooms" || isHousekeeping) && <RoomBoard />}
      {tab === "find" && !isHousekeeping && <FindBooking />}
      {tab === "walkin" && !isHousekeeping && <WalkIn />}
      {tab === "calendar" && !isHousekeeping && <CalendarTab />}
      {tab === "dashboard" && !isHousekeeping && <DashboardTab />}
      {tab === "reviews" && !isHousekeeping && <ReviewsTab canModerate={profile?.role === "manager" || profile?.role === "admin"} />}
    </>
  );
}

// --------------------------------------------------------------------------
function Today() {
  const [data, setData] = useState<{ arrivals: Booking[]; inHouse: Booking[] } | null>(null);
  const [error, setError] = useState("");
  const today = todayManila();

  useEffect(() => {
    const sb = supabase();
    Promise.all([
      sb.from("bookings").select(BOOKING_SELECT).eq("check_in", today).in("status", ["confirmed", "checked_in"]).order("guest_name"),
      sb.from("bookings").select(BOOKING_SELECT).eq("status", "checked_in").order("check_out"),
    ]).then(([a, h]) => {
      if (a.error || h.error) setError((a.error ?? h.error)!.message);
      else setData({ arrivals: (a.data as Booking[]) ?? [], inHouse: (h.data as Booking[]) ?? [] });
    });
  }, [today]);

  if (error) return <Notice tone="error">{error}</Notice>;
  if (!data) return <Spinner />;

  const departures = data.inHouse.filter((b) => b.check_out <= today);
  const waiting = data.arrivals.filter((b) => b.status === "confirmed");

  return (
    <div className="grid gap-8">
      <div className="grid grid-cols-3 gap-3">
        <Stat label="Arrivals left" value={waiting.length} />
        <Stat label="In house" value={data.inHouse.length} />
        <Stat label="Departures" value={departures.length} />
      </div>
      <BookingTable title={`Arrivals · ${niceDate(today)}`} rows={data.arrivals} empty="No arrivals today." />
      <BookingTable title="Departures" rows={departures} empty="No departures due today." />
      <BookingTable title="In house" rows={data.inHouse} empty="No guests checked in." />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="card p-4">
      <p className="text-sm font-medium text-muted">{label}</p>
      <p className="font-display text-4xl font-semibold">{value}</p>
    </div>
  );
}

function BookingTable({ title, rows, empty }: { title: string; rows: Booking[]; empty: string }) {
  return (
    <section>
      <h2 className="mb-3 text-xl font-semibold">{title}</h2>
      {rows.length === 0 ? <p className="text-sm text-muted">{empty}</p> : (
        <div className="card overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-line text-xs font-medium text-muted">
              <tr><th className="px-4 py-3">Guest</th><th className="px-4 py-3">Code</th><th className="px-4 py-3">Room</th><th className="px-4 py-3">Dates</th><th className="px-4 py-3">Arriving</th><th className="px-4 py-3">Balance</th><th className="px-4 py-3">Status</th></tr>
            </thead>
            <tbody className="divide-y divide-line">
              {rows.map((b) => {
                const br = b.booking_rooms?.[0];
                const balance = Number(b.total) - Number(b.amount_paid);
                return (
                  <tr key={b.id} className="hover:bg-sand/60">
                    <td className="px-4 py-3 font-medium"><Link href={`/staff/booking?id=${b.id}`} className="text-sea hover:underline">{b.guest_name}</Link></td>
                    <td className="px-4 py-3 font-mono">{b.code}</td>
                    <td className="px-4 py-3">{br?.rooms?.number ? `${br.rooms.number} · ` : ""}{br?.room_types?.name}</td>
                    <td className="px-4 py-3 whitespace-nowrap">{niceDate(b.check_in)} – {niceDate(b.check_out)}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-muted">{arrivalLabel(b.arrival_time) ?? "Not given"}</td>
                    <td className={`px-4 py-3 ${balance > 0 ? "font-semibold text-sun" : "text-muted"}`}>{balance > 0 ? money(balance) : "Paid"}</td>
                    <td className="px-4 py-3"><BookingBadge status={b.status} /></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

// --------------------------------------------------------------------------
const SETTABLE: RoomStatus[] = ["vacant_clean", "dirty", "cleaning", "out_of_order"];

function RoomBoard() {
  const [rooms, setRooms] = useState<Room[] | null>(null);
  const [error, setError] = useState("");

  const load = useCallback(() => {
    supabase().from("rooms").select("id, number, floor, status, room_type_id, room_types(name)").order("number")
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setRooms((data as unknown as Room[]) ?? []);
      });
  }, []);

  useEffect(load, [load]);

  async function setStatus(room: Room, status: RoomStatus) {
    setError("");
    const { error } = await supabase().rpc("set_room_status", { p_room_id: room.id, p_status: status });
    if (error) setError(error.message);
    load();
  }

  if (!rooms) return error ? <Notice tone="error">{error}</Notice> : <Spinner />;

  const counts = rooms.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.status]: (acc[r.status] ?? 0) + 1 }), {});
  const floors = [...new Set(rooms.map((r) => r.floor ?? 0))].sort();

  return (
    <div className="grid gap-6">
      {error && <Notice tone="error">{error}</Notice>}
      <div className="flex flex-wrap gap-2 text-sm">
        {(Object.keys(roomStatusLabel) as RoomStatus[]).map((s) => (
          <span key={s} className="flex items-center gap-2"><RoomBadge status={s} /><span className="text-muted">{counts[s] ?? 0}</span></span>
        ))}
      </div>
      {floors.map((f) => (
        <section key={f}>
          <h2 className="mb-3 text-base font-semibold text-muted">Floor {f}</h2>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
            {rooms.filter((r) => (r.floor ?? 0) === f).map((r) => (
              <div key={r.id} className="card p-4">
                <div className="flex items-start justify-between">
                  <p className="font-display text-2xl font-semibold">{r.number}</p>
                  <RoomBadge status={r.status} />
                </div>
                <p className="mb-3 text-xs text-muted">{r.room_types?.name}</p>
                {r.status === "occupied" ? (
                  <p className="text-xs text-muted">Guest in room</p>
                ) : (
                  <select aria-label={`Status of room ${r.number}`} className="field py-1.5! text-sm" value={r.status}
                    onChange={(e) => setStatus(r, e.target.value as RoomStatus)}>
                    {SETTABLE.map((s) => <option key={s} value={s}>{roomStatusLabel[s]}</option>)}
                  </select>
                )}
              </div>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}

// --------------------------------------------------------------------------
function FindBooking() {
  const [q, setQ] = useState("");
  const [rows, setRows] = useState<Booking[] | null>(null);
  const [error, setError] = useState("");

  async function search(e: FormEvent) {
    e.preventDefault();
    const term = q.trim().replace(/[%,()]/g, "");
    if (!term) return;
    const { data, error } = await supabase().from("bookings").select(BOOKING_SELECT)
      .or(`code.ilike.%${term}%,guest_name.ilike.%${term}%,guest_email.ilike.%${term}%`)
      .neq("status", "expired")
      .order("check_in", { ascending: false }).limit(30);
    if (error) setError(error.message);
    else setRows((data as Booking[]) ?? []);
  }

  return (
    <div className="grid gap-6">
      <form onSubmit={search} className="flex gap-3">
        <input className="field" placeholder="Booking code, guest name or email" value={q} onChange={(e) => setQ(e.target.value)} autoFocus />
        <button className="btn-primary">Search</button>
      </form>
      {error && <Notice tone="error">{error}</Notice>}
      {rows && <BookingTable title={`${rows.length} found`} rows={rows} empty="No bookings match." />}
    </div>
  );
}

// --------------------------------------------------------------------------
type Option = { id: string; name: string };

function WalkIn() {
  const router = useRouter();
  const [types, setTypes] = useState<Option[]>([]);
  const [plans, setPlans] = useState<Option[]>([]);
  const [form, setForm] = useState({ type: "", plan: "", checkIn: "", checkOut: "", adults: 2, children: 0, name: "", email: "", phone: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const today = useToday();
  const checkIn = form.checkIn || today;
  const checkOut = form.checkOut || (checkIn ? addDays(checkIn, 1) : "");

  useEffect(() => {
    supabase().from("room_types").select("id, name").eq("is_active", true).order("sort_order")
      .then(({ data }) => {
        setTypes(data ?? []);
        if (data?.[0]) setForm((f) => ({ ...f, type: data[0].id }));
      });
  }, []);

  useEffect(() => {
    if (!form.type) return;
    supabase().from("rate_plans").select("id, name").eq("room_type_id", form.type).eq("is_active", true).order("price_multiplier")
      .then(({ data }) => {
        setPlans(data ?? []);
        setForm((f) => ({ ...f, plan: data?.[0]?.id ?? "" }));
      });
  }, [form.type]);

  const set = (k: keyof typeof form) => (e: { target: { value: string } }) =>
    setForm((f) => ({ ...f, [k]: k === "adults" || k === "children" ? Number(e.target.value) : e.target.value }));

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { data, error } = await supabase().rpc("create_booking", {
      p_room_type_id: form.type, p_rate_plan_id: form.plan, p_check_in: checkIn, p_check_out: checkOut,
      p_adults: form.adults, p_children: form.children, p_guest_name: form.name,
      p_guest_email: form.email || "walk-in@hotel.local", p_guest_phone: form.phone, p_source: "front_desk",
    });
    setBusy(false);
    if (error) return setError(error.message);
    router.push(`/staff/booking?id=${data.id}`);
  }

  return (
    <form onSubmit={submit} className="card grid max-w-2xl gap-4 p-6">
      <p className="text-sm text-muted">Walk-in and phone bookings are confirmed right away. Collect payment at the desk.</p>
      <div className="grid gap-4 sm:grid-cols-2">
        <div><label className="label" htmlFor="w-type">Room type</label>
          <select id="w-type" className="field" value={form.type} onChange={set("type")}>{types.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
        <div><label className="label" htmlFor="w-plan">Rate</label>
          <select id="w-plan" className="field" value={form.plan} onChange={set("plan")}>{plans.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
        <div><label className="label" htmlFor="w-in">Check-in</label><input id="w-in" type="date" className="field" value={checkIn} onChange={set("checkIn")} required /></div>
        <div><label className="label" htmlFor="w-out">Check-out</label><input id="w-out" type="date" className="field" value={checkOut} onChange={set("checkOut")} required /></div>
        <div><label className="label" htmlFor="w-ad">Adults</label><input id="w-ad" type="number" min={1} max={6} className="field" value={form.adults} onChange={set("adults")} /></div>
        <div><label className="label" htmlFor="w-ch">Children</label><input id="w-ch" type="number" min={0} max={4} className="field" value={form.children} onChange={set("children")} /></div>
        <div className="sm:col-span-2"><label className="label" htmlFor="w-name">Guest name</label><input id="w-name" className="field" value={form.name} onChange={set("name")} required /></div>
        <div><label className="label" htmlFor="w-email">Email (optional)</label><input id="w-email" type="email" className="field" value={form.email} onChange={set("email")} /></div>
        <div><label className="label" htmlFor="w-phone">Mobile (optional)</label><input id="w-phone" className="field" value={form.phone} onChange={set("phone")} /></div>
      </div>
      {error && <Notice tone="error">{error}</Notice>}
      <button className="btn-primary" disabled={busy || !form.plan}>{busy ? "Booking…" : "Create booking"}</button>
    </form>
  );
}
