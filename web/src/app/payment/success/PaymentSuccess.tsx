"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Notice, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/components/AuthProvider";
import type { BookingStatus } from "@/lib/types";

// PayMongo sends the guest here right away; the booking is confirmed a few
// seconds later when PayMongo's webhook reaches Supabase. Poll until then.
export function PaymentSuccess() {
  const id = useSearchParams().get("booking") ?? "";
  const { session, loading } = useAuth();
  const [status, setStatus] = useState<BookingStatus | null>(null);
  const [tries, setTries] = useState(0);

  useEffect(() => {
    if (!session || !id) return;
    let stop = false;
    let n = 0;
    async function poll() {
      const { data } = await supabase().from("bookings").select("status").eq("id", id).maybeSingle();
      if (stop) return;
      const s = (data?.status ?? null) as BookingStatus | null;
      setStatus(s);
      setTries(++n);
      if (s === "held" && n < 20) setTimeout(poll, 2000);
    }
    poll();
    return () => { stop = true; };
  }, [session, id]);

  if (loading) return <Spinner />;

  // Guests paying from the mobile app land here in their phone's browser, signed out
  if (!session) {
    return (
      <div className="card p-8 text-center">
        <p className="text-sm font-semibold text-good">Payment received</p>
        <h1 className="mt-3 text-3xl font-semibold">Thank you.</h1>
        <p className="mt-3 text-muted">
          You can close this page and go back to the app. Your booking will show as confirmed within a minute.
        </p>
      </div>
    );
  }

  if (status === "confirmed" || status === "checked_in") {
    return (
      <div className="card p-8 text-center">
        <p className="text-sm font-semibold text-good">Payment received</p>
        <h1 className="mt-3 text-4xl font-semibold">You&rsquo;re booked.</h1>
        <p className="mt-3 text-muted">A receipt is on its way to your email. Show the QR code on your booking at the front desk.</p>
        <Link href={`/booking?id=${id}`} className="btn-primary mt-6">View my booking</Link>
      </div>
    );
  }

  if (status === "held" && tries < 20) return <Spinner label="Confirming your payment with PayMongo" />;

  return (
    <div className="grid gap-4">
      <Notice tone="warn">
        We haven&rsquo;t received confirmation from PayMongo yet. If you paid, your booking will update shortly; you don&rsquo;t need to pay again.
      </Notice>
      <Link href={`/booking?id=${id}`} className="btn-quiet">Check my booking</Link>
    </div>
  );
}
