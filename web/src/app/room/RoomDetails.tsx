"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Chevron } from "@/components/Icons";
import { BACK, FORWARD } from "@/components/Page";
import { Steps } from "@/components/Steps";
import { Notice, RoomArt } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { guests, money, niceDate, plural } from "@/lib/format";
import { HOTEL } from "@/lib/hotel";
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

  const back = new URLSearchParams({ check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });

  if (error) return <Notice tone="error">{error}</Notice>;
  if (!room || !offers) return <RoomSkeleton />;

  const fits = adults <= room.max_adults && children <= room.max_children;

  return (
    <>
      <Steps current={2} />
      <div className="grid gap-10 lg:grid-cols-[1.1fr_1fr] lg:gap-x-10 lg:gap-y-0">
        <div className="lg:col-start-1 lg:row-start-1">
          <Link href={`/search?${back}`} transitionTypes={BACK} className="text-sm font-medium text-sea underline-offset-4 hover:underline">
            Back to all rooms
          </Link>
          <div className="mt-4 aspect-[16/10] overflow-hidden rounded-2xl"><RoomArt name={room.name} photo={room.photos?.[0]} /></div>
          <h1 className="mt-7 text-4xl font-semibold sm:text-5xl">{room.name}</h1>
          <p className="mt-3 text-muted">
            {room.bed_type} bed, {room.size_sqm} m², up to {plural(room.max_adults, "adult")}
            {room.max_children ? ` and ${plural(room.max_children, "child", "children")}` : ""}
          </p>
          {room.description && <p className="mt-5 max-w-[60ch] text-lg leading-relaxed">{room.description}</p>}
        </div>

        <div className="lg:col-start-1 lg:row-start-2">
          <h2 className="text-xl font-semibold lg:mt-10">In the room</h2>
          <ul className="mt-4 grid grid-cols-2 gap-x-6 gap-y-2.5 text-[15px]">
            {room.amenities.map((a) => (
              <li key={a} className="flex items-center gap-2.5"><span aria-hidden className="h-1.5 w-1.5 rounded-full bg-narra" />{a}</li>
            ))}
          </ul>

          <div className="mt-10 rounded-2xl bg-sea-tint p-6">
            <h2 className="text-xl font-semibold">Good to know</h2>
            <dl className="mt-4 grid gap-3 text-[15px] sm:grid-cols-2">
              <div><dt className="text-muted">Check-in</dt><dd className="font-medium">From {HOTEL.checkIn}, with a valid ID</dd></div>
              <div><dt className="text-muted">Check-out</dt><dd className="font-medium">By {HOTEL.checkOut}</dd></div>
              <div><dt className="text-muted">Payment</dt><dd className="font-medium">In full when you book, taxes included</dd></div>
              <div><dt className="text-muted">Front desk</dt><dd className="font-medium">Open 24 hours</dd></div>
            </dl>
            <Link href="/#policies" className="mt-4 inline-block text-sm font-medium text-sea underline-offset-4 hover:underline">Read all house rules</Link>
          </div>
        </div>

        <div className="lg:sticky lg:top-20 lg:col-start-2 lg:row-span-2 lg:row-start-1 lg:self-start">
          <div className="card p-5">
            <p className="text-sm text-muted">Your stay</p>
            <p className="mt-1 font-display text-2xl font-semibold">{niceDate(checkIn)} to {niceDate(checkOut)}</p>
            <p className="text-muted">{plural(Math.max(1, offers[0]?.nightly.length ?? 1), "night")}, {guests(adults, children)}</p>
            <Link href={`/search?${back}`} transitionTypes={BACK} className="mt-2 inline-block text-sm font-medium text-sea underline-offset-4 hover:underline">Change dates or guests</Link>
          </div>

          {!fits && (
            <div className="mt-4"><Notice tone="warn">This room fits up to {plural(room.max_adults, "adult")} and {plural(room.max_children, "child", "children")}. Choose fewer guests or another room.</Notice></div>
          )}

          <h2 className="mb-4 mt-8 text-2xl font-semibold">Choose a rate</h2>
          {offers.length === 0 && <Notice>No rates are open for these dates.</Notice>}
          <div className="grid gap-4">
            {offers.map((o, i) => {
              const reserve = new URLSearchParams({ id, plan: o.rate_plan_id, check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });
              return (
                <div key={o.rate_plan_id} className="arrive card p-5" style={{ "--i": i } as React.CSSProperties}>
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <h3 className="text-lg font-semibold">{o.name}</h3>
                      <p className="mt-1 text-sm text-muted">{o.description}</p>
                    </div>
                    <p className="shrink-0 font-display text-2xl font-semibold">{money(o.total)}</p>
                  </div>
                  <ul className="mt-3 space-y-1 text-sm">
                    <li className={o.refundable ? "text-good" : "text-sun"}>
                      {o.refundable ? `Free cancellation until ${o.free_cancel_hours} hours before check-in` : "Non-refundable: no refund if you cancel"}
                    </li>
                    <li className="text-muted">{o.includes_breakfast ? "Breakfast for two each morning" : "Breakfast not included (₱450 a person in the café)"}</li>
                  </ul>
                  <details className="disclose mt-3 border-t border-line">
                    <summary className="flex items-center justify-between py-2.5 text-sm text-muted hover:text-ink">
                      Price for each night
                      <Chevron className="chev h-4 w-4" />
                    </summary>
                    <ul className="divide-y divide-line pb-1 text-sm">
                      {o.nightly.map((n) => (
                        <li key={n.date} className="flex justify-between py-1.5"><span>{niceDate(n.date)}</span><span>{money(n.price)}</span></li>
                      ))}
                    </ul>
                  </details>
                  <div className="mt-3 flex items-center justify-between gap-3">
                    {!o.bookable || !fits ? (
                      <p className="text-sm text-bad">
                        {!fits ? "Too many guests for this room" : o.available < 1 ? "Sold out for these dates" : `Needs a stay of ${o.min_stay} or more nights`}
                      </p>
                    ) : (
                      <>
                        <p className="text-sm font-medium text-sun">{o.available <= 2 ? `Only ${o.available} left` : ""}</p>
                        <Link href={`/checkout?${reserve}`} transitionTypes={FORWARD} className="btn-primary">Reserve this rate</Link>
                      </>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </>
  );
}

function RoomSkeleton() {
  return (
    <div className="grid gap-10 lg:grid-cols-[1.1fr_1fr]" aria-busy="true" aria-label="Loading room">
      <div className="space-y-4">
        <div className="skeleton aspect-[16/10]" />
        <div className="skeleton h-10 w-2/3" />
        <div className="skeleton h-4 w-1/2" />
      </div>
      <div className="space-y-4">
        <div className="skeleton h-28" />
        <div className="skeleton h-44" />
        <div className="skeleton h-44" />
      </div>
    </div>
  );
}
