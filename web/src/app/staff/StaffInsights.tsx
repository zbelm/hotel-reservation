"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Notice, Spinner } from "@/components/ui";
import { Stars } from "@/components/Reviews";
import { supabase } from "@/lib/supabase";
import { addDays, money, niceDate, nightsBetween } from "@/lib/format";
import { useToday } from "@/lib/useToday";
import { BOOKING_SELECT, type Booking, type Review } from "@/lib/types";

// ===========================================================================
// Dashboard: occupancy and revenue by day, plus a summary of bookings made
// ===========================================================================
type Day = { day: string; rooms: number; sold: number; revenue: number; arrivals: number };
type Summary = {
  bookings_made: number;
  by_source: { web: number; mobile: number; front_desk: number };
  cancelled: number;
  refunds_due: number;
  rating: number | null;
  reviews: number;
};

const RANGES = [
  { key: "next7", label: "Next 7 days" },
  { key: "next30", label: "Next 30 days" },
  { key: "last30", label: "Last 30 days" },
  { key: "month", label: "This month" },
] as const;
type RangeKey = (typeof RANGES)[number]["key"];

function rangeFor(key: RangeKey, today: string): [string, string] {
  if (key === "next7") return [today, addDays(today, 7)];
  if (key === "next30") return [today, addDays(today, 30)];
  if (key === "last30") return [addDays(today, -30), today];
  const first = `${today.slice(0, 7)}-01`;
  const next = new Date(`${first}T00:00:00Z`);
  next.setUTCMonth(next.getUTCMonth() + 1);
  return [first, next.toISOString().slice(0, 10)];
}

const compactPeso = (n: number) =>
  n >= 1_000_000 ? `₱${(n / 1_000_000).toFixed(1)}M` : n >= 10_000 ? `₱${Math.round(n / 1000)}K` : money(n);

export function DashboardTab() {
  const today = useToday();
  const [range, setRange] = useState<RangeKey>("next30");
  const [data, setData] = useState<{ key: string; days?: Day[]; summary?: Summary; error?: string } | null>(null);
  const [from, to] = today ? rangeFor(range, today) : ["", ""];
  const key = `${from}|${to}`;

  useEffect(() => {
    if (!from) return;
    let active = true;
    supabase().rpc("dashboard", { p_from: from, p_to: to }).then(({ data, error }) => {
      if (!active) return;
      if (error) setData({ key, error: error.message });
      else setData({ key, days: (data.days as Day[]).map((d) => ({ ...d, revenue: Number(d.revenue) })), summary: data.summary as Summary });
    });
    return () => { active = false; };
  }, [from, to, key]);

  const current = data?.key === key ? data : null;
  const days = current?.days ?? [];
  const totals = (() => {
    const sold = days.reduce((a, d) => a + d.sold, 0);
    const capacity = days.reduce((a, d) => a + d.rooms, 0);
    const revenue = days.reduce((a, d) => a + d.revenue, 0);
    const arrivals = days.reduce((a, d) => a + d.arrivals, 0);
    return { sold, capacity, revenue, arrivals, occupancy: capacity ? sold / capacity : 0, adr: sold ? revenue / sold : 0 };
  })();

  return (
    <div className="grid gap-8">
      <div className="flex flex-wrap items-center gap-2" role="group" aria-label="Date range">
        {RANGES.map((r) => (
          <button key={r.key} onClick={() => setRange(r.key)} aria-pressed={range === r.key}
            className={`rounded-full border px-4 py-2 text-sm font-medium transition-colors ${range === r.key ? "border-sea bg-sea-tint text-sea" : "border-line text-muted hover:text-ink"}`}>
            {r.label}
          </button>
        ))}
        {from && <span className="ml-auto text-sm text-muted">{niceDate(from)} – {niceDate(addDays(to, -1), true)}</span>}
      </div>

      {current?.error && <Notice tone="error">{current.error}</Notice>}
      {!current && <Spinner label="Loading the numbers" />}

      {current?.summary && (
        <>
          <section className="grid gap-px overflow-hidden rounded-2xl border border-line bg-line sm:grid-cols-2 lg:grid-cols-4" aria-label="Summary">
            <Tile label="Occupancy" value={`${Math.round(totals.occupancy * 100)}%`} note={`${totals.sold} of ${totals.capacity} room-nights sold`} />
            <Tile label="Room revenue" value={compactPeso(totals.revenue)} note="Confirmed, in-house and completed stays" />
            <Tile label="Average nightly rate" value={totals.sold ? money(totals.adr) : "—"} note="Room revenue ÷ room-nights sold" />
            <Tile label="Arrivals" value={String(totals.arrivals)} note="Guests checking in in this range" />
          </section>

          <ColumnChart
            title="Occupancy by night"
            caption="Share of rooms sold each night. Out-of-order rooms are left out."
            data={days.map((d) => ({ day: d.day, value: d.rooms ? d.sold / d.rooms : 0, tip: `${d.sold} of ${d.rooms} rooms (${d.rooms ? Math.round((d.sold / d.rooms) * 100) : 0}%)` }))}
            max={1}
            ticks={[0, 0.5, 1]}
            tickLabel={(v) => `${Math.round(v * 100)}%`}
          />

          <ColumnChart
            title="Room revenue by night"
            caption="Nightly prices of confirmed, in-house and completed stays."
            data={days.map((d) => ({ day: d.day, value: d.revenue, tip: money(d.revenue) }))}
            {...niceScale(Math.max(...days.map((d) => d.revenue), 1))}
            tickLabel={compactPeso}
          />

          <section className="grid gap-6 lg:grid-cols-2">
            <div className="card p-5">
              <h3 className="font-semibold">Bookings made in this range</h3>
              <p className="text-sm text-muted">{current.summary.bookings_made} bookings, {current.summary.cancelled} cancelled</p>
              <SourceBars by={current.summary.by_source} />
            </div>
            <div className="card p-5">
              <h3 className="font-semibold">Guest reviews</h3>
              {current.summary.reviews ? (
                <p className="mt-3 flex items-center gap-3 text-lg">
                  <Stars rating={Math.round(Number(current.summary.rating ?? 0))} />
                  <span className="font-semibold">{current.summary.rating} out of 5</span>
                  <span className="text-muted">from {current.summary.reviews}</span>
                </p>
              ) : <p className="mt-3 text-muted">No reviews yet. Guests can review after they check out.</p>}
              {Number(current.summary.refunds_due) > 0 && (
                <p className="mt-4 text-sm"><span className="font-semibold text-bad">{money(current.summary.refunds_due)}</span> in refunds still to send for bookings made in this range.</p>
              )}
            </div>
          </section>

          <details className="disclose card px-5">
            <summary className="flex items-center justify-between py-4 font-medium">Show the numbers as a table</summary>
            <div className="overflow-x-auto pb-4">
              <table className="w-full text-left text-sm tabular-nums">
                <thead className="border-b border-line text-muted">
                  <tr><th className="py-2 font-medium">Night</th><th className="py-2 text-right font-medium">Rooms sold</th><th className="py-2 text-right font-medium">Occupancy</th><th className="py-2 text-right font-medium">Revenue</th><th className="py-2 text-right font-medium">Arrivals</th></tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {days.map((d) => (
                    <tr key={d.day}>
                      <td className="py-1.5">{niceDate(d.day, true)}</td>
                      <td className="py-1.5 text-right">{d.sold} / {d.rooms}</td>
                      <td className="py-1.5 text-right">{d.rooms ? Math.round((d.sold / d.rooms) * 100) : 0}%</td>
                      <td className="py-1.5 text-right">{money(d.revenue)}</td>
                      <td className="py-1.5 text-right">{d.arrivals}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </details>
        </>
      )}
    </div>
  );
}

function Tile({ label, value, note }: { label: string; value: string; note: string }) {
  return (
    <div className="bg-paper p-5">
      <p className="text-sm text-muted">{label}</p>
      <p className="mt-1 text-3xl font-semibold">{value}</p>
      <p className="mt-1 text-xs text-muted">{note}</p>
    </div>
  );
}

// Round the top of the scale up to a clean number, with three ticks
function niceScale(maxValue: number) {
  const step = Math.pow(10, Math.floor(Math.log10(maxValue)));
  const max = [1, 2, 2.5, 5, 10].map((m) => m * step).find((v) => v >= maxValue) ?? maxValue;
  return { max, ticks: [0, max / 2, max] };
}

// Single-series columns: one hue, thin bars, a tooltip on hover or keyboard focus
function ColumnChart({ title, caption, data, max, ticks, tickLabel }: {
  title: string; caption: string; data: { day: string; value: number; tip: string }[];
  max: number; ticks: number[]; tickLabel: (v: number) => string;
}) {
  const every = Math.max(1, Math.ceil(data.length / 8));
  return (
    <section className="card p-5">
      <h3 className="font-semibold">{title}</h3>
      <p className="text-sm text-muted">{caption}</p>
      <div className="mt-5 grid grid-cols-[3.25rem_1fr] gap-2">
        <div className="relative h-48 text-right text-xs tabular-nums text-muted" aria-hidden>
          {ticks.map((v) => (
            <span key={v} className="absolute right-0 -translate-y-1/2" style={{ bottom: `calc(${(v / max) * 100}% - 0.5em)`, transform: "none" }}>{tickLabel(v)}</span>
          ))}
        </div>
        <div>
          <div className="relative h-48">
            {ticks.map((v) => (
              <div key={v} aria-hidden className="absolute inset-x-0 border-t border-line" style={{ bottom: `${(v / max) * 100}%` }} />
            ))}
            <ul className="absolute inset-0 flex items-end" aria-label={title}>
              {data.map((d) => (
                <li key={d.day} tabIndex={0} aria-label={`${niceDate(d.day)}: ${d.tip}`}
                  className="group relative flex h-full flex-1 items-end justify-center px-px outline-none">
                  <span className="block w-full max-w-6 rounded-t-[4px] bg-sea transition-opacity group-hover:opacity-80 group-focus-visible:opacity-80"
                    style={{ height: `${Math.min(1, d.value / max) * 100}%`, minHeight: d.value > 0 ? 2 : 0 }} />
                  <span role="tooltip" className="pointer-events-none absolute bottom-full left-1/2 z-10 mb-1 hidden -translate-x-1/2 whitespace-nowrap rounded-lg bg-bay px-2.5 py-1.5 text-xs text-on-bay shadow-[var(--shadow)] group-hover:block group-focus-visible:block">
                    <strong className="block font-semibold">{niceDate(d.day)}</strong>{d.tip}
                  </span>
                </li>
              ))}
            </ul>
          </div>
          <div className="mt-1.5 flex text-[11px] text-muted" aria-hidden>
            {data.map((d, i) => (
              <span key={d.day} className="flex-1 overflow-visible whitespace-nowrap text-center">{i % every === 0 ? niceDate(d.day).replace(/^\w+, /, "") : ""}</span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function SourceBars({ by }: { by: Summary["by_source"] }) {
  const rows = [
    { label: "Website", n: by.web },
    { label: "Mobile app", n: by.mobile },
    { label: "Front desk", n: by.front_desk },
  ];
  const top = Math.max(1, ...rows.map((r) => r.n));
  return (
    <ul className="mt-4 grid gap-3">
      {rows.map((r) => (
        <li key={r.label} className="grid grid-cols-[6.5rem_1fr_2rem] items-center gap-3 text-sm">
          <span className="text-muted">{r.label}</span>
          <span className="h-3 rounded-r-[4px] bg-sea" style={{ width: `${(r.n / top) * 100}%`, minWidth: r.n ? 4 : 0 }} />
          <span className="text-right tabular-nums">{r.n}</span>
        </li>
      ))}
    </ul>
  );
}

// ===========================================================================
// Room calendar: every room across two weeks, with each stay as a bar
// ===========================================================================
type CalRoom = { id: string; number: string; floor: number | null; room_type_id: string; room_types: { name: string } | null };
const SPAN = 14;
const STATUS_STYLE: Record<string, { bar: string; label: string }> = {
  held: { bar: "bg-mango text-[#13303b]", label: "Awaiting payment" },
  confirmed: { bar: "bg-sea text-white", label: "Confirmed" },
  checked_in: { bar: "bg-bay text-on-bay ring-1 ring-on-bay/20", label: "In house" },
  checked_out: { bar: "bg-line text-muted", label: "Checked out" },
};

export function CalendarTab() {
  const today = useToday();
  const [start, setStart] = useState("");
  const from = start || today;
  const to = from ? addDays(from, SPAN) : "";
  const [data, setData] = useState<{ key: string; rooms?: CalRoom[]; bookings?: Booking[]; error?: string } | null>(null);
  const key = `${from}|${to}`;

  useEffect(() => {
    if (!from) return;
    let active = true;
    const sb = supabase();
    Promise.all([
      sb.from("rooms").select("id, number, floor, room_type_id, room_types(name)").order("number"),
      sb.from("bookings").select(BOOKING_SELECT).lt("check_in", to).gt("check_out", from)
        .in("status", ["held", "confirmed", "checked_in", "checked_out"]),
    ]).then(([r, b]) => {
      if (!active) return;
      if (r.error || b.error) return setData({ key, error: (r.error ?? b.error)!.message });
      const now = new Date();
      const bookings = ((b.data as Booking[]) ?? []).filter((x) => x.status !== "held" || (x.hold_expires_at && new Date(x.hold_expires_at) > now));
      setData({ key, rooms: (r.data as unknown as CalRoom[]) ?? [], bookings });
    });
    return () => { active = false; };
  }, [from, to, key]);

  const current = data?.key === key ? data : null;
  const dates = from ? [...Array(SPAN)].map((_, i) => addDays(from, i)) : [];

  // Group rooms by type, then add "not yet assigned" lanes for bookings without a room
  const groups = useMemo(() => {
    if (!current?.rooms || !current.bookings) return [];
    const types = new Map<string, { name: string; rooms: CalRoom[] }>();
    for (const r of current.rooms) {
      const g = types.get(r.room_type_id) ?? { name: r.room_types?.name ?? "Rooms", rooms: [] };
      g.rooms.push(r);
      types.set(r.room_type_id, g);
    }
    return [...types.entries()].map(([typeId, g]) => {
      const rows = g.rooms.map((room) => ({
        label: `Room ${room.number}`,
        bookings: current.bookings!.filter((b) => b.booking_rooms?.[0]?.room_id === room.id),
      }));
      const loose = current.bookings!
        .filter((b) => b.booking_rooms?.[0]?.room_type_id === typeId && !b.booking_rooms?.[0]?.room_id)
        .sort((a, b) => a.check_in.localeCompare(b.check_in));
      const lanes: Booking[][] = [];
      for (const b of loose) {
        const lane = lanes.find((l) => l[l.length - 1].check_out <= b.check_in);
        if (lane) lane.push(b);
        else lanes.push([b]);
      }
      lanes.forEach((l, i) => rows.push({ label: i === 0 ? "Not yet assigned" : "", bookings: l }));
      return { name: g.name, rows };
    });
  }, [current]);

  const cols = `9rem repeat(${SPAN}, minmax(3rem, 1fr))`;

  return (
    <div className="grid gap-5">
      <div className="flex flex-wrap items-center gap-2">
        <button className="btn-quiet px-3! py-2!" onClick={() => setStart(addDays(from, -7))} aria-label="Previous week">‹ Week</button>
        <button className="btn-quiet px-3! py-2!" onClick={() => setStart("")} disabled={!start || start === today}>Today</button>
        <button className="btn-quiet px-3! py-2!" onClick={() => setStart(addDays(from, 7))} aria-label="Next week">Week ›</button>
        {from && <span className="text-sm text-muted">{niceDate(from)} – {niceDate(addDays(to, -1), true)}</span>}
        <ul className="ml-auto flex flex-wrap gap-3 text-xs text-muted" aria-label="Legend">
          {Object.entries(STATUS_STYLE).map(([k, s]) => (
            <li key={k} className="flex items-center gap-1.5"><span className={`h-3 w-5 rounded ${s.bar}`} />{s.label}</li>
          ))}
        </ul>
      </div>

      {current?.error && <Notice tone="error">{current.error}</Notice>}
      {!current && <Spinner label="Loading the calendar" />}

      {current && !current.error && (
        <div className="card overflow-x-auto">
          <div className="min-w-[52rem]">
            <div className="sticky top-0 grid border-b border-line bg-paper text-center text-xs" style={{ gridTemplateColumns: cols }}>
              <span />
              {dates.map((d) => (
                <span key={d} className={`py-2 ${d === today ? "font-semibold text-sea" : "text-muted"}`}>
                  {new Date(`${d}T00:00:00Z`).toLocaleDateString("en-PH", { weekday: "short", timeZone: "UTC" })}<br />
                  <span className="text-sm">{Number(d.slice(8))}</span>
                </span>
              ))}
            </div>
            {groups.map((g) => (
              <div key={g.name}>
                <p className="border-b border-line bg-sand/60 px-3 py-1.5 text-xs font-semibold text-muted">{g.name}</p>
                {g.rows.map((row, i) => (
                  <div key={i} className="relative grid min-h-11 items-center border-b border-line" style={{ gridTemplateColumns: cols }}>
                    <span className="row-start-1 truncate px-3 text-sm">{row.label}</span>
                    {dates.map((d, j) => (
                      <span key={d} aria-hidden className={`row-start-1 h-full border-l border-line ${d === today ? "bg-sea-tint/60" : ""}`} style={{ gridColumn: j + 2 }} />
                    ))}
                    {row.bookings.map((b) => {
                      const first = Math.max(0, nightsBetween(from, b.check_in));
                      const last = Math.min(SPAN, nightsBetween(from, b.check_out));
                      if (last <= 0 || first >= SPAN) return null;
                      const style = STATUS_STYLE[b.status] ?? STATUS_STYLE.confirmed;
                      return (
                        <Link key={b.id} href={`/staff/booking?id=${b.id}`}
                          title={`${b.guest_name} · ${b.code} · ${niceDate(b.check_in)} – ${niceDate(b.check_out)} · ${style.label}`}
                          className={`row-start-1 mx-0.5 truncate rounded-md px-2 py-1 text-xs font-medium transition-opacity hover:opacity-85 ${style.bar}`}
                          style={{ gridColumn: `${first + 2} / ${last + 2}` }}>
                          {b.guest_name}
                        </Link>
                      );
                    })}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ===========================================================================
// Reviews: managers can hide a review (for example abuse or personal details)
// ===========================================================================
export function ReviewsTab({ canModerate }: { canModerate: boolean }) {
  const [list, setList] = useState<Review[] | null>(null);
  const [version, setVersion] = useState(0);
  const [error, setError] = useState("");

  useEffect(() => {
    supabase().from("reviews").select("*").order("created_at", { ascending: false }).limit(100)
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setList((data as Review[]) ?? []);
      });
  }, [version]);

  async function toggle(r: Review) {
    const { error } = await supabase().from("reviews").update({ is_published: !r.is_published }).eq("id", r.id);
    if (error) setError(error.message);
    setVersion((v) => v + 1);
  }

  if (error) return <Notice tone="error">{error}</Notice>;
  if (!list) return <Spinner label="Loading reviews" />;
  if (!list.length) return <p className="text-muted">No reviews yet. Guests can leave one from their booking page after they check out.</p>;

  return (
    <ul className="grid gap-3">
      {list.map((r) => (
        <li key={r.id} className={`card flex flex-wrap items-start justify-between gap-4 p-5 ${r.is_published ? "" : "opacity-70"}`}>
          <div className="max-w-2xl">
            <div className="flex items-center gap-3">
              <Stars rating={r.rating} />
              <span className="text-sm font-semibold">{r.display_name}</span>
              <span className="text-sm text-muted">stayed {niceDate(r.stayed_on, true)}</span>
              {!r.is_published && <span className="rounded-full bg-line px-2 py-0.5 text-xs font-semibold text-muted">Hidden</span>}
            </div>
            {r.body && <p className="mt-2">{r.body}</p>}
          </div>
          {canModerate && (
            <button className={r.is_published ? "btn-quiet" : "btn-sea"} onClick={() => toggle(r)}>
              {r.is_published ? "Hide from website" : "Show on website"}
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}
