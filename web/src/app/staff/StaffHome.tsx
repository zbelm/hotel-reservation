"use client";

import Link from "next/link";
import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { BookingBadge, Notice, RoomBadge, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { addDays, money, niceDate, nightsBetween, plural, roomStatusLabel, todayManila } from "@/lib/format";
import { useToday } from "@/lib/useToday";
import { arrivalLabel } from "@/lib/hotel";
import { BOOKING_SELECT, type Booking, type Room, type RoomStatus } from "@/lib/types";
import { currentTab, type TabKey } from "./StaffShell";
import { CalendarTab, DashboardTab, ReviewsTab } from "./StaffInsights";
import { TeamTab } from "./StaffTeam";

const HEADINGS: Record<TabKey, [string, string]> = {
  today: ["Today", "Who arrives, who leaves, and who is in house."],
  calendar: ["Room calendar", "Two weeks of bookings by room. Open a bar to see the booking."],
  find: ["Find a booking", "Search by booking code, guest name or email."],
  walkin: ["New booking", "For walk-ins and phone bookings. These are confirmed straight away; take payment at the desk."],
  rooms: ["Rooms", "Set each room's housekeeping status. Rooms become dirty automatically at check-out."],
  dashboard: ["Dashboard", "Occupancy, revenue and bookings for a date range."],
  reviews: ["Reviews", "What guests wrote after their stay."],
  team: ["Team", "Who can use the staff portal, and what each person can do."],
};

export function StaffHome() {
  const { profile } = useAuth();
  const params = useSearchParams();
  const role = profile?.role;
  const tab = currentTab(role, params.get("tab"));
  if (!tab) return null;
  const [title, intro] = HEADINGS[tab];
  const isManager = role === "manager" || role === "admin";

  return (
    <>
      <div className="mb-8">
        <h1 className="text-3xl font-semibold sm:text-4xl">{title}</h1>
        <p className="mt-2 max-w-2xl text-muted">{intro}</p>
      </div>
      {tab === "today" && <Today />}
      {tab === "calendar" && <CalendarTab />}
      {tab === "find" && <FindBooking />}
      {tab === "walkin" && <WalkIn />}
      {tab === "rooms" && <RoomBoard />}
      {tab === "dashboard" && <DashboardTab />}
      {tab === "reviews" && <ReviewsTab canModerate={isManager} />}
      {tab === "team" && <TeamTab />}
    </>
  );
}

// --------------------------------------------------------------------------
// Today
// --------------------------------------------------------------------------
function Today() {
  const [data, setData] = useState<{ arrivals: Booking[]; inHouse: Booking[]; dirty: number } | null>(null);
  const [error, setError] = useState("");
  const today = todayManila();

  useEffect(() => {
    const sb = supabase();
    Promise.all([
      sb.from("bookings").select(BOOKING_SELECT).eq("check_in", today).in("status", ["confirmed", "checked_in"]).order("guest_name"),
      sb.from("bookings").select(BOOKING_SELECT).eq("status", "checked_in").order("check_out"),
      sb.from("rooms").select("id", { count: "exact", head: true }).eq("status", "dirty"),
    ]).then(([a, h, r]) => {
      if (a.error || h.error) setError((a.error ?? h.error)!.message);
      else setData({ arrivals: (a.data as Booking[]) ?? [], inHouse: (h.data as Booking[]) ?? [], dirty: r.count ?? 0 });
    });
  }, [today]);

  if (error) return <Notice tone="error">{error}</Notice>;
  if (!data) return <Spinner />;

  const waiting = data.arrivals.filter((b) => b.status === "confirmed");
  const departures = data.inHouse.filter((b) => b.check_out <= today);
  const staying = data.inHouse.filter((b) => b.check_out > today);

  return (
    <div className="grid gap-10">
      <div className="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-line bg-line lg:grid-cols-4">
        <Stat label="To check in" value={waiting.length} note={`of ${data.arrivals.length} arriving today`} href="#arrivals" />
        <Stat label="To check out" value={departures.length} note="due out today" href="#departures" />
        <Stat label="Staying on" value={staying.length} note="in house tonight" href="#in-house" />
        <Stat label="Rooms to clean" value={data.dirty} note="marked dirty" href="/staff?tab=rooms" />
      </div>
      <BookingList id="arrivals" title={`Arriving ${niceDate(today)}`} rows={data.arrivals} today={today}
        empty="Nobody is due to arrive today." />
      <BookingList id="departures" title="Leaving today" rows={departures} today={today}
        empty="No departures due today." />
      <BookingList id="in-house" title="Staying on" rows={staying} today={today}
        empty="No other guests are checked in." />
    </div>
  );
}

function Stat({ label, value, note, href }: { label: string; value: number; note: string; href: string }) {
  return (
    <Link href={href} className="bg-paper p-4 transition-colors hover:bg-sea-tint sm:p-5">
      <p className="text-sm font-medium text-muted">{label}</p>
      <p className="mt-1 font-display text-4xl font-semibold tabular-nums">{value}</p>
      <p className="mt-1 text-xs text-muted">{note}</p>
    </Link>
  );
}

/** The next step for this booking at the desk, if there is one today. */
function nextStep(b: Booking, today: string): string | null {
  if (b.status === "confirmed" && b.check_in <= today) return "Check in";
  if (b.status === "checked_in" && b.check_out <= today) return "Check out";
  return null;
}

function BookingList({ id, title, rows, empty, today }: { id?: string; title: ReactNode; rows: Booking[]; empty: string; today: string }) {
  return (
    <section id={id} className="scroll-mt-24">
      <h2 className="mb-3 flex items-baseline gap-2 text-xl font-semibold">
        {title} <span className="text-base font-normal text-muted tabular-nums">{rows.length}</span>
      </h2>
      {rows.length === 0 ? (
        <p className="rounded-xl border border-dashed border-line px-4 py-6 text-sm text-muted">{empty}</p>
      ) : (
        <>
          {/* Phones: one card per booking */}
          <ul className="grid gap-3 md:hidden">
            {rows.map((b) => {
              const br = b.booking_rooms?.[0];
              const balance = Number(b.total) - Number(b.amount_paid);
              const step = nextStep(b, today);
              return (
                <li key={b.id}>
                  <Link href={`/staff/booking?id=${b.id}`} className="card block p-4 transition-colors hover:border-sea">
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="truncate font-semibold">{b.guest_name}</p>
                        <p className="text-sm text-muted">{br?.rooms?.number ? `Room ${br.rooms.number} · ` : ""}{br?.room_types?.name}</p>
                      </div>
                      <BookingBadge status={b.status} />
                    </div>
                    <p className="mt-2 text-sm">{niceDate(b.check_in)} – {niceDate(b.check_out)} · <span className="font-mono">{b.code}</span></p>
                    <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-sm">
                      <span className="text-muted">Arriving {arrivalLabel(b.arrival_time)?.toLowerCase() ?? "time not given"}</span>
                      {balance > 0 && <span className="font-semibold text-sun">{money(balance)} to pay</span>}
                    </div>
                    {step && <span className="btn-primary mt-3 w-full">{step}</span>}
                  </Link>
                </li>
              );
            })}
          </ul>

          {/* Wider screens: a table */}
          <div className="card hidden overflow-x-auto md:block">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-line text-xs font-medium text-muted">
                <tr>
                  <th className="px-4 py-3">Guest</th><th className="px-4 py-3">Room</th><th className="px-4 py-3">Dates</th>
                  <th className="px-4 py-3">Arriving</th><th className="px-4 py-3">Balance</th><th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3"><span className="sr-only">Action</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {rows.map((b) => {
                  const br = b.booking_rooms?.[0];
                  const balance = Number(b.total) - Number(b.amount_paid);
                  const step = nextStep(b, today);
                  return (
                    <tr key={b.id} className="hover:bg-sand/60">
                      <td className="px-4 py-3">
                        <Link href={`/staff/booking?id=${b.id}`} className="font-medium text-sea hover:underline">{b.guest_name}</Link>
                        <p className="font-mono text-xs text-muted">{b.code}</p>
                      </td>
                      <td className="px-4 py-3">{br?.rooms?.number ? <strong className="font-semibold">{br.rooms.number} </strong> : null}<span className="text-muted">{br?.room_types?.name}</span></td>
                      <td className="whitespace-nowrap px-4 py-3">{niceDate(b.check_in)} – {niceDate(b.check_out)}<p className="text-xs text-muted">{plural(nightsBetween(b.check_in, b.check_out), "night")}</p></td>
                      <td className="whitespace-nowrap px-4 py-3 text-muted">{arrivalLabel(b.arrival_time) ?? "Not given"}</td>
                      <td className={`whitespace-nowrap px-4 py-3 tabular-nums ${balance > 0 ? "font-semibold text-sun" : "text-muted"}`}>{balance > 0 ? money(balance) : "Paid"}</td>
                      <td className="px-4 py-3"><BookingBadge status={b.status} /></td>
                      <td className="px-4 py-3 text-right">
                        <Link href={`/staff/booking?id=${b.id}`} className={step ? "btn-primary px-3.5! py-1.5! text-sm" : "text-sm font-medium text-sea hover:underline"}>
                          {step ?? "Open"}
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </>
      )}
    </section>
  );
}

// --------------------------------------------------------------------------
// Rooms (housekeeping)
// --------------------------------------------------------------------------
const NEXT_STATUS: Partial<Record<RoomStatus, { to: RoomStatus; label: string }>> = {
  dirty: { to: "cleaning", label: "Start cleaning" },
  cleaning: { to: "vacant_clean", label: "Mark clean" },
  out_of_order: { to: "dirty", label: "Back in service" },
};
const SETTABLE: RoomStatus[] = ["vacant_clean", "dirty", "cleaning", "out_of_order"];
const ROOM_EDGE: Record<RoomStatus, string> = {
  vacant_clean: "border-l-good",
  dirty: "border-l-sun",
  cleaning: "border-l-sea",
  occupied: "border-l-bay",
  out_of_order: "border-l-bad",
};

function RoomBoard() {
  const [rooms, setRooms] = useState<Room[] | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [filter, setFilter] = useState<RoomStatus | "all">("all");

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
    setBusy(room.id);
    const { error } = await supabase().rpc("set_room_status", { p_room_id: room.id, p_status: status });
    setBusy(null);
    if (error) setError(error.message);
    load();
  }

  if (!rooms) return error ? <Notice tone="error">{error}</Notice> : <Spinner />;

  const counts = rooms.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.status]: (acc[r.status] ?? 0) + 1 }), {});
  const shown = filter === "all" ? rooms : rooms.filter((r) => r.status === filter);
  const floors = [...new Set(shown.map((r) => r.floor ?? 0))].sort();
  const filters: (RoomStatus | "all")[] = ["all", "dirty", "cleaning", "vacant_clean", "occupied", "out_of_order"];

  return (
    <div className="grid gap-6">
      {error && <Notice tone="error">{error}</Notice>}
      <div className="flex flex-wrap gap-2" role="group" aria-label="Show rooms">
        {filters.map((f) => (
          <button key={f} onClick={() => setFilter(f)} aria-pressed={filter === f}
            className={`inline-flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors ${filter === f ? "border-bay bg-bay text-on-bay" : "border-line bg-paper hover:border-sea"}`}>
            {f === "all" ? "All rooms" : roomStatusLabel[f]}
            <span className={`tabular-nums ${filter === f ? "text-on-bay-muted" : "text-muted"}`}>{f === "all" ? rooms.length : counts[f] ?? 0}</span>
          </button>
        ))}
      </div>
      {shown.length === 0 && <p className="rounded-xl border border-dashed border-line px-4 py-6 text-sm text-muted">No rooms with this status.</p>}
      {floors.map((f) => (
        <section key={f}>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-[0.12em] text-muted">Floor {f}</h2>
          <div className="grid grid-cols-1 gap-3 min-[420px]:grid-cols-2 xl:grid-cols-4">
            {shown.filter((r) => (r.floor ?? 0) === f).map((r) => {
              const next = NEXT_STATUS[r.status];
              return (
                <div key={r.id} className={`card border-l-4 p-4 ${ROOM_EDGE[r.status]}`}>
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <p className="font-display text-2xl font-semibold leading-none">{r.number}</p>
                      <p className="mt-1 text-xs text-muted">{r.room_types?.name}</p>
                    </div>
                    <RoomBadge status={r.status} />
                  </div>
                  {r.status === "occupied" ? (
                    <p className="mt-4 text-sm text-muted">Guest in room. It becomes dirty at check-out.</p>
                  ) : (
                    <div className="mt-4 grid gap-2">
                      {next && (
                        <button className="btn-primary py-2! text-sm" disabled={busy === r.id} onClick={() => setStatus(r, next.to)}>
                          {busy === r.id ? "Saving…" : next.label}
                        </button>
                      )}
                      <select aria-label={`Status of room ${r.number}`} className="field py-1.5! text-sm" value={r.status} disabled={busy === r.id}
                        onChange={(e) => setStatus(r, e.target.value as RoomStatus)}>
                        {SETTABLE.map((s) => <option key={s} value={s}>{roomStatusLabel[s]}</option>)}
                      </select>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}

// --------------------------------------------------------------------------
// Find a booking
// --------------------------------------------------------------------------
function FindBooking() {
  const [q, setQ] = useState("");
  const [result, setResult] = useState<{ term: string; rows: Booking[] } | null>(null);
  const [recent, setRecent] = useState<Booking[] | null>(null);
  const [error, setError] = useState("");
  const today = todayManila();

  // Before searching, show the latest bookings so the page is useful straight away
  useEffect(() => {
    supabase().from("bookings").select(BOOKING_SELECT).neq("status", "expired")
      .order("created_at", { ascending: false }).limit(15)
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setRecent((data as Booking[]) ?? []);
      });
  }, []);

  async function search(e: FormEvent) {
    e.preventDefault();
    const term = q.trim().replace(/[%,()]/g, "");
    if (!term) return setResult(null);
    const { data, error } = await supabase().from("bookings").select(BOOKING_SELECT)
      .or(`code.ilike.%${term}%,guest_name.ilike.%${term}%,guest_email.ilike.%${term}%`)
      .neq("status", "expired")
      .order("check_in", { ascending: false }).limit(30);
    if (error) setError(error.message);
    else setResult({ term, rows: (data as Booking[]) ?? [] });
  }

  return (
    <div className="grid gap-8">
      <form onSubmit={search} className="flex flex-col gap-3 sm:flex-row" role="search">
        <label htmlFor="find-q" className="sr-only">Booking code, guest name or email</label>
        <input id="find-q" className="field" placeholder="Booking code, guest name or email" value={q} onChange={(e) => setQ(e.target.value)} autoFocus />
        <button className="btn-primary shrink-0">Search</button>
      </form>
      {error && <Notice tone="error">{error}</Notice>}
      {result ? (
        <BookingList title={`Results for “${result.term}”`} rows={result.rows} today={today} empty="No bookings match. Try part of the name, or the code from the guest's confirmation." />
      ) : recent ? (
        <BookingList title="Latest bookings" rows={recent} today={today} empty="No bookings yet." />
      ) : (
        <Spinner />
      )}
    </div>
  );
}

// --------------------------------------------------------------------------
// New booking (walk-in or phone)
// --------------------------------------------------------------------------
type Offer = {
  rate_plan_id: string; name: string; refundable: boolean; free_cancel_hours: number; includes_breakfast: boolean;
  min_stay: number; bookable: boolean; total: number; available: number;
};

function WalkIn() {
  const router = useRouter();
  const today = useToday();
  const [types, setTypes] = useState<{ id: string; name: string; max_adults: number; max_children: number }[]>([]);
  const [form, setForm] = useState({ type: "", plan: "", checkIn: "", checkOut: "", adults: 2, children: 0, name: "", email: "", phone: "", requests: "" });
  const [offers, setOffers] = useState<{ key: string; list: Offer[] } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const checkIn = form.checkIn || today;
  const checkOut = form.checkOut || (checkIn ? addDays(checkIn, 1) : "");
  const datesOk = Boolean(checkIn && checkOut && checkOut > checkIn);
  const offerKey = `${form.type}|${checkIn}|${checkOut}`;

  useEffect(() => {
    supabase().from("room_types").select("id, name, max_adults, max_children").eq("is_active", true).order("sort_order")
      .then(({ data }) => {
        setTypes(data ?? []);
        if (data?.[0]) setForm((f) => ({ ...f, type: f.type || data[0].id }));
      });
  }, []);

  // Live prices and rooms left for the chosen room type and dates
  useEffect(() => {
    if (!form.type || !datesOk) return;
    let active = true;
    supabase().rpc("room_type_offers", { p_room_type_id: form.type, p_check_in: checkIn, p_check_out: checkOut })
      .then(({ data, error }) => {
        if (!active) return;
        if (error) return setError(error.message);
        const list = (data as Offer[]) ?? [];
        setOffers({ key: offerKey, list });
        setForm((f) => ({ ...f, plan: list.find((o) => o.rate_plan_id === f.plan && o.bookable)?.rate_plan_id ?? list.find((o) => o.bookable)?.rate_plan_id ?? "" }));
      });
    return () => { active = false; };
  }, [form.type, checkIn, checkOut, datesOk, offerKey]);

  const set = (k: keyof typeof form) => (e: { target: { value: string } }) =>
    setForm((f) => ({ ...f, [k]: k === "adults" || k === "children" ? Number(e.target.value) : e.target.value }));

  const type = types.find((t) => t.id === form.type);
  const list = offers?.key === offerKey ? offers.list : null;
  const chosen = list?.find((o) => o.rate_plan_id === form.plan);
  const tooMany = type && (form.adults > type.max_adults || form.children > type.max_children);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!chosen) return;
    setBusy(true);
    setError("");
    const { data, error } = await supabase().rpc("create_booking", {
      p_room_type_id: form.type, p_rate_plan_id: form.plan, p_check_in: checkIn, p_check_out: checkOut,
      p_adults: form.adults, p_children: form.children, p_guest_name: form.name.trim(),
      p_guest_email: form.email.trim() || "walk-in@hotel.local", p_guest_phone: form.phone.trim(),
      p_special_requests: form.requests.trim(), p_source: "front_desk",
    });
    setBusy(false);
    if (error) return setError(error.message);
    router.push(`/staff/booking?id=${data.id}`);
  }

  return (
    <form onSubmit={submit} className="grid max-w-3xl gap-8">
      <fieldset className="card grid gap-4 p-5 sm:grid-cols-2 sm:p-6">
        <legend className="sr-only">Stay</legend>
        <div className="sm:col-span-2"><label className="label" htmlFor="w-type">Room type</label>
          <select id="w-type" className="field" value={form.type} onChange={set("type")}>{types.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
        <div><label className="label" htmlFor="w-in">Check-in</label><input id="w-in" type="date" className="field" min={today} value={checkIn} onChange={set("checkIn")} required /></div>
        <div><label className="label" htmlFor="w-out">Check-out</label><input id="w-out" type="date" className="field" min={checkIn ? addDays(checkIn, 1) : undefined} value={checkOut} onChange={set("checkOut")} required /></div>
        <div><label className="label" htmlFor="w-ad">Adults</label><input id="w-ad" type="number" min={1} max={6} className="field" value={form.adults} onChange={set("adults")} /></div>
        <div><label className="label" htmlFor="w-ch">Children</label><input id="w-ch" type="number" min={0} max={4} className="field" value={form.children} onChange={set("children")} /></div>
        {tooMany && type && (
          <div className="sm:col-span-2"><Notice tone="warn">{type.name} fits up to {type.max_adults} adults and {type.max_children} children.</Notice></div>
        )}
      </fieldset>

      <fieldset>
        <legend className="mb-3 text-xl font-semibold">Rate {datesOk && <span className="text-base font-normal text-muted">· {plural(nightsBetween(checkIn, checkOut), "night")}</span>}</legend>
        {!datesOk ? (
          <p className="text-sm text-muted">Choose a check-out after the check-in date.</p>
        ) : !list ? (
          <Spinner label="Checking rooms" />
        ) : list.length === 0 ? (
          <Notice>No rates are open for this room type.</Notice>
        ) : (
          <div className="grid gap-3">
            {list.map((o) => (
              <label key={o.rate_plan_id}
                className={`card flex cursor-pointer items-center gap-4 p-4 transition-colors has-[:checked]:border-sea has-[:checked]:bg-sea-tint ${o.bookable ? "" : "cursor-not-allowed opacity-60"}`}>
                <input type="radio" name="plan" value={o.rate_plan_id} checked={form.plan === o.rate_plan_id} disabled={!o.bookable}
                  onChange={() => setForm((f) => ({ ...f, plan: o.rate_plan_id }))} className="h-4 w-4 accent-[var(--sea)]" />
                <span className="min-w-0 flex-1">
                  <span className="block font-semibold">{o.name}</span>
                  <span className="block text-sm text-muted">
                    {o.refundable ? `Free cancellation until ${o.free_cancel_hours}h before` : "Non-refundable"}
                    {o.includes_breakfast ? " · breakfast included" : ""}
                  </span>
                </span>
                <span className="text-right">
                  <span className="block font-display text-xl font-semibold tabular-nums">{money(o.total)}</span>
                  <span className={`block text-xs ${o.available < 1 ? "font-semibold text-bad" : o.available <= 2 ? "font-semibold text-sun" : "text-muted"}`}>
                    {o.available < 1 ? "Sold out" : !o.bookable ? `Needs ${o.min_stay}+ nights` : `${o.available} left`}
                  </span>
                </span>
              </label>
            ))}
          </div>
        )}
      </fieldset>

      <fieldset className="card grid gap-4 p-5 sm:grid-cols-2 sm:p-6">
        <legend className="sr-only">Guest</legend>
        <div className="sm:col-span-2"><label className="label" htmlFor="w-name">Guest name</label><input id="w-name" className="field" value={form.name} onChange={set("name")} required autoComplete="off" /></div>
        <div><label className="label" htmlFor="w-email">Email (optional)</label><input id="w-email" type="email" className="field" value={form.email} onChange={set("email")} autoComplete="off" /></div>
        <div><label className="label" htmlFor="w-phone">Mobile (optional)</label><input id="w-phone" className="field" value={form.phone} onChange={set("phone")} autoComplete="off" /></div>
        <div className="sm:col-span-2"><label className="label" htmlFor="w-req">Requests (optional)</label><input id="w-req" className="field" value={form.requests} onChange={set("requests")} placeholder="High floor, extra towels…" /></div>
      </fieldset>

      {error && <Notice tone="error">{error}</Notice>}
      <div className="flex flex-wrap items-center gap-4">
        <button className="btn-primary" disabled={busy || !chosen || Boolean(tooMany)}>
          {busy ? "Booking…" : chosen ? `Confirm booking · ${money(chosen.total)}` : "Confirm booking"}
        </button>
        <p className="text-sm text-muted">Payment is recorded on the next page.</p>
      </div>
    </form>
  );
}
