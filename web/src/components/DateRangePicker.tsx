"use client";

import { useEffect, useId, useRef, useState } from "react";
import { supabase } from "@/lib/supabase";
import { addDays, money, nightsBetween } from "@/lib/format";
import { fmtDate, fmtMonth } from "@/lib/messages";
import { useT } from "@/lib/i18n";
import { useToday } from "@/lib/useToday";

type Day = { price: number | null; available: boolean };
type Props = {
  checkIn: string;
  checkOut: string;
  adults: number;
  kids: number;
  onChange: (checkIn: string, checkOut: string) => void;
  label?: string;
};

const monthStart = (iso: string) => `${iso.slice(0, 7)}-01`;
function addMonths(iso: string, n: number) {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCMonth(d.getUTCMonth() + n, 1);
  return d.toISOString().slice(0, 10);
}
const shortPrice = (n: number) => (n >= 10000 ? `${Math.round(n / 1000)}k` : n.toLocaleString("en-PH", { maximumFractionDigits: 0 }));

// One shared cache for the session: prices for a month and guest count rarely change mid-visit
const cache = new Map<string, Record<string, Day>>();

export function DateRangePicker({ checkIn, checkOut, adults, kids, onChange, label }: Props) {
  const { t, lang } = useT();
  const today = useToday();
  const [open, setOpen] = useState(false);
  const [view, setView] = useState("");
  const [pendingIn, setPendingIn] = useState<string | null>(null);
  const [hover, setHover] = useState<string | null>(null);
  const [days, setDays] = useState<Record<string, Day>>({});
  const [message, setMessage] = useState("");
  const wrap = useRef<HTMLDivElement>(null);
  const panelId = useId();

  const first = view || monthStart(checkIn || today || "2026-01-01");
  const from = first < (today || first) ? today : first;
  const to = addMonths(first, 2);
  const key = `${from}|${to}|${adults}|${kids}`;

  // Bring the whole calendar on screen when it opens below the fold
  useEffect(() => {
    if (!open) return;
    const panel = document.getElementById(panelId);
    const smooth = !matchMedia("(prefers-reduced-motion: reduce)").matches;
    panel?.scrollIntoView({ block: "nearest", behavior: smooth ? "smooth" : "auto" });
  }, [open, panelId]);

  // Prices for the two months on screen
  useEffect(() => {
    if (!open || !from) return;
    const hit = cache.get(key);
    let active = true;
    if (hit) {
      queueMicrotask(() => active && setDays((d) => ({ ...d, ...hit })));
      return () => { active = false; };
    }
    supabase()
      .rpc("price_calendar", { p_from: from, p_to: to, p_adults: adults, p_children: kids })
      .then(({ data }) => {
        if (!active || !data) return;
        const map: Record<string, Day> = {};
        for (const row of data as { day: string; lowest_price: number | null; available: boolean }[]) {
          map[row.day] = { price: row.lowest_price == null ? null : Number(row.lowest_price), available: row.available };
        }
        cache.set(key, map);
        setDays((d) => ({ ...d, ...map }));
      });
    return () => { active = false; };
  }, [open, key, from, to, adults, kids]);

  // Close on Escape or a click outside
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    const onClick = (e: MouseEvent) => {
      if (wrap.current && !wrap.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("mousedown", onClick);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("mousedown", onClick);
    };
  }, [open]);

  function pick(day: string) {
    setMessage("");
    const info = days[day];
    if (!pendingIn || day <= pendingIn) {
      if (info && !info.available) {
        setMessage(t.calendar.fullNight);
        return;
      }
      setPendingIn(day);
      return;
    }
    if (nightsBetween(pendingIn, day) > 30) {
      setMessage(t.calendar.tooLong);
      return;
    }
    for (let d = pendingIn; d < day; d = addDays(d, 1)) {
      if (days[d] && !days[d].available) {
        setMessage(t.calendar.fullNight);
        return;
      }
    }
    onChange(pendingIn, day);
    setPendingIn(null);
    setOpen(false);
  }

  const shownIn = pendingIn ?? checkIn;
  const shownOut = pendingIn ? (hover && hover > pendingIn ? hover : "") : checkOut;
  const nights = checkIn && checkOut ? nightsBetween(checkIn, checkOut) : 0;

  return (
    <div ref={wrap} className="relative">
      <span className="label" id={`${panelId}-label`}>{label ?? t.search.dates}</span>
      <button
        type="button"
        className="field flex items-center justify-between gap-3 text-left"
        aria-expanded={open}
        aria-controls={panelId}
        aria-labelledby={`${panelId}-label ${panelId}-value`}
        onClick={() => {
          setOpen((o) => !o);
          setPendingIn(null);
          setMessage("");
        }}
      >
        <span id={`${panelId}-value`} className="truncate">
          {checkIn && checkOut ? (
            <>
              {fmtDate(checkIn, lang)} <span className="text-muted">→</span> {fmtDate(checkOut, lang)}
              <span className="ml-2 text-muted">{t.nights(nights)}</span>
            </>
          ) : (
            <span className="text-muted">{t.search.chooseDates}</span>
          )}
        </span>
        <svg viewBox="0 0 20 20" className="h-5 w-5 shrink-0 text-muted" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden>
          <rect x="3" y="4.5" width="14" height="12.5" rx="2" />
          <path d="M3 8.5h14M7 2.5v4M13 2.5v4" />
        </svg>
      </button>

      {open && (
        <div id={panelId} role="dialog" aria-label={pendingIn ? t.calendar.pickCheckOut : t.calendar.pickCheckIn}
          className="picker-panel absolute left-0 top-full z-40 mt-2 w-full sm:w-[min(42rem,calc(100vw-2rem))] rounded-2xl border border-line bg-paper p-4 shadow-[var(--shadow)] sm:p-5">
          <div className="mb-3 flex items-center justify-between gap-3">
            <button type="button" className="btn-quiet h-9 w-9 p-0!" aria-label={t.calendar.prev}
              disabled={!today || first <= monthStart(today)} onClick={() => setView(addMonths(first, -1))}>‹</button>
            <p className="text-center text-sm font-medium" aria-live="polite">{pendingIn ? t.calendar.pickCheckOut : t.calendar.pickCheckIn}</p>
            <button type="button" className="btn-quiet h-9 w-9 p-0!" aria-label={t.calendar.next}
              disabled={!today || first >= addMonths(monthStart(today), 10)} onClick={() => setView(addMonths(first, 1))}>›</button>
          </div>
          <div className="grid gap-6 sm:grid-cols-2">
            {[0, 1].map((m) => (
              <Month key={m} month={addMonths(first, m)} className={m === 1 ? "hidden sm:block" : ""}
                today={today} days={days} checkIn={shownIn} checkOut={shownOut} pending={!!pendingIn}
                onPick={pick} onHover={setHover} />
            ))}
          </div>
          {message && <p className="mt-3 text-sm text-bad" role="alert">{message}</p>}
          <p className="mt-3 text-xs text-muted">{t.calendar.note}</p>
        </div>
      )}
    </div>
  );
}

function Month({ month, className, today, days, checkIn, checkOut, pending, onPick, onHover }: {
  month: string; className: string; today: string; days: Record<string, Day>;
  checkIn: string; checkOut: string; pending: boolean;
  onPick: (d: string) => void; onHover: (d: string | null) => void;
}) {
  const { t, lang } = useT();
  const startWeekday = new Date(`${month}T00:00:00Z`).getUTCDay(); // Sunday first
  const count = new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0)).getUTCDate();
  const weekdays = [...Array(7)].map((_, i) =>
    new Date(Date.UTC(2026, 1, 1 + i)).toLocaleDateString(t.locale, { weekday: "narrow", timeZone: "UTC" }));

  return (
    <div className={className}>
      <p className="mb-2 text-center font-display font-semibold">{fmtMonth(month, lang)}</p>
      <div className="grid grid-cols-7 text-center text-xs text-muted" aria-hidden>
        {weekdays.map((w, i) => <span key={i} className="py-1">{w}</span>)}
      </div>
      <div className="grid grid-cols-7 gap-y-1" onMouseLeave={() => onHover(null)}>
        {[...Array(startWeekday)].map((_, i) => <span key={`b${i}`} />)}
        {[...Array(count)].map((_, i) => {
          const day = addDays(month, i);
          const info = days[day];
          const past = !today || day < today;
          const full = !!info && !info.available;
          const isIn = day === checkIn;
          const isOut = day === checkOut;
          const inRange = checkIn && checkOut && day > checkIn && day < checkOut;
          // Check-out day can be a "full" night because nobody sleeps there that night
          const disabled = past || (full && !pending);
          return (
            <button
              key={day}
              type="button"
              disabled={disabled}
              onClick={() => onPick(day)}
              onMouseEnter={() => onHover(day)}
              aria-pressed={isIn || isOut}
              aria-label={t.calendar.dayLabel(fmtDate(day, lang, true), info?.price != null ? money(info.price) : null, full)}
              className={`flex h-12 flex-col items-center justify-center text-sm transition-colors
                ${isIn || isOut ? "rounded-xl bg-bay text-on-bay" : inRange ? "bg-sea-tint" : "rounded-xl hover:bg-sea-tint"}
                ${disabled ? "cursor-not-allowed text-muted/50 hover:bg-transparent" : ""}`}
            >
              <span className={full && !past ? "line-through" : ""}>{i + 1}</span>
              {!past && (
                <span className={`text-[10px] leading-none ${isIn || isOut ? "text-mango" : full ? "text-bad" : "text-muted"}`}>
                  {full ? t.calendar.soldOut : info?.price != null ? shortPrice(info.price) : info ? "" : "·"}
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
