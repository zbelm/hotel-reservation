"use client";

import { useT } from "@/lib/i18n";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { PayNowButton } from "@/components/PayNowButton";
import { ONLINE_PAYMENTS } from "@/lib/hotel";

export function PaymentCancelled() {
  const { t } = useT();
  const id = useSearchParams().get("booking") ?? "";
  const { session, loading } = useAuth();

  return (
    <div className="card p-8 text-center">
      <h1 className="text-3xl font-semibold">{t.payment.notCompleted}</h1>
      <p className="mt-3 text-muted">{t.payment.noMoney}</p>
      {!loading && (session ? (
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          {ONLINE_PAYMENTS && id && <PayNowButton bookingId={id} label={t.payment.tryAgain} />}
          {id ? <Link href={`/booking?id=${id}`} className="btn-quiet">{t.payment.viewBooking}</Link> : <Link href="/bookings" className="btn-quiet">{t.nav.myStays}</Link>}
        </div>
      ) : (
        <p className="mt-6 text-sm text-muted">{t.payment.inApp}</p>
      ))}
    </div>
  );
}
