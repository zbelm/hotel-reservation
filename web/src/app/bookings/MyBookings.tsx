"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { BookingBadge, Notice, PageTitle, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { money, niceDate, plural, nightsBetween, todayManila } from "@/lib/format";
import { useRequireAuth } from "@/lib/useRequireAuth";
import { BOOKING_SELECT, type Booking } from "@/lib/types";

export function MyBookings() {
  const { session } = useRequireAuth();
  const [bookings, setBookings] = useState<Booking[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!session) return;
    supabase()
      .from("bookings")
      .select(BOOKING_SELECT)
      .eq("guest_id", session.user.id)
      .not("status", "eq", "expired")
      .order("check_in", { ascending: false })
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setBookings((data as Booking[]) ?? []);
      });
  }, [session]);

  if (!session || (!bookings && !error)) return <Spinner label="Loading your stays" />;

  const today = todayManila();
  const upcoming = bookings?.filter((b) => b.check_out >= today && ["held", "confirmed", "checked_in"].includes(b.status)) ?? [];
  const past = bookings?.filter((b) => !upcoming.includes(b)) ?? [];

  return (
    <>
      <PageTitle eyebrow="Your account" title="My stays" />
      {error && <Notice tone="error">{error}</Notice>}
      {bookings?.length === 0 && (
        <div className="card p-8 text-center">
          <p className="text-muted">You haven&rsquo;t booked a stay yet.</p>
          <Link href="/" className="btn-primary mt-4">Find a room</Link>
        </div>
      )}
      {upcoming.length > 0 && <BookingList title="Upcoming" items={upcoming} />}
      {past.length > 0 && <BookingList title="Past and cancelled" items={past} />}
    </>
  );
}

function BookingList({ title, items }: { title: string; items: Booking[] }) {
  return (
    <section className="mb-10">
      <h2 className="mb-3 text-xl font-semibold">{title}</h2>
      <ul className="grid gap-3">
        {items.map((b) => (
          <li key={b.id}>
            <Link href={`/booking?id=${b.id}`} className="card flex flex-wrap items-center justify-between gap-3 p-5 transition-colors hover:border-sea">
              <div>
                <p className="font-display text-xl font-semibold">{b.booking_rooms?.[0]?.room_types?.name ?? "Room"}</p>
                <p className="text-sm text-muted">
                  {niceDate(b.check_in, true)} to {niceDate(b.check_out)} · {plural(nightsBetween(b.check_in, b.check_out), "night")} · {b.code}
                </p>
              </div>
              <div className="flex items-center gap-4">
                <span className="font-semibold">{money(b.total)}</span>
                <BookingBadge status={b.status} />
              </div>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
