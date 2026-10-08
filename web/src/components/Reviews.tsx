"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";
import type { Review } from "@/lib/types";

export function Stars({ rating, className = "" }: { rating: number; className?: string }) {
  return (
    <span className={`inline-flex gap-0.5 text-mango ${className}`} aria-hidden>
      {[1, 2, 3, 4, 5].map((n) => (
        <svg key={n} viewBox="0 0 20 20" className="h-4 w-4" fill={n <= rating ? "currentColor" : "none"} stroke="currentColor" strokeWidth="1.4">
          <path d="M10 2.5l2.3 4.9 5.2.6-3.9 3.6 1.1 5.2L10 14.2l-4.7 2.6 1.1-5.2L2.5 8l5.2-.6z" />
        </svg>
      ))}
    </span>
  );
}

/** Published reviews from verified stays: the whole hotel, or one room type. */
export function Reviews({ roomTypeId, limit = 6, compact = false }: { roomTypeId?: string; limit?: number; compact?: boolean }) {
  const { t } = useT();
  const [data, setData] = useState<{ list: Review[]; count: number; average: number | null } | null>(null);

  useEffect(() => {
    const sb = supabase();
    let q = sb.from("reviews").select("*").eq("is_published", true).order("created_at", { ascending: false }).limit(limit);
    if (roomTypeId) q = q.eq("room_type_id", roomTypeId);
    Promise.all([q, sb.rpc("review_summary", { p_room_type_id: roomTypeId ?? null })]).then(([r, s]) => {
      const sum = (s.data ?? {}) as { count?: number; average?: number | null };
      setData({ list: (r.data as Review[]) ?? [], count: sum.count ?? 0, average: sum.average ?? null });
    });
  }, [roomTypeId, limit]);

  if (!data) return <div className="skeleton mt-6 h-28" aria-busy="true" />;

  if (data.count === 0) {
    return compact ? null : <p className="mt-6 max-w-xl text-muted">{t.reviews.none}</p>;
  }

  const month = (iso: string) => new Date(`${iso}T00:00:00Z`).toLocaleDateString(t.locale, { month: "long", year: "numeric", timeZone: "UTC" });

  return (
    <div className="mt-6">
      <p className="flex items-center gap-3 text-lg">
        <Stars rating={Math.round(data.average ?? 0)} />
        <span className="font-semibold">{t.reviews.average(String(data.average), data.count)}</span>
      </p>
      <ul className={`mt-6 grid gap-x-10 gap-y-8 ${compact ? "" : "md:grid-cols-2"}`}>
        {data.list.map((r) => (
          <li key={r.id} className="border-t border-line pt-5">
            <div className="flex items-center justify-between gap-3">
              <span className="sr-only">{t.reviews.stars(r.rating)}</span>
              <Stars rating={r.rating} />
              <span className="text-sm text-muted">{t.reviews.stayed(month(r.stayed_on))}</span>
            </div>
            {r.body && <p className="mt-3 max-w-[60ch] text-[17px] leading-relaxed">{r.body}</p>}
            <p className="mt-2 text-sm font-semibold">{r.display_name}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
