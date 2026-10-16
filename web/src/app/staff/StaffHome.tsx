"use client";

import Link from "next/link";
import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { BookingBadge, Notice, OccupancyBadge, RoomBadge, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { addDays, money, niceDate, nightsBetween, occupancyLabel, plural, todayManila } from "@/lib/format";
import { useToday } from "@/lib/useToday";
import { arrivalLabel } from "@/lib/hotel";
import { BOOKING_SELECT, STAFF_BOOKING_SELECT, type BoardRoom, type Booking, type Occupancy, type RoomStatus } from "@/lib/types";
import { currentTab, type TabKey } from "./StaffShell";
import { CalendarTab, DashboardTab, ReviewsTab } from "./StaffInsights";
import { TeamTab } from "./StaffTeam";

const HEADINGS: Record<TabKey, [string, string]> = {
  today: ["Today", "Who arrives today, who leaves, and who is staying tonight. Tap Guest arrived when they get here."],
  calendar: ["Calendar", "Two weeks of rooms booked per room type. Open a booking to see it."],
  find: ["Find a booking", "Search by booking code, guest name or email."],
  walkin: ["New booking", "For walk-ins and phone bookings. These are confirmed straight away; take payment at the desk."],
  rooms: ["Rooms", "Who is in each room right now. Rooms count as occupied once you confirm the guest arrived."],
  dashboard: ["Dashboard", "Occupancy, revenue and bookings for a date range."],
  reviews: ["Reviews", "What guests wrote after their stay."],
  team: ["Team", "Who can use the staff portal. Everyone here is an admin."],
};

export function StaffHome() {
  const params = useSearchParams();
  const tab = currentTab(params.get("tab"));
  const [title, intro] = HEADINGS[tab];

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
      {tab === "reviews" && <ReviewsTab canModerate />}
      {tab === "team" && <TeamTab />}
    </>
  );
}

// --------------------------------------------------------------------------
// Today
// --------------------------------------------------------------------------
function Today() {
  const [rows, setRows] = useState<Booking[] | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const today = todayManila();

  const [upcoming, setUpcoming] = useState<Booking[]>([]);

  const load = useCallback(() => {
    // Every confirmed booking that touches today: arriving, leaving or staying
    supabase().from("bookings").select(STAFF_BOOKING_SELECT).eq("status", "confirmed")
      .lte("check_in", today).gte("check_out", today).order("guest_name")
      .then(({ data, error }) => (error ? setError(error.message) : setRows((data as Booking[]) ?? [])));
    // And who is due in the next two weeks, so new website and app bookings show up here too
    supabase().from("bookings").select(STAFF_BOOKING_SELECT).eq("status", "confirmed")
      .gt("check_in", today).lte("check_in", addDays(today, UPCOMING_DAYS)).order("check_in").order("guest_name")
      .then(({ data, error }) => (error ? setError(error.message) : setUpcoming((data as Booking[]) ?? [])));
  }, [today]);

  // New bookings come in from the website and the app at any time, so refresh every minute
  useEffect(() => {
    load();
    const timer = setInterval(load, 60_000);
    return () => clearInterval(timer);
  }, [load]);

  async function arrived(b: Booking) {
    setError("");
    setBusy(b.id);
    const { error } = await supabase().rpc("confirm_arrival", { p_booking_id: b.id });
    setBusy(null);
    if (error) setError(error.message);
    load();
  }

  if (!rows) return error ? <Notice tone="error">{error}</Notice> : <Spinner />;

  const arriving = rows.filter((b) => b.check_in === today);
  const leaving = rows.filter((b) => b.check_out === today);
  const staying = rows.filter((b) => b.check_in < today && b.check_out > today);
  const toCollect = arriving.reduce((sum, b) => sum + owes(b), 0);
  const rooms = { onArrived: arrived, busy };

  return (
    <div className="grid gap-10">
      {error && <Notice tone="error">{error}</Notice>}
      <div className="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-line bg-line lg:grid-cols-4">
        <Stat label="Arriving" value={String(arriving.length)} note={`due ${niceDate(today)}`} href="#arrivals" />
        <Stat label="Leaving" value={String(leaving.length)} note="check-out today" href="#departures" />
        <Stat label="Staying tonight" value={String(staying.length)} note="stay started earlier" href="#staying" />
        <Stat label="To collect" value={money(toCollect)} note="from today's arrivals" href="#arrivals" />
      </div>
      <BookingList id="arrivals" title={`Arriving ${niceDate(today)}`} rows={arriving} empty="Nobody is due to arrive today." rooms={rooms} />
      <BookingList id="departures" title="Leaving today" rows={leaving} empty="Nobody is due to leave today." rooms={{ busy }} />
      <BookingList id="staying" title="Staying tonight" rows={staying} empty="No other guests are mid-stay." rooms={rooms} />
      <BookingList id="upcoming" title={`Arriving in the next ${UPCOMING_DAYS} days`} rows={upcoming}
        empty={`Nobody is booked to arrive in the next ${UPCOMING_DAYS} days.`} />
    </div>
  );
}

const UPCOMING_DAYS = 14;

function Stat({ label, value, note, href }: { label: string; value: string; note: string; href: string }) {
  return (
    <Link href={href} className="bg-paper p-4 transition-colors hover:bg-sea-tint sm:p-5">
      <p className="text-sm font-medium text-muted">{label}</p>
      <p className="mt-1 font-display text-3xl font-semibold tabular-nums sm:text-4xl">{value}</p>
      <p className="mt-1 text-xs text-muted">{note}</p>
    </Link>
  );
}

// Where the booking came from, and a "New" mark for the last 24 hours
const SOURCE_LABEL: Record<string, string> = { web: "Website", mobile: "App", front_desk: "Walk-in" };

function SourceTag({ b }: { b: Booking }) {
  const isNew = Date.now() - new Date(b.created_at).getTime() < 24 * 60 * 60 * 1000;
  return (
    <span className="inline-flex flex-wrap items-center gap-1.5">
      <span className="rounded-full border border-line px-2 py-0.5 text-xs font-medium text-muted">{SOURCE_LABEL[b.source] ?? b.source}</span>
      {isNew && <span className="rounded-full bg-sea-tint px-2 py-0.5 text-xs font-semibold text-sea">New</span>}
    </span>
  );
}

// Today's lists also show the assigned room, whether the guest is in it, and a way to say they arrived
type RoomColumn = { onArrived?: (b: Booking) => void; busy: string | null };

function RoomCell({ b, rooms }: { b: Booking; rooms: RoomColumn }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="font-semibold">{b.room ? `Room ${b.room.number}` : "No room yet"}</span>
      <OccupancyBadge occupancy={b.arrived_at ? "occupied" : "not_arrived"} />
      {!b.arrived_at && rooms.onArrived && (
        <button className="btn-quiet py-1! text-xs" disabled={rooms.busy === b.id}
          onClick={(e) => { e.preventDefault(); rooms.onArrived?.(b); }}>
          {rooms.busy === b.id ? "Saving…" : "Guest arrived"}
        </button>
      )}
    </div>
  );
}

function BookingList({ id, title, rows, empty, rooms }: { id?: string; title: ReactNode; rows: Booking[]; empty: string; rooms?: RoomColumn }) {
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
              const balance = owes(b);
              return (
                <li key={b.id} className="card p-4">
                  <Link href={`/staff/booking?id=${b.id}`} className="block transition-colors hover:text-sea">
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="truncate font-semibold">{b.guest_name}</p>
                        <p className="text-sm text-muted">{br?.room_types?.name}</p>
                      </div>
                      <BookingBadge status={b.status} />
                    </div>
                    <p className="mt-2 text-sm">{niceDate(b.check_in)} – {niceDate(b.check_out)} · <span className="font-mono">{b.code}</span></p>
                    <div className="mt-2"><SourceTag b={b} /></div>
                    <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-sm">
                      <span className="text-muted">Arriving {arrivalLabel(b.arrival_time)?.toLowerCase() ?? "time not given"}</span>
                      {balance > 0 && <span className="font-semibold text-sun">{money(balance)} to pay{b.payment_option === "pay_at_hotel" ? " · pays at hotel" : ""}</span>}
                    </div>
                  </Link>
                  {rooms && <div className="mt-3 border-t border-line pt-3 text-sm"><RoomCell b={b} rooms={rooms} /></div>}
                </li>
              );
            })}
          </ul>

          {/* Wider screens: a table */}
          <div className="card hidden overflow-x-auto md:block">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-line text-xs font-medium text-muted">
                <tr>
                  <th className="px-4 py-3">Guest</th><th className="px-4 py-3">{rooms ? "Room" : "Room type"}</th><th className="px-4 py-3">Dates</th>
                  <th className="px-4 py-3">Arriving</th><th className="px-4 py-3">Balance</th><th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3"><span className="sr-only">Action</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {rows.map((b) => {
                  const br = b.booking_rooms?.[0];
                  const balance = owes(b);
                  return (
                    <tr key={b.id} className="hover:bg-sand/60">
                      <td className="px-4 py-3">
                        <Link href={`/staff/booking?id=${b.id}`} className="font-medium text-sea hover:underline">{b.guest_name}</Link>
                        <p className="font-mono text-xs text-muted">{b.code}</p>
                        <div className="mt-1"><SourceTag b={b} /></div>
                      </td>
                      <td className="px-4 py-3 text-muted">
                        {rooms ? <><RoomCell b={b} rooms={rooms} /><p className="mt-1 text-xs">{br?.room_types?.name}</p></> : br?.room_types?.name}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3">{niceDate(b.check_in)} – {niceDate(b.check_out)}<p className="text-xs text-muted">{plural(nightsBetween(b.check_in, b.check_out), "night")}</p></td>
                      <td className="whitespace-nowrap px-4 py-3 text-muted">{arrivalLabel(b.arrival_time) ?? "Not given"}</td>
                      <td className={`whitespace-nowrap px-4 py-3 tabular-nums ${balance > 0 ? "font-semibold text-sun" : "text-muted"}`}>{balance > 0 ? money(balance) : "Paid"}{balance > 0 && b.payment_option === "pay_at_hotel" && <p className="text-xs font-normal text-muted">Pays at hotel</p>}</td>
                      <td className="px-4 py-3"><BookingBadge status={b.status} /></td>
                      <td className="px-4 py-3 text-right">
                        <Link href={`/staff/booking?id=${b.id}`} className="text-sm font-medium text-sea hover:underline">Open</Link>
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
// Rooms: who is in each room now, with cleaning and out of order as smaller controls
// --------------------------------------------------------------------------
const NEXT_STATUS: Partial<Record<RoomStatus, { to: RoomStatus; label: string }>> = {
  dirty: { to: "cleaning", label: "Start cleaning" },
  cleaning: { to: "vacant_clean", label: "Mark clean" },
};
const ROOM_EDGE: Record<Occupancy, string> = {
  occupied: "border-l-sea",
  leaving_soon: "border-l-sun",
  not_arrived: "border-l-line",
  empty: "border-l-good",
  out_of_order: "border-l-bad",
};
const FILTERS: (Occupancy | "all")[] = ["all", "occupied", "leaving_soon", "not_arrived", "empty", "out_of_order"];

function RoomBoard() {
  const [rooms, setRooms] = useState<BoardRoom[] | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [filter, setFilter] = useState<Occupancy | "all">("all");

  const load = useCallback(() => {
    supabase().rpc("staff_room_board").then(({ data, error }) => {
      if (error) setError(error.message);
      else setRooms((data as BoardRoom[]) ?? []);
    });
  }, []);

  // Occupancy depends on the clock too (Leaving soon), so refresh every minute
  useEffect(() => {
    load();
    const timer = setInterval(load, 60_000);
    return () => clearInterval(timer);
  }, [load]);

  async function act(room: BoardRoom, fn: string, args: Record<string, unknown>) {
    setError("");
    setBusy(room.room_id);
    const { error } = await supabase().rpc(fn, args);
    setBusy(null);
    if (error) setError(error.message);
    load();
  }
  const setStatus = (r: BoardRoom, status: RoomStatus) => act(r, "set_room_status", { p_room_id: r.room_id, p_status: status });

  if (!rooms) return error ? <Notice tone="error">{error}</Notice> : <Spinner />;

  const counts = rooms.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.occupancy]: (acc[r.occupancy] ?? 0) + 1 }), {});
  const shown = filter === "all" ? rooms : rooms.filter((r) => r.occupancy === filter);
  const floors = [...new Set(shown.map((r) => r.floor ?? 0))].sort((a, b) => a - b);

  return (
    <div className="grid gap-6">
      {error && <Notice tone="error">{error}</Notice>}
      <div className="flex flex-wrap gap-2" role="group" aria-label="Show rooms">
        {FILTERS.map((f) => (
          <button key={f} onClick={() => setFilter(f)} aria-pressed={filter === f}
            className={`inline-flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors ${filter === f ? "border-bay bg-bay text-on-bay" : "border-line bg-paper hover:border-sea"}`}>
            {f === "all" ? "All rooms" : f === "not_arrived" ? "Not arrived" : occupancyLabel[f]}
            <span className={`tabular-nums ${filter === f ? "text-on-bay-muted" : "text-muted"}`}>{f === "all" ? rooms.length : counts[f] ?? 0}</span>
          </button>
        ))}
      </div>
      {shown.length === 0 && <p className="rounded-xl border border-dashed border-line px-4 py-6 text-sm text-muted">No rooms like this right now.</p>}
      {floors.map((f) => (
        <section key={f}>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-[0.12em] text-muted">Floor {f}</h2>
          <div className="grid grid-cols-1 gap-3 min-[420px]:grid-cols-2 xl:grid-cols-4">
            {shown.filter((r) => (r.floor ?? 0) === f).map((r) => {
              const next = NEXT_STATUS[r.room_status];
              const saving = busy === r.room_id;
              const outOfOrder = r.room_status === "out_of_order";
              return (
                <div key={r.room_id} className={`card flex flex-col border-l-4 p-4 ${ROOM_EDGE[r.occupancy]}`}>
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <p className="font-display text-2xl font-semibold leading-none">{r.number}</p>
                      <p className="mt-1 text-xs text-muted">{r.room_type}</p>
                    </div>
                    <OccupancyBadge occupancy={r.occupancy} />
                  </div>

                  {r.booking_id && r.guest_name && (
                    <div className="mt-3 text-sm">
                      <Link href={`/staff/booking?id=${r.booking_id}`} className="font-medium text-sea hover:underline">{r.guest_name}</Link>
                      {r.check_out && <p className="text-xs text-muted">Leaves {niceDate(r.check_out)}</p>}
                      {r.occupancy === "not_arrived" && (
                        <button className="btn-primary mt-2 w-full py-1.5! text-sm" disabled={saving}
                          onClick={() => act(r, "confirm_arrival", { p_booking_id: r.booking_id })}>
                          {saving ? "Saving…" : "Guest arrived"}
                        </button>
                      )}
                    </div>
                  )}

                  {/* Housekeeping: a small tag and the next step, plus out of order */}
                  <div className="mt-auto pt-4">
                    <div className="flex flex-wrap items-center gap-2 border-t border-line pt-3 text-xs">
                      {(r.room_status === "dirty" || r.room_status === "cleaning") && <RoomBadge status={r.room_status} />}
                      {next && (
                        <button className="font-medium text-sea hover:underline disabled:opacity-60" disabled={saving} onClick={() => setStatus(r, next.to)}>
                          {next.label}
                        </button>
                      )}
                      {r.room_status === "vacant_clean" && (
                        <button className="font-medium text-muted hover:text-sea hover:underline disabled:opacity-60" disabled={saving} onClick={() => setStatus(r, "dirty")}>
                          Mark for cleaning
                        </button>
                      )}
                      <button className="ml-auto font-medium text-muted hover:text-bad hover:underline disabled:opacity-60" disabled={saving}
                        onClick={() => setStatus(r, outOfOrder ? "dirty" : "out_of_order")}>
                        {outOfOrder ? "Back in service" : "Out of order"}
                      </button>
                    </div>
                  </div>
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

  // Before searching, show the latest bookings so the page is useful straight away
  // (refreshed every minute, so new website and app bookings appear without a reload)
  useEffect(() => {
    const load = () => supabase().from("bookings").select(BOOKING_SELECT).neq("status", "expired")
      .order("created_at", { ascending: false }).limit(15)
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setRecent((data as Booking[]) ?? []);
      });
    load();
    const timer = setInterval(load, 60_000);
    return () => clearInterval(timer);
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
        <BookingList title={`Results for “${result.term}”`} rows={result.rows} empty="No bookings match. Try part of the name, or the code from the guest's confirmation." />
      ) : recent ? (
        <BookingList title="Latest bookings" rows={recent} empty="No bookings yet." />
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
        if (error) {
          setError(error.message);
          setOffers({ key: offerKey, list: [] });
          return;
        }
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

// Money still to collect: only on stays that are going ahead (not cancelled, expired or no-shows)
function owes(b: Booking): number {
  return ["confirmed", "checked_out"].includes(b.status) ? Math.max(Number(b.total) - Number(b.amount_paid), 0) : 0;
}
