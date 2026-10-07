"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Notice, RoomArt, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { guests, money, niceDate, plural } from "@/lib/format";
import type { Offer, RoomType } from "@/lib/types";

export function RoomDetails() {
  const params = useSearchParams();
  const id = params.get("id") ?? "";
  const checkIn = params.get("check_in") ?? "";
  const checkOut = params.get("check_out") ?? "";
  const adults = Number(params.get("adults") ?? 2);
  const children = Number(params.get("children") ?? 0);

  const [room, setRoom] = useState<RoomType | null>(null);
  const [offers, setOffers] = useState<Offer[] | null>(null);
  const [error, setError] = useState("");
  const [open, setOpen] = useState<string | null>(null);

  useEffect(() => {
    const sb = supabase();
    Promise.all([
      sb.from("room_types").select("*").eq("id", id).maybeSingle(),
      sb.rpc("room_type_offers", { p_room_type_id: id, p_check_in: checkIn, p_check_out: checkOut }),
    ]).then(([r, o]) => {
      if (r.error || o.error) setError((r.error ?? o.error)!.message);
      else if (!r.data) setError("This room type no longer exists.");
      else {
        setRoom(r.data as RoomType);
        setOffers((o.data as Offer[]) ?? []);
      }
    });
  }, [id, checkIn, checkOut]);

  if (error) return <Notice tone="error">{error}</Notice>;
  if (!room || !offers) return <Spinner label="Loading room" />;

  const back = new URLSearchParams({ check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });

  return (
    <div className="grid gap-8 lg:grid-cols-[1.1fr_1fr]">
      <div>
        <Link href={`/search?${back}`} className="text-sm font-medium text-sea hover:underline">&larr; All rooms</Link>
        <div className="card mt-4 h-72 overflow-hidden"><RoomArt name={room.name} photo={room.photos?.[0]} /></div>
        <h1 className="mt-6 text-4xl font-semibold">{room.name}</h1>
        <p className="mt-2 text-muted">
          {room.bed_type} bed · {room.size_sqm} m² · up to {plural(room.max_adults, "adult")}
          {room.max_children ? ` and ${plural(room.max_children, "child", "children")}` : ""}
        </p>
        {room.description && <p className="mt-4 text-lg leading-relaxed">{room.description}</p>}
        <h2 className="mt-8 text-lg font-semibold">In the room</h2>
        <ul className="mt-3 grid grid-cols-2 gap-2 text-[15px]">
          {room.amenities.map((a) => (
            <li key={a} className="flex items-center gap-2"><span className="h-1.5 w-1.5 rounded-full bg-sea" />{a}</li>
          ))}
        </ul>
      </div>

      <div>
        <div className="card p-5">
          <p className="label">Your stay</p>
          <p className="font-display text-xl">{niceDate(checkIn)} &rarr; {niceDate(checkOut)}</p>
          <p className="text-sm text-muted">{guests(adults, children)}</p>
        </div>

        <h2 className="mb-3 mt-8 text-xl font-semibold">Choose a rate</h2>
        {offers.length === 0 && <Notice>No rates are open for these dates.</Notice>}
        <div className="grid gap-3">
          {offers.map((o) => {
            const reserve = new URLSearchParams({ id, plan: o.rate_plan_id, check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });
            return (
              <div key={o.rate_plan_id} className="card p-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <h3 className="text-lg font-semibold">{o.name}</h3>
                    <p className="mt-1 text-sm text-muted">{o.description}</p>
                    <p className={`mt-2 text-sm font-medium ${o.refundable ? "text-good" : "text-sun"}`}>
                      {o.refundable ? `Free cancellation until ${o.free_cancel_hours}h before check-in` : "Non-refundable"}
                      {o.includes_breakfast ? " · Breakfast included" : ""}
                    </p>
                  </div>
                  <div className="shrink-0 text-right">
                    <p className="font-display text-2xl font-semibold">{money(o.total)}</p>
                    <button className="text-xs text-muted underline-offset-2 hover:underline" onClick={() => setOpen(open === o.rate_plan_id ? null : o.rate_plan_id)}>
                      {open === o.rate_plan_id ? "Hide" : "Price per night"}
                    </button>
                  </div>
                </div>
                {open === o.rate_plan_id && (
                  <ul className="mt-3 divide-y divide-line border-t border-line text-sm">
                    {o.nightly.map((n) => (
                      <li key={n.date} className="flex justify-between py-1.5"><span>{niceDate(n.date)}</span><span>{money(n.price)}</span></li>
                    ))}
                  </ul>
                )}
                <div className="mt-4 flex items-center justify-between gap-3">
                  {!o.bookable ? (
                    <p className="text-sm text-bad">{o.available < 1 ? "Sold out for these dates" : `Needs a stay of ${o.min_stay}+ nights`}</p>
                  ) : (
                    <>
                      <p className="text-sm text-muted">{o.available <= 2 ? `Only ${o.available} left` : ""}</p>
                      <Link href={`/checkout?${reserve}`} className="btn-primary">Reserve</Link>
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
