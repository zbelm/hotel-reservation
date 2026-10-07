"use client";

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
            <button className="btn-primary" disabled={busy}
              onClick={() => {
                if (balance > 0 && !confirm(`This guest still owes ${money(balance)}. Check out anyway?`)) return;
                run("check_out_booking", { p_booking_id: b.id }, () => "Checked out. The room is marked dirty for housekeeping.");
              }}>
              Check out
            </button>
          )}
          {["held", "confirmed"].includes(b.status) && (
            <button className="btn-danger" disabled={busy}
              onClick={() => {
                if (!confirm("Cancel this booking? The cancellation policy of the rate applies.")) return;
                run("cancel_booking", { p_booking_id: b.id }, (d) => `Cancelled. Refund due: ${money(Number(d.refund_due))}.`);
              }}>
              Cancel booking
            </button>
          )}
        </div>
      </div>
    </>
  );
}
