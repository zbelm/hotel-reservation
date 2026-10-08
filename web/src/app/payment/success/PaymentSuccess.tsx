"use client";

import { useT } from "@/lib/i18n";
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
  const { t } = useT();
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
        <p className="text-sm font-semibold text-good">{t.payment.received}</p>
        <h1 className="mt-3 text-3xl font-semibold">{t.payment.thanks}</h1>
        <p className="mt-3 text-muted">{t.payment.backToApp}</p>
      </div>
    );
  }

  if (status === "confirmed" || status === "checked_in") {
    return (
      <div className="card p-8 text-center">
        <p className="text-sm font-semibold text-good">{t.payment.received}</p>
        <h1 className="mt-3 text-4xl font-semibold">{t.payment.booked}</h1>
        <p className="mt-3 text-muted">{t.payment.bookedBody}</p>
        <Link href={`/booking?id=${id}`} className="btn-primary mt-6">{t.payment.view}</Link>
      </div>
    );
  }

  if (status === "held" && tries < 20) return <Spinner label={t.payment.confirming} />;

  return (
    <div className="grid gap-4">
      <Notice tone="warn">
        {t.payment.waiting}
      </Notice>
      <Link href={`/booking?id=${id}`} className="btn-quiet">{t.payment.check}</Link>
    </div>
  );
}
