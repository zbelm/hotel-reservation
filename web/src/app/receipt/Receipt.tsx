"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Notice, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { money, nightsBetween } from "@/lib/format";
import { HOTEL } from "@/lib/hotel";
import { useT } from "@/lib/i18n";
import { fmtDate } from "@/lib/messages";
import { useRequireAuth } from "@/lib/useRequireAuth";
import { BOOKING_SELECT, type Booking } from "@/lib/types";

type Payment = { id: string; amount: number; method: string | null; provider: string; status: string; paid_at: string | null; created_at: string };

// A printable summary of the booking and its payments. Guests save it as a PDF with the browser.
export function Receipt() {
  const { session } = useRequireAuth();
  const { t, lang } = useT();
  const id = useSearchParams().get("id") ?? "";
  const [b, setB] = useState<Booking | null>(null);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [error, setError] = useState("");
  const userId = session?.user.id;

  useEffect(() => {
    if (!userId) return;
    const sb = supabase();
    Promise.all([
      sb.from("bookings").select(BOOKING_SELECT).eq("id", id).maybeSingle(),
      sb.from("payments").select("id, amount, method, provider, status, paid_at, created_at").eq("booking_id", id).order("created_at"),
    ]).then(([bk, pay]) => {
      if (bk.error) return setError(bk.error.message);
      if (!bk.data) return setError("NOT_FOUND");
      setB(bk.data as Booking);
      setPayments(((pay.data as Payment[]) ?? []).filter((p) => p.status === "paid" || p.status === "refunded" || p.status === "needs_refund"));
    });
  }, [userId, id]);

  if (error) return <Notice tone="error">{error === "NOT_FOUND" ? t.booking.notFound : error}</Notice>;
  if (!session || !b) return <Spinner />;

  const br = b.booking_rooms?.[0];
  const nights = nightsBetween(b.check_in, b.check_out);
  const balance = Math.max(0, Number(b.total) - Number(b.amount_paid));
  const issued = new Date().toLocaleDateString(t.locale, { timeZone: "Asia/Manila", year: "numeric", month: "long", day: "numeric" });

  return (
    <>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3 print:hidden">
        <Link href={`/booking?id=${b.id}`} className="text-sm font-medium text-sea underline-offset-4 hover:underline">{t.receipt.back}</Link>
        <button className="btn-primary" onClick={() => window.print()}>{t.receipt.print}</button>
      </div>

      <article className="card p-8 print:rounded-none print:border-0 print:p-0">
        <header className="flex flex-wrap items-start justify-between gap-6 border-b border-line pb-6">
          <div>
            <p className="font-display text-2xl font-semibold">{HOTEL.name}</p>
            <p className="mt-1 text-sm text-muted">{HOTEL.address}</p>
            <p className="text-sm text-muted">{HOTEL.phone} · {HOTEL.email}</p>
          </div>
          <div className="text-right">
            <h1 className="text-2xl font-semibold">{t.receipt.title}</h1>
            <p className="mt-1 text-sm text-muted">{t.receipt.issued}: {issued}</p>
          </div>
        </header>

        <dl className="grid gap-x-8 gap-y-3 py-6 text-[15px] sm:grid-cols-2">
          <div><dt className="text-muted">{t.receipt.billedTo}</dt><dd className="font-medium">{b.guest_name}<br /><span className="font-normal text-muted">{b.guest_email}</span></dd></div>
          <div><dt className="text-muted">{t.receipt.booking}</dt><dd className="font-mono font-medium">{b.code}</dd></div>
          <div>
            <dt className="text-muted">{t.receipt.stay}</dt>
            <dd className="font-medium">{fmtDate(b.check_in, lang, true)} – {fmtDate(b.check_out, lang, true)}<br />
              <span className="font-normal text-muted">{t.nights(nights)}, {t.guests(b.adults, b.children)}</span></dd>
          </div>
          <div><dt className="text-muted">{t.receipt.rate}</dt><dd className="font-medium">{br?.room_types?.name}, {br?.rate_plans?.name}</dd></div>
        </dl>

        <table className="w-full text-left text-[15px]">
          <thead className="border-y border-line text-sm text-muted">
            <tr><th className="py-2 font-medium">{t.receipt.night}</th><th className="py-2 text-right font-medium">{t.receipt.amount}</th></tr>
          </thead>
          <tbody className="divide-y divide-line">
            {br?.nightly_prices.map((n) => (
              <tr key={n.date}><td className="py-2">{fmtDate(n.date, lang, true)}</td><td className="py-2 text-right">{money(n.price)}</td></tr>
            ))}
          </tbody>
          <tfoot className="border-t-2 border-ink">
            <tr><td className="pt-3 font-semibold">{t.receipt.total}</td><td className="pt-3 text-right font-display text-xl font-semibold">{money(b.total)}</td></tr>
            <tr><td className="pt-1 text-muted">{t.receipt.paid}</td><td className="pt-1 text-right">{money(b.amount_paid)}</td></tr>
            {Number(b.refund_due) > 0 && <tr><td className="pt-1 text-muted">{t.receipt.refund}</td><td className="pt-1 text-right">{money(b.refund_due)}</td></tr>}
            {balance > 0 && <tr><td className="pt-1 font-semibold">{t.receipt.balance}</td><td className="pt-1 text-right font-semibold">{money(balance)}</td></tr>}
          </tfoot>
        </table>

        <section className="mt-8">
          <h2 className="text-base font-semibold">{t.receipt.payments}</h2>
          {payments.length === 0 ? (
            <p className="mt-2 text-sm text-muted">{t.receipt.noPayments}</p>
          ) : (
            <ul className="mt-2 divide-y divide-line text-sm">
              {payments.map((p) => (
                <li key={p.id} className="flex justify-between gap-4 py-2">
                  <span>{new Date(p.paid_at ?? p.created_at).toLocaleDateString(t.locale, { timeZone: "Asia/Manila", month: "short", day: "numeric", year: "numeric" })}
                    {" · "}{(p.method ?? p.provider).toUpperCase()}</span>
                  <span>{money(p.amount)}</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        <footer className="mt-8 border-t border-line pt-4 text-sm text-muted">
          <p>{t.receipt.vatNote}</p>
          <p className="mt-1">{t.receipt.note}</p>
        </footer>
      </article>
    </>
  );
}
