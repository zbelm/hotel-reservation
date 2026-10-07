"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { SearchForm } from "@/components/SearchForm";
import { Notice, RoomArt, Spinner } from "@/components/ui";
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

  // Results are tagged with the search they answer, so a new search shows the spinner
  const [state, setState] = useState<{ query: string; results?: SearchResult[]; error?: string }>({ query: "" });

  useEffect(() => {
    let active = true;
    supabase()
      .rpc("search_availability", { p_check_in: checkIn, p_check_out: checkOut, p_adults: adults, p_children: children })
      .then(({ data, error }) => {
        if (!active) return;
        setState(error ? { query, error: error.message } : { query, results: (data as SearchResult[]) ?? [] });
      });
    return () => { active = false; };
  }, [query, checkIn, checkOut, adults, children]);

  const current = state.query === query;
  const results = current ? state.results ?? null : null;
  const error = current ? state.error ?? "" : "";

  return (
    <>
      <SearchForm key={query} compact initial={{ checkIn, checkOut, adults, children }} />

      <div className="mb-6 mt-10 flex flex-wrap items-baseline justify-between gap-2">
        <h1 className="text-3xl font-semibold">Rooms for your stay</h1>
        {checkIn && checkOut && (
          <p className="text-muted">
            {niceDate(checkIn)} to {niceDate(checkOut)} · {guests(adults, children)}
          </p>
        )}
      </div>

      {!isConfigured && <Notice tone="warn">The app isn&rsquo;t connected to Supabase yet. Add the keys from the README to <code>.env.local</code>.</Notice>}
      {error && <Notice tone="error">{error}</Notice>}
      {!results && !error && <Spinner label="Finding rooms" />}
      {results && results.length === 0 && (
        <Notice>No rooms fit {plural(adults, "adult")} on those dates. Try fewer guests or other dates.</Notice>
      )}

      <div className="grid gap-5">
        {results?.map((r) => {
          const soldOut = r.available < 1;
          return (
            <article key={r.room_type_id} className="card grid overflow-hidden sm:grid-cols-[280px_1fr]">
              <div className="h-44 sm:h-full"><RoomArt name={r.name} photo={r.photos?.[0]} /></div>
              <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-end sm:justify-between">
                <div className="max-w-md">
                  <h2 className="text-2xl font-semibold">{r.name}</h2>
                  <p className="mt-1 text-sm text-muted">
                    {r.bed_type} bed · {r.size_sqm} m² · up to {plural(r.max_adults, "adult")}
                  </p>
                  {r.description && <p className="mt-3 text-[15px] leading-relaxed">{r.description}</p>}
                  <ul className="mt-3 flex flex-wrap gap-1.5">
                    {r.amenities.slice(0, 5).map((a) => (
                      <li key={a} className="rounded-full bg-sand px-2.5 py-1 text-xs text-muted">{a}</li>
                    ))}
                  </ul>
                </div>
                <div className="shrink-0 sm:text-right">
                  {soldOut ? (
                    <p className="font-semibold text-bad">Sold out for these dates</p>
                  ) : (
                    <>
                      <p className="text-sm text-muted">from</p>
                      <p className="font-display text-3xl font-semibold">{money(r.lowest_total)}</p>
                      <p className="text-sm text-muted">{plural(r.nights, "night")} · {money(r.lowest_nightly)}/night</p>
                      {r.available <= 2 && <p className="mt-1 text-sm font-semibold text-sun">Only {r.available} left</p>}
                      <Link href={`/room?id=${r.room_type_id}&${stay}`} className="btn-primary mt-3">See rates</Link>
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
