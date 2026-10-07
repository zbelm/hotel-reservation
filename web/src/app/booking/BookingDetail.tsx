"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { QRCodeSVG } from "qrcode.react";
import { BookingBadge, Notice, Spinner } from "@/components/ui";
import { PayNowButton } from "@/components/PayNowButton";
import { supabase } from "@/lib/supabase";
import { guests, money, niceDate, niceTime, plural, nightsBetween } from "@/lib/format";
import { useRequireAuth } from "@/lib/useRequireAuth";
import { HOTEL, arrivalLabel, mapsUrl } from "@/lib/hotel";
import { Steps } from "@/components/Steps";
import { BOOKING_SELECT, type Booking } from "@/lib/types";

export function BookingDetail() {
  const { session } = useRequireAuth();
  const params = useSearchParams();
  const id = params.get("id") ?? "";
  const paymentError = params.get("payment_error");

  const [b, setB] = useState<Booking | null>(null);
  const [error, setError] = useState("");
  const [confirming, setConfirming] = useState(false);
  const [cancelMsg, setCancelMsg] = useState("");

  const [version, setVersion] = useState(0); // bump to reload
  const userId = session?.user.id;

  useEffect(() => {
    if (!userId) return;
    supabase().from("bookings").select(BOOKING_SELECT).eq("id", id).maybeSingle()
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else if (!data) setError("Booking not found.");
        else setB(data as Booking);
      });
  }, [userId, id, version]);

  const load = () => setVersion((v) => v + 1);

  async function cancel() {
    const { data, error } = await supabase().rpc("cancel_booking", { p_booking_id: id });
    setConfirming(false);
    if (error) return setError(error.message);
    const refund = Number(data?.refund_due ?? 0);
    setCancelMsg(refund > 0
      ? `Booking cancelled. A refund of ${money(refund)} will be sent to your original payment method.`
      : "Booking cancelled.");
    load();
  }

  if (error) return <Notice tone="error">{error}</Notice>;
  if (!session || !b) return <Spinner label="Loading booking" />;

  const br = b.booking_rooms?.[0];
  const plan = br?.rate_plans;
  const nights = nightsBetween(b.check_in, b.check_out);
  const holdActive = b.status === "held" && b.hold_expires_at && new Date(b.hold_expires_at) > new Date();
  const balance = Number(b.total) - Number(b.amount_paid);

  return (
    <>
      {b.status === "held" && <Steps current={4} />}
      <Link href="/bookings" className="text-sm font-medium text-sea underline-offset-4 hover:underline">All my stays</Link>
      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-4xl font-semibold">{br?.room_types?.name ?? "Your stay"}</h1>
        <BookingBadge status={b.status} />
      </div>
      <p className="mt-1 text-muted">Booking {b.code}{plan?.name ? `, ${plan.name}` : ""}</p>

      <div className="mt-6 grid gap-3">
        {paymentError && b.status === "held" && <Notice tone="error">Payment couldn&rsquo;t start: {paymentError}</Notice>}
        {cancelMsg && <Notice tone="good">{cancelMsg}</Notice>}
        {holdActive && (
          <Notice tone="warn">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <span>Your room is held until <strong>{niceTime(b.hold_expires_at!)}</strong>. Pay before then to confirm it.</span>
              <PayNowButton bookingId={b.id} />
            </div>
          </Notice>
        )}
        {b.status === "held" && !holdActive && (
          <Notice tone="error">This hold has ended and the room was released. <Link href="/" className="underline">Book again</Link></Notice>
        )}
        {Number(b.refund_due) > 0 && (
          <Notice>Refund due: <strong>{money(b.refund_due)}</strong>. The hotel will send it to your original payment method.</Notice>
        )}
      </div>

      <div className="mt-8 grid gap-6 md:grid-cols-[1fr_260px]">
        <div className="card p-6">
          <dl className="grid grid-cols-2 gap-y-3 text-[15px]">
            <dt className="text-muted">Check-in</dt><dd className="text-right">{niceDate(b.check_in, true)}, from {HOTEL.checkIn}</dd>
            <dt className="text-muted">Check-out</dt><dd className="text-right">{niceDate(b.check_out, true)}, by {HOTEL.checkOut}</dd>
            <dt className="text-muted">Guests</dt><dd className="text-right">{guests(b.adults, b.children)}</dd>
            <dt className="text-muted">Guest</dt><dd className="text-right">{b.guest_name}</dd>
            {arrivalLabel(b.arrival_time) && (<><dt className="text-muted">Arriving</dt><dd className="text-right">{arrivalLabel(b.arrival_time)}</dd></>)}
            {b.special_requests && (<><dt className="text-muted">Requests</dt><dd className="text-right">{b.special_requests}</dd></>)}
            {br?.rooms?.number && (<><dt className="text-muted">Room</dt><dd className="text-right">{br.rooms.number}</dd></>)}
            {plan && (<><dt className="text-muted">Cancellation</dt><dd className="text-right">{plan.refundable ? `Free until ${plan.free_cancel_hours}h before check-in` : "Non-refundable"}</dd></>)}
          </dl>
          <ul className="mt-5 divide-y divide-line border-t border-line text-sm">
            {br?.nightly_prices.map((n) => (
              <li key={n.date} className="flex justify-between py-2"><span>{niceDate(n.date)}</span><span>{money(n.price)}</span></li>
            ))}
          </ul>
          <div className="mt-2 flex items-baseline justify-between border-t border-line pt-4">
            <span className="font-semibold">Total for {plural(nights, "night")}</span>
            <span className="font-display text-2xl font-semibold">{money(b.total)}</span>
          </div>
          <p className="mt-1 text-right text-sm text-muted">
            Paid {money(b.amount_paid)}{balance > 0 && b.status !== "held" ? `, ${money(balance)} still to pay` : ""}
          </p>
        </div>

        {["confirmed", "checked_in"].includes(b.status) && (
          <div className="card flex flex-col items-center p-6 text-center">
            <div className="rounded-xl bg-white p-3"><QRCodeSVG value={b.code} size={176} /></div>
            <p className="mt-3 font-mono text-lg font-semibold tracking-widest">{b.code}</p>
            <p className="mt-1 text-sm text-muted">Show this at the front desk</p>
          </div>
        )}
      </div>

      {["held", "confirmed"].includes(b.status) && (
        <section className="mt-8 rounded-2xl bg-sea-tint p-6">
          <h2 className="text-xl font-semibold">Before you arrive</h2>
          <ul className="mt-4 grid gap-3 text-[15px] sm:grid-cols-2">
            <li><span className="text-muted">Where</span><br />{HOTEL.address}<br /><a href={mapsUrl} target="_blank" rel="noreferrer" className="font-medium text-sea underline-offset-4 hover:underline">Get directions</a></li>
            <li><span className="text-muted">Bring</span><br />A valid ID for {b.guest_name}</li>
            <li><span className="text-muted">Check-in</span><br />From {HOTEL.checkIn}. Show the QR code at the front desk.</li>
            <li><span className="text-muted">Need anything?</span><br /><a href={`tel:${HOTEL.phone.replace(/\s/g, "")}`} className="font-medium text-sea underline-offset-4 hover:underline">{HOTEL.phone}</a>, open 24 hours</li>
          </ul>
        </section>
      )}

      {b.status === "confirmed" && (
        <div className="mt-8">
          {!confirming ? (
            <button className="btn-danger" onClick={() => setConfirming(true)}>Cancel booking</button>
          ) : (
            <div className="card grid gap-3 p-5">
              <p className="font-semibold">Cancel this booking?</p>
              <p className="text-sm text-muted">
                {plan?.refundable
                  ? `Free if it's more than ${plan.free_cancel_hours} hours before check-in; after that the first night is kept.`
                  : "This rate is non-refundable, so no money will be returned."}
              </p>
              <div className="flex gap-3">
                <button className="btn-danger" onClick={cancel}>Yes, cancel</button>
                <button className="btn-quiet" onClick={() => setConfirming(false)}>Keep booking</button>
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}
