"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Notice, PageTitle, Spinner } from "@/components/ui";
import { functionError, supabase } from "@/lib/supabase";
import { guests, money, niceDate, plural, nightsBetween } from "@/lib/format";
import { useRequireAuth } from "@/lib/useRequireAuth";
import type { Offer } from "@/lib/types";

export function Checkout() {
  const { session, profile, loading } = useRequireAuth();
  const router = useRouter();
  const params = useSearchParams();
  const roomTypeId = params.get("id") ?? "";
  const planId = params.get("plan") ?? "";
  const checkIn = params.get("check_in") ?? "";
  const checkOut = params.get("check_out") ?? "";
  const adults = Number(params.get("adults") ?? 2);
  const children = Number(params.get("children") ?? 0);

  const [roomName, setRoomName] = useState("");
  const [offer, setOffer] = useState<Offer | null>(null);
  // null = not typed yet, so show what we know from the account
  const [typedName, setName] = useState<string | null>(null);
  const [typedEmail, setEmail] = useState<string | null>(null);
  const [typedPhone, setPhone] = useState<string | null>(null);
  const name = typedName ?? profile?.full_name ?? "";
  const email = typedEmail ?? session?.user.email ?? "";
  const phone = typedPhone ?? profile?.phone ?? "";
  const [requests, setRequests] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const sb = supabase();
    Promise.all([
      sb.from("room_types").select("name").eq("id", roomTypeId).maybeSingle(),
      sb.rpc("room_type_offers", { p_room_type_id: roomTypeId, p_check_in: checkIn, p_check_out: checkOut }),
    ]).then(([r, o]) => {
      if (r.error || o.error) return setError((r.error ?? o.error)!.message);
      setRoomName(r.data?.name ?? "");
      const match = (o.data as Offer[] | null)?.find((x) => x.rate_plan_id === planId) ?? null;
      if (!match) setError("That rate is no longer available. Please choose another.");
      setOffer(match);
    });
  }, [roomTypeId, planId, checkIn, checkOut]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");

    const sb = supabase();
    const { data: booking, error: bookErr } = await sb.rpc("create_booking", {
      p_room_type_id: roomTypeId,
      p_rate_plan_id: planId,
      p_check_in: checkIn,
      p_check_out: checkOut,
      p_adults: adults,
      p_children: children,
      p_guest_name: name,
      p_guest_email: email,
      p_guest_phone: phone,
      p_special_requests: requests,
      p_source: "web",
    });
    if (bookErr) {
      setError(bookErr.message);
      setBusy(false);
      return;
    }

    // Save name and phone for next time
    if (session && (name !== profile?.full_name || phone !== (profile?.phone ?? ""))) {
      await sb.from("profiles").update({ full_name: name, phone }).eq("id", session.user.id);
    }

    const { data: pay, error: payErr } = await sb.functions.invoke("create-checkout", { body: { booking_id: booking.id } });
    if (payErr || !pay?.checkout_url) {
      // The room is still held; the booking page lets them try paying again
      const msg = payErr ? await functionError(payErr) : "Could not start payment";
      router.push(`/booking?id=${booking.id}&payment_error=${encodeURIComponent(msg)}`);
      return;
    }
    window.location.href = pay.checkout_url;
  }

  if (loading || !session) return <Spinner />;

  return (
    <>
      <PageTitle eyebrow="Almost there" title="Who's staying?">
        We&rsquo;ll hold your room for 15 minutes while you pay with GCash, Maya, GrabPay, QR Ph or card.
      </PageTitle>

      <div className="grid gap-8 lg:grid-cols-[1.3fr_1fr]">
        <form onSubmit={submit} className="card grid gap-4 p-6">
          <div>
            <label htmlFor="name" className="label">Full name</label>
            <input id="name" className="field" value={name} onChange={(e) => setName(e.target.value)} required autoComplete="name" />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label htmlFor="email" className="label">Email</label>
              <input id="email" type="email" className="field" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
            </div>
            <div>
              <label htmlFor="phone" className="label">Mobile number</label>
              <input id="phone" type="tel" className="field" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+63 917 123 4567" autoComplete="tel" />
            </div>
          </div>
          <div>
            <label htmlFor="requests" className="label">Special requests (optional)</label>
            <textarea id="requests" className="field min-h-24" value={requests} onChange={(e) => setRequests(e.target.value)} placeholder="Late arrival, high floor, extra pillows…" />
          </div>
          {error && <Notice tone="error">{error}</Notice>}
          <button className="btn-primary mt-2" disabled={busy || !offer}>
            {busy ? "Holding your room…" : offer ? `Continue to payment · ${money(offer.total)}` : "Continue to payment"}
          </button>
        </form>

        <aside className="card h-fit p-6">
          <p className="label">Summary</p>
          <h2 className="text-2xl font-semibold">{roomName || "…"}</h2>
          <p className="text-muted">{offer?.name}</p>
          <dl className="mt-5 grid grid-cols-2 gap-y-2 text-[15px]">
            <dt className="text-muted">Check-in</dt><dd className="text-right">{checkIn && niceDate(checkIn, true)}</dd>
            <dt className="text-muted">Check-out</dt><dd className="text-right">{checkOut && niceDate(checkOut, true)}</dd>
            <dt className="text-muted">Guests</dt><dd className="text-right">{guests(adults, children)}</dd>
            <dt className="text-muted">Length</dt><dd className="text-right">{checkIn && checkOut && plural(nightsBetween(checkIn, checkOut), "night")}</dd>
          </dl>
          <div className="mt-5 flex items-baseline justify-between border-t border-line pt-4">
            <span className="font-semibold">Total</span>
            <span className="font-display text-3xl font-semibold">{offer ? money(offer.total) : "…"}</span>
          </div>
          {offer && (
            <p className={`mt-3 text-sm ${offer.refundable ? "text-good" : "text-sun"}`}>
              {offer.refundable ? `Free cancellation until ${offer.free_cancel_hours} hours before check-in.` : "This rate can't be refunded."}
            </p>
          )}
        </aside>
      </div>
    </>
  );
}
