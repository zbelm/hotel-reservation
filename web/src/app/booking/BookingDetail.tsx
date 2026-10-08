"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import { useSearchParams } from "next/navigation";
import { QRCodeSVG } from "qrcode.react";
import { BookingBadge, Notice, Spinner } from "@/components/ui";
import { DateRangePicker } from "@/components/DateRangePicker";
import { PayNowButton } from "@/components/PayNowButton";
import { Stars } from "@/components/Reviews";
import { Steps } from "@/components/Steps";
import { supabase } from "@/lib/supabase";
import { money, nightsBetween } from "@/lib/format";
import { HOTEL, arrivalLabel, mapsUrl } from "@/lib/hotel";
import { useT } from "@/lib/i18n";
import { fmtDate, fmtTime } from "@/lib/messages";
import { useRequireAuth } from "@/lib/useRequireAuth";
import { BOOKING_SELECT, type Booking, type Review } from "@/lib/types";

export function BookingDetail() {
  const { session } = useRequireAuth();
  const { t, lang } = useT();
  const params = useSearchParams();
  const id = params.get("id") ?? "";
  const paymentError = params.get("payment_error");

  const [b, setB] = useState<Booking | null>(null);
  const [error, setError] = useState("");
  const [confirming, setConfirming] = useState(false);
  const [notice, setNotice] = useState("");

  const [version, setVersion] = useState(0); // bump to reload
  const userId = session?.user.id;

  useEffect(() => {
    if (!userId) return;
    supabase().from("bookings").select(BOOKING_SELECT).eq("id", id).maybeSingle()
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else if (!data) setError("NOT_FOUND");
        else setB(data as Booking);
      });
  }, [userId, id, version]);

  const load = () => setVersion((v) => v + 1);

  async function cancel() {
    const { data, error } = await supabase().rpc("cancel_booking", { p_booking_id: id });
    setConfirming(false);
    if (error) return setError(error.message);
    const refund = Number(data?.refund_due ?? 0);
    setNotice(refund > 0 ? t.booking.cancelledRefund(money(refund)) : t.booking.cancelled);
    load();
  }

  if (error) return <Notice tone="error">{error === "NOT_FOUND" ? t.booking.notFound : error}</Notice>;
  if (!session || !b) return <Spinner label={t.booking.loading} />;

  const br = b.booking_rooms?.[0];
  const plan = br?.rate_plans;
  const nights = nightsBetween(b.check_in, b.check_out);
  const holdActive = b.status === "held" && b.hold_expires_at && new Date(b.hold_expires_at) > new Date();
  const balance = Number(b.total) - Number(b.amount_paid);
  const arriving = arrivalLabel(b.arrival_time, lang);
  const upcoming = ["held", "confirmed"].includes(b.status);
  const hasReceipt = Number(b.amount_paid) > 0 || ["confirmed", "checked_in", "checked_out"].includes(b.status);

  return (
    <>
      {b.status === "held" && <Steps current={4} />}
      <Link href="/bookings" className="text-sm font-medium text-sea underline-offset-4 hover:underline">{t.booking.all}</Link>
      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-4xl font-semibold">{br?.room_types?.name ?? t.booking.yourStay}</h1>
        <BookingBadge status={b.status} label={t.status[b.status]} />
      </div>
      <p className="mt-1 text-muted">{t.booking.code(b.code, plan?.name)}</p>

      <div className="mt-6 grid gap-3">
        {paymentError && b.status === "held" && <Notice tone="error">{t.booking.payFailed(paymentError)}</Notice>}
        {notice && <Notice tone="good">{notice}</Notice>}
        {holdActive && (
          <Notice tone="warn">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <span>{t.booking.heldUntil} <strong>{fmtTime(b.hold_expires_at!, lang)}</strong>{t.booking.heldAfter}</span>
              <PayNowButton bookingId={b.id} />
            </div>
          </Notice>
        )}
        {b.status === "held" && !holdActive && (
          <Notice tone="error">{t.booking.holdEnded} <Link href="/" className="underline">{t.booking.bookAgain}</Link></Notice>
        )}
        {Number(b.refund_due) > 0 && <Notice>{t.booking.refundDue(money(b.refund_due))}</Notice>}
      </div>

      <div className="mt-8 grid gap-6 md:grid-cols-[1fr_260px]">
        <div className="card p-6">
          <dl className="grid grid-cols-2 gap-y-3 text-[15px]">
            <dt className="text-muted">{t.booking.checkIn}</dt><dd className="text-right">{t.booking.checkInValue(fmtDate(b.check_in, lang, true), HOTEL.checkIn)}</dd>
            <dt className="text-muted">{t.booking.checkOut}</dt><dd className="text-right">{t.booking.checkOutValue(fmtDate(b.check_out, lang, true), HOTEL.checkOut)}</dd>
            <dt className="text-muted">{t.booking.guests}</dt><dd className="text-right">{t.guests(b.adults, b.children)}</dd>
            <dt className="text-muted">{t.booking.guest}</dt><dd className="text-right">{b.guest_name}</dd>
            {arriving && (<><dt className="text-muted">{t.booking.arriving}</dt><dd className="text-right">{arriving}</dd></>)}
            {b.special_requests && (<><dt className="text-muted">{t.booking.requests}</dt><dd className="text-right">{b.special_requests}</dd></>)}
            {br?.rooms?.number && (<><dt className="text-muted">{t.booking.room}</dt><dd className="text-right">{br.rooms.number}</dd></>)}
            {plan && (<><dt className="text-muted">{t.booking.cancellation}</dt><dd className="text-right">{plan.refundable ? t.booking.freeUntil(plan.free_cancel_hours) : t.booking.nonRefundable}</dd></>)}
          </dl>
          <ul className="mt-5 divide-y divide-line border-t border-line text-sm">
            {br?.nightly_prices.map((n) => (
              <li key={n.date} className="flex justify-between py-2"><span>{fmtDate(n.date, lang)}</span><span>{money(n.price)}</span></li>
            ))}
          </ul>
          <div className="mt-2 flex items-baseline justify-between border-t border-line pt-4">
            <span className="font-semibold">{t.booking.totalFor(t.nights(nights))}</span>
            <span className="font-display text-2xl font-semibold">{money(b.total)}</span>
          </div>
          <p className="mt-1 text-right text-sm text-muted">
            {t.booking.paid(money(b.amount_paid))}{balance > 0 && b.status !== "held" ? `, ${t.booking.toPay(money(balance))}` : ""}
          </p>
          {hasReceipt && (
            <div className="mt-4 border-t border-line pt-4 text-right">
              <Link href={`/receipt?id=${b.id}`} className="text-sm font-medium text-sea underline-offset-4 hover:underline">{t.booking.receipt}</Link>
            </div>
          )}
        </div>

        {["confirmed", "checked_in"].includes(b.status) && (
          <div className="card flex flex-col items-center self-start p-6 text-center">
            <div className="rounded-xl bg-white p-3"><QRCodeSVG value={b.code} size={176} /></div>
            <p className="mt-3 font-mono text-lg font-semibold tracking-widest">{b.code}</p>
            <p className="mt-1 text-sm text-muted">{t.booking.showQr}</p>
          </div>
        )}
      </div>

      {b.status === "confirmed" && plan && (
        <ChangeDates booking={b} refundable={plan.refundable} onChanged={(msg) => { setNotice(msg); load(); }} />
      )}

      {upcoming && <IdUpload booking={b} onChanged={load} />}

      {upcoming && (
        <section className="mt-8 rounded-2xl bg-sea-tint p-6">
          <h2 className="text-xl font-semibold">{t.booking.beforeArrive}</h2>
          <ul className="mt-4 grid gap-3 text-[15px] sm:grid-cols-2">
            <li><span className="text-muted">{t.booking.where}</span><br />{HOTEL.address}<br /><a href={mapsUrl} target="_blank" rel="noreferrer" className="font-medium text-sea underline-offset-4 hover:underline">{t.booking.directions}</a></li>
            <li><span className="text-muted">{t.booking.bring}</span><br />{t.booking.idFor(b.guest_name)}</li>
            <li><span className="text-muted">{t.booking.checkIn}</span><br />{t.booking.checkInTip(HOTEL.checkIn)}</li>
            <li><span className="text-muted">{t.booking.needAnything}</span><br /><a href={`tel:${HOTEL.phone.replace(/\s/g, "")}`} className="font-medium text-sea underline-offset-4 hover:underline">{HOTEL.phone}</a>, {t.booking.open24}</li>
          </ul>
        </section>
      )}

      {b.status === "checked_out" && <ReviewForm booking={b} />}

      {b.status === "confirmed" && (
        <div className="mt-8">
          {!confirming ? (
            <button className="btn-danger" onClick={() => setConfirming(true)}>{t.booking.cancel}</button>
          ) : (
            <div className="card grid gap-3 p-5">
              <p className="font-semibold">{t.booking.cancelQ}</p>
              <p className="text-sm text-muted">{plan?.refundable ? t.booking.cancelFree(plan.free_cancel_hours) : t.booking.cancelNonRef}</p>
              <div className="flex gap-3">
                <button className="btn-danger" onClick={cancel}>{t.booking.yesCancel}</button>
                <button className="btn-quiet" onClick={() => setConfirming(false)}>{t.booking.keep}</button>
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}

// ---------------------------------------------------------------------------
type Quote = { total: number; old_total: number; balance_due: number; refund_due: number; check_in: string; check_out: string };

function ChangeDates({ booking, refundable, onChanged }: { booking: Booking; refundable: boolean; onChanged: (msg: string) => void }) {
  const { t, lang } = useT();
  const [open, setOpen] = useState(false);
  const [checkIn, setCheckIn] = useState(booking.check_in);
  const [checkOut, setCheckOut] = useState(booking.check_out);
  const [quote, setQuote] = useState<Quote | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function run(preview: boolean) {
    setBusy(true);
    setError("");
    const { data, error } = await supabase().rpc("change_booking_dates", {
      p_booking_id: booking.id, p_check_in: checkIn, p_check_out: checkOut, p_preview: preview,
    });
    setBusy(false);
    if (error) return setError(error.message);
    if (preview) setQuote(data as Quote);
    else {
      setOpen(false);
      setQuote(null);
      onChanged(t.changeDates.done);
    }
  }

  if (!refundable) {
    return <p className="mt-8 text-sm text-muted">{t.changeDates.notAllowedNonRef}</p>;
  }

  if (!open) {
    return <button className="btn-quiet mt-8" onClick={() => setOpen(true)}>{t.changeDates.button}</button>;
  }

  const changed = checkIn !== booking.check_in || checkOut !== booking.check_out;

  return (
    <section className="card mt-8 grid gap-4 p-6">
      <div>
        <h2 className="text-xl font-semibold">{t.changeDates.title}</h2>
        <p className="mt-1 text-sm text-muted">{t.changeDates.intro}</p>
        <p className="mt-1 text-sm text-muted">{t.changeDates.current(fmtDate(booking.check_in, lang), fmtDate(booking.check_out, lang))}</p>
      </div>
      <div className="max-w-md">
        <DateRangePicker checkIn={checkIn} checkOut={checkOut} adults={booking.adults} kids={booking.children}
          onChange={(ci, co) => { setCheckIn(ci); setCheckOut(co); setQuote(null); }} />
      </div>
      {quote && (
        <div className="rounded-xl bg-sea-tint p-4">
          <p className="text-sm text-muted">{t.changeDates.newTotal}</p>
          <p className="font-display text-2xl font-semibold">
            {money(quote.total)} <span className="text-base font-normal text-muted">{t.changeDates.was(money(quote.old_total))}</span>
          </p>
          <p className="mt-1 text-[15px]">
            {quote.balance_due > 0 ? t.changeDates.balance(money(quote.balance_due))
              : quote.refund_due > 0 ? t.changeDates.refund(money(quote.refund_due)) : t.changeDates.same}
          </p>
        </div>
      )}
      {error && <Notice tone="error">{error}</Notice>}
      <div className="flex flex-wrap gap-3">
        {!quote ? (
          <button className="btn-sea" disabled={busy || !changed} onClick={() => run(true)}>{busy ? t.changeDates.checking : t.changeDates.check}</button>
        ) : (
          <button className="btn-primary" disabled={busy} onClick={() => run(false)}>{busy ? t.changeDates.saving : t.changeDates.confirm}</button>
        )}
        <button className="btn-quiet" onClick={() => { setOpen(false); setQuote(null); setError(""); }}>{t.changeDates.close}</button>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
const ID_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "application/pdf"];

function IdUpload({ booking, onChanged }: { booking: Booking; onChanged: () => void }) {
  const { t } = useT();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function upload(file: File) {
    setError("");
    if (file.size > 5 * 1024 * 1024) return setError(t.idUpload.tooBig);
    if (!ID_TYPES.includes(file.type)) return setError(t.idUpload.wrongType);
    setBusy(true);
    const ext = (file.name.split(".").pop() ?? "jpg").toLowerCase().replace(/[^a-z0-9]/g, "");
    const path = `${booking.id}/id-${Date.now()}.${ext}`;
    const sb = supabase();
    const { error: upErr } = await sb.storage.from("guest-ids").upload(path, file, { contentType: file.type });
    if (upErr) {
      setBusy(false);
      return setError(upErr.message);
    }
    const { error: recErr } = await sb.rpc("record_id_upload", { p_booking_id: booking.id, p_path: path });
    if (!recErr && booking.id_document_path) {
      await sb.storage.from("guest-ids").remove([booking.id_document_path]); // replace the earlier photo
    }
    setBusy(false);
    if (recErr) return setError(recErr.message);
    onChanged();
  }

  const uploadedAt = booking.id_uploaded_at
    ? new Date(booking.id_uploaded_at).toLocaleString(t.locale, { timeZone: "Asia/Manila", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })
    : "";

  return (
    <section className="card mt-8 p-6">
      <h2 className="text-xl font-semibold">{t.idUpload.title}</h2>
      {booking.id_verified_at ? (
        <p className="mt-2 text-good">{t.idUpload.verified}</p>
      ) : (
        <>
          <p className="mt-2 max-w-2xl text-muted">{booking.id_uploaded_at ? t.idUpload.received(uploadedAt) : t.idUpload.body}</p>
          <label className={`btn-quiet mt-4 cursor-pointer ${busy ? "pointer-events-none opacity-60" : ""}`}>
            {busy ? t.idUpload.uploading : booking.id_uploaded_at ? t.idUpload.replace : t.idUpload.choose}
            <input type="file" accept={ID_TYPES.join(",")} capture="environment" className="sr-only" disabled={busy}
              onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ""; if (f) upload(f); }} />
          </label>
          <p className="mt-2 text-xs text-muted">{t.idUpload.privacy}</p>
          {error && <div className="mt-3"><Notice tone="error">{error}</Notice></div>}
        </>
      )}
    </section>
  );
}

// ---------------------------------------------------------------------------
function ReviewForm({ booking }: { booking: Booking }) {
  const { t } = useT();
  const [mine, setMine] = useState<Review | null | undefined>(undefined);
  const [rating, setRating] = useState(0);
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [version, setVersion] = useState(0);
  const [posted, setPosted] = useState(false);

  useEffect(() => {
    supabase().from("reviews").select("*").eq("booking_id", booking.id).maybeSingle()
      .then(({ data }) => setMine((data as Review) ?? null));
  }, [booking.id, version]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!rating) return;
    setBusy(true);
    setError("");
    const { error } = await supabase().rpc("submit_review", { p_booking_id: booking.id, p_rating: rating, p_body: body });
    setBusy(false);
    if (error) return setError(error.message);
    setPosted(true);
    setVersion((v) => v + 1);
  }

  if (mine === undefined) return null;

  if (mine) {
    return (
      <section className="card mt-8 p-6">
        {posted && <div className="mb-4"><Notice tone="good">{t.review.thanks}</Notice></div>}
        <h2 className="text-xl font-semibold">{t.review.yours}</h2>
        <div className="mt-3"><Stars rating={mine.rating} /></div>
        {mine.body && <p className="mt-2 max-w-2xl">{mine.body}</p>}
        <p className="mt-2 text-sm text-muted">{mine.display_name}</p>
      </section>
    );
  }

  return (
    <form onSubmit={submit} className="card mt-8 grid gap-4 p-6">
      <div>
        <h2 className="text-xl font-semibold">{t.review.title}</h2>
        <p className="mt-1 text-sm text-muted">{t.review.intro}</p>
      </div>
      <fieldset>
        <legend className="label">{t.review.rating}</legend>
        <div className="flex gap-1">
          {[1, 2, 3, 4, 5].map((n) => (
            <label key={n} className="cursor-pointer rounded-lg p-1 text-mango hover:bg-sun-tint has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-sea">
              <input type="radio" name="rating" value={n} className="sr-only" checked={rating === n} onChange={() => setRating(n)} required />
              <span className="sr-only">{t.review.star(n)}</span>
              <svg viewBox="0 0 20 20" className="h-8 w-8 transition-transform active:scale-90" fill={n <= rating ? "currentColor" : "none"} stroke="currentColor" strokeWidth="1.3" aria-hidden>
                <path d="M10 2.5l2.3 4.9 5.2.6-3.9 3.6 1.1 5.2L10 14.2l-4.7 2.6 1.1-5.2L2.5 8l5.2-.6z" />
              </svg>
            </label>
          ))}
        </div>
      </fieldset>
      <div>
        <label htmlFor="review-body" className="label">{t.review.comment}</label>
        <textarea id="review-body" className="field min-h-28" maxLength={1500} value={body} onChange={(e) => setBody(e.target.value)} />
      </div>
      {error && <Notice tone="error">{error}</Notice>}
      <button className="btn-primary justify-self-start" disabled={busy || !rating}>{busy ? t.review.posting : t.review.submit}</button>
    </form>
  );
}
