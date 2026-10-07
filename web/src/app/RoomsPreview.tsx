"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { FORWARD } from "@/components/Page";
import { Notice, RoomArt } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { addDays, money, plural } from "@/lib/format";
import { useToday } from "@/lib/useToday";
import type { RoomType } from "@/lib/types";

export function RoomsPreview() {
  const today = useToday();
  const [rooms, setRooms] = useState<RoomType[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    supabase()
      .from("room_types")
      .select("*")
      .eq("is_active", true)
      .order("sort_order")
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setRooms((data as RoomType[]) ?? []);
      });
  }, []);

  if (error) return <div className="mt-10"><Notice tone="error">Rooms couldn&rsquo;t load: {error}</Notice></div>;

  if (!rooms) {
    return (
      <div className="mt-10 grid gap-10" aria-busy="true" aria-label="Loading rooms">
        {[0, 1, 2].map((i) => (
          <div key={i} className="grid gap-6 md:grid-cols-[5fr_7fr]">
            <div className="skeleton aspect-[4/3]" />
            <div className="space-y-3 py-2">
              <div className="skeleton h-8 w-1/2" />
              <div className="skeleton h-4 w-3/4" />
              <div className="skeleton h-4 w-2/3" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  const stay = (id?: string) => {
    if (!today) return "/search";
    const q = new URLSearchParams({ check_in: addDays(today, 1), check_out: addDays(today, 3), adults: "2", children: "0" });
    return id ? `/room?id=${id}&${q}` : `/search?${q}`;
  };

  return (
    <div className="mt-10 divide-y divide-line">
      {rooms.map((r, i) => (
        <article key={r.id} className="arrive lift grid gap-6 py-8 first:pt-0 md:grid-cols-[5fr_7fr] md:gap-10" style={{ "--i": i } as React.CSSProperties}>
          <Link href={stay(r.id)} transitionTypes={FORWARD} className="block aspect-[4/3] overflow-hidden rounded-2xl" tabIndex={-1} aria-hidden>
            <RoomArt name={r.name} photo={r.photos?.[0]} className="lift-art" />
          </Link>
          <div className="flex flex-col justify-center">
            <h3 className="text-2xl font-semibold sm:text-3xl">{r.name}</h3>
            <p className="mt-2 text-muted">
              {r.bed_type} bed, {r.size_sqm} m², sleeps {plural(r.max_adults, "adult")}
              {r.max_children ? ` and ${plural(r.max_children, "child", "children")}` : ""}
            </p>
            {r.description && <p className="mt-4 max-w-[60ch] text-lg leading-relaxed">{r.description}</p>}
            <ul className="mt-4 flex flex-wrap gap-1.5">
              {r.amenities.map((a) => (
                <li key={a} className="rounded-full border border-line px-2.5 py-1 text-sm text-muted">{a}</li>
              ))}
            </ul>
            <div className="mt-6 flex flex-wrap items-center gap-x-6 gap-y-3">
              <p><span className="font-display text-2xl font-semibold">{money(r.base_price)}</span> <span className="text-muted">a night, flexible rate</span></p>
              <Link href={stay(r.id)} transitionTypes={FORWARD} className="btn-primary">See prices for your dates</Link>
            </div>
          </div>
        </article>
      ))}
    </div>
  );
}
