"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { addDays } from "@/lib/format";
import { useToday } from "@/lib/useToday";
import { FORWARD } from "./Page";

type Props = {
  initial?: { checkIn?: string; checkOut?: string; adults?: number; children?: number };
  compact?: boolean;
};

export function SearchForm({ initial, compact }: Props) {
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
    if (checkOut <= checkIn) {
      setError("Check-out must be after check-in.");
      return;
    }
    setError("");
    const q = new URLSearchParams({ check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });
    router.push(`/search?${q}`, { transitionTypes: FORWARD });
  }

  return (
    <form onSubmit={submit} className={`card grid gap-3 p-4 sm:grid-cols-[1fr_1fr_0.7fr_0.7fr_auto] sm:items-end ${compact ? "" : "shadow-[var(--shadow)] sm:p-5"}`}>
      <div>
        <label htmlFor="check-in" className="label">Check-in</label>
        <input id="check-in" type="date" className="field" min={today || undefined} value={checkIn} required
          onChange={(e) => {
            setCheckIn(e.target.value);
            if (checkOut <= e.target.value) setCheckOut(addDays(e.target.value, 1));
          }} />
      </div>
      <div>
        <label htmlFor="check-out" className="label">Check-out</label>
        <input id="check-out" type="date" className="field" min={checkIn ? addDays(checkIn, 1) : undefined} max={checkIn ? addDays(checkIn, 30) : undefined} value={checkOut} required
          onChange={(e) => setCheckOut(e.target.value)} />
      </div>
      <div>
        <label htmlFor="adults" className="label">Adults</label>
        <select id="adults" className="field" value={adults} onChange={(e) => setAdults(Number(e.target.value))}>
          {[1, 2, 3, 4].map((n) => <option key={n} value={n}>{n}</option>)}
        </select>
      </div>
      <div>
        <label htmlFor="children" className="label">Children</label>
        <select id="children" className="field" value={children} onChange={(e) => setChildren(Number(e.target.value))}>
          {[0, 1, 2].map((n) => <option key={n} value={n}>{n}</option>)}
        </select>
      </div>
      <button type="submit" className="btn-primary h-[46px]">Search rooms</button>
      {error && <p className="text-sm text-bad sm:col-span-5">{error}</p>}
    </form>
  );
}
