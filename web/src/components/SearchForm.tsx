"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { addDays } from "@/lib/format";
import { useT } from "@/lib/i18n";
import { useToday } from "@/lib/useToday";
import { DateRangePicker } from "./DateRangePicker";
import { FORWARD } from "./Page";

type Props = {
  initial?: { checkIn?: string; checkOut?: string; adults?: number; children?: number };
  compact?: boolean;
};

export function SearchForm({ initial, compact }: Props) {
  const { t } = useT();
  const router = useRouter();
  const today = useToday();
  // Empty means "not chosen yet": fall back to tomorrow for 2 nights
  const [pickedIn, setCheckIn] = useState(initial?.checkIn ?? "");
  const [pickedOut, setCheckOut] = useState(initial?.checkOut ?? "");
  const checkIn = pickedIn || (today ? addDays(today, 1) : "");
  const checkOut = pickedOut || (today ? addDays(today, 3) : "");
  const [adults, setAdults] = useState(initial?.adults ?? 2);
  const [children, setChildren] = useState(initial?.children ?? 0);
  const [error, setError] = useState("");

  function submit(e: FormEvent) {
    e.preventDefault();
    if (!checkIn || !checkOut || checkOut <= checkIn) {
      setError(t.search.checkoutAfter);
      return;
    }
    setError("");
    const q = new URLSearchParams({ check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });
    router.push(`/search?${q}`, { transitionTypes: FORWARD });
  }

  return (
    <form onSubmit={submit} className={`card grid gap-3 p-4 sm:grid-cols-[2fr_0.7fr_0.7fr_auto] sm:items-end ${compact ? "" : "shadow-[var(--shadow)] sm:p-5"}`}>
      <DateRangePicker checkIn={checkIn} checkOut={checkOut} adults={adults} kids={children}
        onChange={(ci, co) => { setCheckIn(ci); setCheckOut(co); }} />
      <div>
        <label htmlFor="adults" className="label">{t.search.adults}</label>
        <select id="adults" className="field" value={adults} onChange={(e) => setAdults(Number(e.target.value))}>
          {[1, 2, 3, 4].map((n) => <option key={n} value={n}>{n}</option>)}
        </select>
      </div>
      <div>
        <label htmlFor="children" className="label">{t.search.children}</label>
        <select id="children" className="field" value={children} onChange={(e) => setChildren(Number(e.target.value))}>
          {[0, 1, 2].map((n) => <option key={n} value={n}>{n}</option>)}
        </select>
      </div>
      <button type="submit" className="btn-primary h-[46px]">{t.search.submit}</button>
      {error && <p className="text-sm text-bad sm:col-span-4">{error}</p>}
    </form>
  );
}
