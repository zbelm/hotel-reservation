"use client";

import { arrivalLabel } from "@/lib/hotel";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { BookingBadge, Notice, Spinner } from "@/components/ui";
import { supabase } from "@/lib/supabase";
import { guests, money, niceDate, todayManila } from "@/lib/format";
import { BOOKING_SELECT, type Booking } from "@/lib/types";
import { StaffGate } from "../StaffGate";

export function StaffBooking() {
  return (
    <StaffGate>
      <Detail />
    </StaffGate>
  );
}

type Payment = { id: string; amount: number; method: string | null; provider: string; status: string; paid_at: string | null; created_at: string };

async function fetchDetail(id: string) {
  const sb = supabase();
  const [bk, pay] = await Promise.all([
    sb.from("bookings").select(BOOKING_SELECT).eq("id", id).maybeSingle(),
    sb.from("payments").select("id, amount, method, provider, status, paid_at, created_at").eq("booking_id", id).order("created_at"),
  ]);
  const booking = (bk.data as Booking | null) ?? null;
  let rooms: { id: string; number: string }[] = [];
  const typeId = booking?.booking_rooms?.[0]?.room_type_id;
  if (typeId) {
    const { data } = await sb.from("rooms").select("id, number").eq("room_type_id", typeId).eq("status", "vacant_clean").order("number");
    rooms = data ?? [];
  }
  return {
    error: bk.error?.message ?? (booking ? null : "Booking not found."),
    booking,
    payments: (pay.data as Payment[]) ?? [],
    rooms,
  };
}

function Detail() {
  const id = useSearchParams().get("id") ?? "";
  const [b, setB] = useState<Booking | null>(null);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [rooms, setRooms] = useState<{ id: string; number: string }[]>([]);
  const [roomId, setRoomId] = useState("");
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("cash");
  const [msg, setMsg] = useState<{ tone: "good" | "error"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [ask, setAsk] = useState<"checkout" | "cancel" | null>(null);

  const [version, setVersion] = useState(0); // bump to reload
  const load = () => setVersion((v) => v + 1);

  useEffect(() => {
    let active = true;
    fetchDetail(id).then((d) => {
      if (!active) return;
      if (d.error) return setMsg({ tone: "error", text: d.error });
      setB(d.booking);
      setPayments(d.payments);
      setRooms(d.rooms);
      setRoomId(d.rooms[0]?.id ?? "");
      if (d.booking) setAmount(String(Math.max(Number(d.booking.total) - Number(d.booking.amount_paid), 0)));
    });
    return () => { active = false; };
  }, [id, version]);

  async function run(fn: string, args: Record<string, unknown>, done: (d: Record<string, unknown>) => string) {
    setBusy(true);
    setMsg(null);
    const { data, error } = await supabase().rpc(fn, args);
    setBusy(false);
    setMsg(error ? { tone: "error", text: error.message } : { tone: "good", text: done(data ?? {}) });
    load();
  }

  if (!b) return msg ? <Notice tone={msg.tone}>{msg.text}</Notice> : <Spinner />;

  const br = b.booking_rooms?.[0];
  const balance = Number(b.total) - Number(b.amount_paid);
  const canCheckIn = b.status === "confirmed" && b.check_in <= todayManila();

  return (
    <>
      <Link href="/staff" className="text-sm font-medium text-sea hover:underline">&larr; Front office</Link>
      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-4xl font-semibold">{b.guest_name}</h1>
        <BookingBadge status={b.status} />
      </div>
      <p className="mt-1 font-mono text-muted">{b.code} · booked via {b.source.replace("_", " ")}</p>

      {msg && <div className="mt-5"><Notice tone={msg.tone}>{msg.text}</Notice></div>}

      <div className="mt-6 grid gap-6 md:grid-cols-2">
        <div className="card p-5">
          <dl className="grid grid-cols-2 gap-y-2 text-[15px]">
            <dt className="text-muted">Room type</dt><dd className="text-right">{br?.room_types?.name}</dd>
            <dt className="text-muted">Rate</dt><dd className="text-right">{br?.rate_plans?.name}</dd>
            <dt className="text-muted">Room</dt><dd className="text-right">{br?.rooms?.number ?? "Not assigned"}</dd>
            <dt className="text-muted">Dates</dt><dd className="text-right">{niceDate(b.check_in)} – {niceDate(b.check_out, true)}</dd>
            <dt className="text-muted">Guests</dt><dd className="text-right">{guests(b.adults, b.children)}</dd>
            <dt className="text-muted">Email</dt><dd className="truncate text-right">{b.guest_email}</dd>
            <dt className="text-muted">Mobile</dt><dd className="text-right">{b.guest_phone ?? "—"}</dd>
            <dt className="text-muted">Arriving</dt><dd className="text-right">{arrivalLabel(b.arrival_time) ?? "Not given"}</dd>
            <dt className="text-muted">House rules</dt><dd className="text-right">{b.policies_accepted_at ? "Agreed online" : "Not recorded"}</dd>
            <dt className="text-muted">ID</dt>
            <dd className="text-right">{b.id_verified_at ? "Checked" : b.id_document_path ? "Uploaded, not checked" : "Not uploaded"}</dd>
          </dl>
          {b.special_requests && <p className="mt-4 rounded-xl bg-sun-tint p-3 text-sm"><strong>Request:</strong> {b.special_requests}</p>}
        </div>

        <div className="card p-5">
          <dl className="grid grid-cols-2 gap-y-2 text-[15px]">
            <dt className="text-muted">Total</dt><dd className="text-right font-semibold">{money(b.total)}</dd>
            <dt className="text-muted">Paid</dt><dd className="text-right">{money(b.amount_paid)}</dd>
            <dt className="text-muted">Balance</dt><dd className={`text-right font-semibold ${balance > 0 ? "text-sun" : "text-good"}`}>{money(Math.max(balance, 0))}</dd>
            {Number(b.refund_due) > 0 && (<><dt className="text-muted">Refund due</dt><dd className="text-right font-semibold text-bad">{money(b.refund_due)}</dd></>)}
          </dl>
          <ul className="mt-4 divide-y divide-line border-t border-line text-sm">
            {payments.length === 0 && <li className="py-2 text-muted">No payments yet.</li>}
            {payments.map((p) => (
              <li key={p.id} className="flex justify-between py-2">
                <span>{p.method ?? p.provider} · <span className="text-muted">{p.status.replace("_", " ")}</span></span>
                <span>{money(p.amount)}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div className="mt-6 grid gap-4">
        {b.id_document_path && !b.id_verified_at && (
          <div className="card flex flex-wrap items-center justify-between gap-3 p-5">
            <div>
              <p className="font-semibold">Guest uploaded an ID</p>
              <p className="text-sm text-muted">Compare it with the guest at the desk. Confirming deletes the photo so we don&rsquo;t keep it.</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <button className="btn-quiet" disabled={busy} onClick={async () => {
                const { data, error } = await supabase().storage.from("guest-ids").createSignedUrl(b.id_document_path!, 60);
                if (error || !data) return setMsg({ tone: "error", text: error?.message ?? "Could not open the ID." });
                window.open(data.signedUrl, "_blank", "noopener");
              }}>
                View ID
              </button>
              <button className="btn-primary" disabled={busy} onClick={async () => {
                setBusy(true);
                await supabase().storage.from("guest-ids").remove([b.id_document_path!]);
                setBusy(false);
                run("verify_guest_id", { p_booking_id: b.id }, () => "ID checked. The photo has been deleted.");
              }}>
                ID matches, delete photo
              </button>
            </div>
          </div>
        )}

        {b.status === "confirmed" && <ChangeDates booking={b} onDone={(text) => { setMsg({ tone: "good", text }); load(); }} />}

        {canCheckIn && (
          <div className="card flex flex-wrap items-end gap-3 p-5">
            <div className="min-w-40 flex-1">
              <label className="label" htmlFor="room">Assign room</label>
              {rooms.length ? (
                <select id="room" className="field" value={roomId} onChange={(e) => setRoomId(e.target.value)}>
                  {rooms.map((r) => <option key={r.id} value={r.id}>Room {r.number}</option>)}
                </select>
              ) : <p className="text-sm text-bad">No clean room of this type is free. Check the room board.</p>}
            </div>
            <button className="btn-primary" disabled={busy || !roomId}
              onClick={() => run("check_in_booking", { p_booking_id: b.id, p_room_id: roomId }, (d) => `Checked in to room ${d.room_number}.`)}>
              Check in
            </button>
          </div>
        )}

        {["confirmed", "checked_in", "checked_out"].includes(b.status) && balance > 0 && (
          <div className="card flex flex-wrap items-end gap-3 p-5">
            <div className="w-36">
              <label className="label" htmlFor="amt">Amount</label>
              <input id="amt" type="number" min={1} step="0.01" className="field" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </div>
            <div className="w-36">
              <label className="label" htmlFor="method">Method</label>
              <select id="method" className="field" value={method} onChange={(e) => setMethod(e.target.value)}>
                <option value="cash">Cash</option><option value="card">Card terminal</option><option value="gcash">GCash QR</option><option value="maya">Maya QR</option>
              </select>
            </div>
            <button className="btn-quiet" disabled={busy || Number(amount) <= 0}
              onClick={() => run("record_desk_payment", { p_booking_id: b.id, p_amount: Number(amount), p_method: method }, (d) => `Payment recorded. Balance: ${money(Number(d.balance))}.`)}>
              Record payment
            </button>
          </div>
        )}

        <div className="flex flex-wrap gap-3">
          {b.status === "checked_in" && (
            ask === "checkout" ? (
              <ConfirmBar
                text={`This guest still owes ${money(balance)}. Check out anyway?`}
                yes="Check out anyway" busy={busy} onNo={() => setAsk(null)}
                onYes={() => { setAsk(null); run("check_out_booking", { p_booking_id: b.id }, () => "Checked out. The room is marked dirty for housekeeping."); }} />
            ) : (
              <button className="btn-primary" disabled={busy}
                onClick={() => balance > 0
                  ? setAsk("checkout")
                  : run("check_out_booking", { p_booking_id: b.id }, () => "Checked out. The room is marked dirty for housekeeping.")}>
                Check out
              </button>
            )
          )}
          {["held", "confirmed"].includes(b.status) && (
            ask === "cancel" ? (
              <ConfirmBar
                text={br?.rate_plans?.refundable
                  ? `Cancel this booking? Free until ${br.rate_plans.free_cancel_hours}h before check-in; after that the first night is kept.`
                  : "Cancel this booking? This rate is non-refundable, so nothing is refunded."}
                yes="Yes, cancel booking" danger busy={busy} onNo={() => setAsk(null)}
                onYes={() => { setAsk(null); run("cancel_booking", { p_booking_id: b.id }, (d) => `Cancelled. Refund due: ${money(Number(d.refund_due))}.`); }} />
            ) : (
              <button className="btn-danger" disabled={busy} onClick={() => setAsk("cancel")}>
                Cancel booking
              </button>
            )
          )}
        </div>
      </div>
    </>
  );
}

function ChangeDates({ booking, onDone }: { booking: Booking; onDone: (text: string) => void }) {
  const [open, setOpen] = useState(false);
  const [checkIn, setCheckIn] = useState(booking.check_in);
  const [checkOut, setCheckOut] = useState(booking.check_out);
  const [quote, setQuote] = useState<ChangeQuote | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function call(preview: boolean) {
    setBusy(true);
    setError("");
    const { data, error } = await supabase().rpc("change_booking_dates", {
      p_booking_id: booking.id, p_check_in: checkIn, p_check_out: checkOut, p_preview: preview,
    });
    setBusy(false);
    if (error) return setError(error.message);
    const q = data as ChangeQuote;
    if (preview) return setQuote(q);
    setOpen(false);
    setQuote(null);
    onDone(`Dates changed to ${niceDate(q.check_in)} – ${niceDate(q.check_out, true)}. New total ${money(q.total)}.`);
  }

  if (!open) {
    return <div><button className="btn-quiet" onClick={() => setOpen(true)}>Change dates</button></div>;
  }

  return (
    <div className="card p-5">
      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <label className="label" htmlFor="cd-in">Check-in</label>
          <input id="cd-in" type="date" className="field" value={checkIn} onChange={(e) => { setCheckIn(e.target.value); setQuote(null); }} />
        </div>
        <div className="w-44">
          <label className="label" htmlFor="cd-out">Check-out</label>
          <input id="cd-out" type="date" className="field" min={checkIn} value={checkOut} onChange={(e) => { setCheckOut(e.target.value); setQuote(null); }} />
        </div>
        <button className="btn-quiet" disabled={busy || !checkIn || checkOut <= checkIn} onClick={() => call(true)}>Check price</button>
        <button className="btn-quiet" onClick={() => { setOpen(false); setQuote(null); setError(""); }}>Close</button>
      </div>
      {error && <div className="mt-4"><Notice tone="error">{error}</Notice></div>}
      {quote && (
        <div className="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-xl bg-sand p-4 text-[15px]">
          <p>
            {niceDate(quote.check_in)} – {niceDate(quote.check_out, true)}: <strong>{money(quote.total)}</strong>
            <span className="text-muted"> (was {money(quote.old_total)})</span>
            {Number(quote.balance_due) > 0 && <> · guest owes {money(quote.balance_due)}</>}
            {Number(quote.refund_due) > 0 && <> · refund due {money(quote.refund_due)}</>}
          </p>
          <button className="btn-primary" disabled={busy} onClick={() => call(false)}>Confirm change</button>
        </div>
      )}
    </div>
  );
}

type ChangeQuote = {
  check_in: string; check_out: string; nights: number; total: number; old_total: number;
  balance_due: number; refund_due: number;
};

// Asks before an action that can't be undone, inside the page
function ConfirmBar({ text, yes, onYes, onNo, busy, danger }: {
  text: string; yes: string; onYes: () => void; onNo: () => void; busy: boolean; danger?: boolean;
}) {
  return (
    <div role="alertdialog" aria-label={text} className="flex w-full flex-wrap items-center gap-3 rounded-xl border border-line bg-paper p-4">
      <p className="min-w-0 flex-1 text-sm font-medium">{text}</p>
      <button className={danger ? "btn-danger" : "btn-primary"} disabled={busy} onClick={onYes}>{yes}</button>
      <button className="btn-quiet" disabled={busy} onClick={onNo}>Keep it</button>
    </div>
  );
}
