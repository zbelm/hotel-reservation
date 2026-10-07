"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { FORWARD } from "@/components/Page";
import { SearchForm } from "@/components/SearchForm";
import { Steps } from "@/components/Steps";
import { Notice, RoomArt } from "@/components/ui";
import { isConfigured, supabase } from "@/lib/supabase";
import { guests, money, niceDate, plural } from "@/lib/format";
import type { SearchResult } from "@/lib/types";

export function SearchResults() {
  const params = useSearchParams();
  const checkIn = params.get("check_in") ?? "";
  const checkOut = params.get("check_out") ?? "";
  const adults = Number(params.get("adults") ?? 2);
  const children = Number(params.get("children") ?? 0);

  const stay = new URLSearchParams({ check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });
  const query = stay.toString();
  // Only ask the database once both dates are real dates (e.g. someone opened /search directly)
  const isDate = (d: string) => /^\d{4}-\d{2}-\d{2}$/.test(d);
  const ready = isDate(checkIn) && isDate(checkOut);

  // Results are tagged with the search they answer, so a new search shows the placeholders
  const [state, setState] = useState<{ query: string; results?: SearchResult[]; error?: string }>({ query: "" });

  useEffect(() => {
    if (!ready) return;
    let active = true;
    supabase()
      .rpc("search_availability", { p_check_in: checkIn, p_check_out: checkOut, p_adults: adults, p_children: children })
      .then(({ data, error }) => {
        if (!active) return;
        setState(error ? { query, error: error.message } : { query, results: (data as SearchResult[]) ?? [] });
      });
    return () => { active = false; };
  }, [ready, query, checkIn, checkOut, adults, children]);

  const current = state.query === query;
  const results = current ? state.results ?? null : null;
  const error = current ? state.error ?? "" : "";

  return (
    <>
      <Steps current={ready ? 2 : 1} />
      <SearchForm key={query} compact initial={{ checkIn, checkOut, adults, children }} />

      <div className="mb-6 mt-12 flex flex-wrap items-baseline justify-between gap-2">
        <h1 className="text-3xl font-semibold sm:text-4xl">Rooms for your stay</h1>
        {ready && (
          <p className="text-muted">
            {niceDate(checkIn)} to {niceDate(checkOut)}, {guests(adults, children)}
          </p>
        )}
      </div>

      {!isConfigured && <Notice tone="warn">The app isn&rsquo;t connected to Supabase yet. Add the keys from the README to <code>.env.local</code>.</Notice>}
      {!ready && <Notice>Choose your check-in and check-out dates above, then select Search rooms.</Notice>}
      {error && <Notice tone="error">{error}</Notice>}
      {ready && !results && !error && <ResultsSkeleton />}
      {results && results.length === 0 && (
        <Notice>No room fits {guests(adults, children)}. Try fewer guests per room, or call the front desk to book two rooms together.</Notice>
      )}

      <div className="grid gap-5">
        {results?.map((r, i) => {
          const soldOut = r.available < 1;
          const href = `/room?id=${r.room_type_id}&${stay}`;
          return (
            <article key={r.room_type_id} className="arrive lift card grid overflow-hidden sm:grid-cols-[300px_1fr]" style={{ "--i": i } as React.CSSProperties}>
              <div className="h-48 overflow-hidden sm:h-full"><RoomArt name={r.name} photo={r.photos?.[0]} className="lift-art" /></div>
              <div className="flex flex-col gap-5 p-5 sm:flex-row sm:items-end sm:justify-between sm:p-6">
                <div className="max-w-md">
                  <h2 className="text-2xl font-semibold">{r.name}</h2>
                  <p className="mt-1 text-sm text-muted">
                    {r.bed_type} bed, {r.size_sqm} m², up to {plural(r.max_adults, "adult")}
                  </p>
                  {r.description && <p className="mt-3 text-[15px] leading-relaxed">{r.description}</p>}
                  <ul className="mt-3 flex flex-wrap gap-1.5">
                    {r.amenities.slice(0, 5).map((a) => (
                      <li key={a} className="rounded-full border border-line px-2.5 py-1 text-xs text-muted">{a}</li>
                    ))}
                  </ul>
                </div>
                <div className="shrink-0 sm:text-right">
                  {soldOut ? (
                    <p className="font-semibold text-bad">Sold out for these dates</p>
                  ) : (
                    <>
                      <p className="text-sm text-muted">{plural(r.nights, "night")} from</p>
                      <p className="font-display text-3xl font-semibold">{money(r.lowest_total)}</p>
                      <p className="text-sm text-muted">{money(r.lowest_nightly)} a night, taxes included</p>
                      {r.available <= 2 && <p className="mt-1 text-sm font-semibold text-sun">Only {r.available} left</p>}
                      <Link href={href} transitionTypes={FORWARD} className="btn-primary mt-3">Choose a rate</Link>
                    </>
                  )}
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </>
  );
}

function ResultsSkeleton() {
  return (
    <div className="grid gap-5" aria-busy="true" aria-label="Finding rooms">
      {[0, 1, 2].map((i) => (
        <div key={i} className="card grid overflow-hidden sm:grid-cols-[300px_1fr]">
          <div className="skeleton h-48 rounded-none sm:h-52" />
          <div className="space-y-3 p-6">
            <div className="skeleton h-7 w-48" />
            <div className="skeleton h-4 w-64" />
            <div className="skeleton h-4 w-full max-w-md" />
          </div>
        </div>
      ))}
    </div>
  );
}
