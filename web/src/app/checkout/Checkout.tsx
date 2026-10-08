"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Chevron } from "@/components/Icons";
import { BACK } from "@/components/Page";
import { Steps } from "@/components/Steps";
import { Notice, RoomArt, Spinner } from "@/components/ui";
import { functionError, supabase } from "@/lib/supabase";
import { money, nightsBetween } from "@/lib/format";
import { HOTEL } from "@/lib/hotel";
import { useT } from "@/lib/i18n";
import { fmtDate } from "@/lib/messages";
import { useRequireAuth } from "@/lib/useRequireAuth";
import type { Offer } from "@/lib/types";

export function Checkout() {
  const { t, lang, hotel } = useT();
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
  const [arrival, setArrival] = useState("not_sure");
  const [requests, setRequests] = useState("");
  const [agreed, setAgreed] = useState(false);
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
      if (!match) setError("RATE_GONE");
      setOffer(match);
    });
  }, [roomTypeId, planId, checkIn, checkOut]);

  function addIdea(idea: string) {
    setRequests((r) => (r.includes(idea) ? r : r.trim() ? `${r.trim()}. ${idea}` : idea));
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!agreed) {
      setError("MUST_AGREE");
      return;
    }
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

    // Arrival time and the agreement are extras: a failure here shouldn't stop the booking
    await sb.rpc("save_booking_details", { p_booking_id: booking.id, p_arrival_time: arrival, p_accept_policies: true });

    // Save name and phone for next time
    if (session && (name !== profile?.full_name || phone !== (profile?.phone ?? ""))) {
      await sb.from("profiles").update({ full_name: name, phone }).eq("id", session.user.id);
    }

    const { data: pay, error: payErr } = await sb.functions.invoke("create-checkout", { body: { booking_id: booking.id } });
    if (payErr || !pay?.checkout_url) {
      // The room is still held; the booking page lets them try paying again
      const msg = payErr ? await functionError(payErr) : t.payment.couldNotStart;
      router.push(`/booking?id=${booking.id}&payment_error=${encodeURIComponent(msg)}`);
      return;
    }
    window.location.href = pay.checkout_url;
  }

  if (loading || !session) return <Spinner />;

  const back = new URLSearchParams({ id: roomTypeId, check_in: checkIn, check_out: checkOut, adults: String(adults), children: String(children) });
  const nights = checkIn && checkOut ? nightsBetween(checkIn, checkOut) : 0;

  return (
    <>
      <Steps current={3} />
      <Link href={`/room?${back}`} transitionTypes={BACK} className="text-sm font-medium text-sea underline-offset-4 hover:underline">{t.checkout.back}</Link>
      <h1 className="mt-3 text-4xl font-semibold sm:text-5xl">{t.checkout.title}</h1>
      <p className="mt-3 max-w-2xl text-muted">{t.checkout.intro}</p>

      <div className="mt-10 grid gap-8 lg:grid-cols-[1.35fr_1fr]">
        <form onSubmit={submit} className="grid gap-8">
          <fieldset className="card grid gap-4 p-6">
            <legend className="float-left mb-1 font-display text-xl font-semibold">{t.checkout.guestDetails}</legend>
            <div className="clear-both">
              <label htmlFor="name" className="label">{t.checkout.name}</label>
              <input id="name" className="field" value={name} onChange={(e) => setName(e.target.value)} required autoComplete="name" />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label htmlFor="email" className="label">{t.checkout.email}</label>
                <input id="email" type="email" className="field" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
              </div>
              <div>
                <label htmlFor="phone" className="label">{t.checkout.phone}</label>
                <input id="phone" type="tel" className="field" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+63 917 123 4567" autoComplete="tel" />
              </div>
            </div>
          </fieldset>

          <fieldset className="card grid gap-4 p-6">
            <legend className="float-left mb-1 font-display text-xl font-semibold">{t.checkout.arrival}</legend>
            <div className="clear-both">
              <label htmlFor="arrival" className="label">{t.checkout.arrivalQ(checkIn ? fmtDate(checkIn, lang) : "")}</label>
              <select id="arrival" className="field" value={arrival} onChange={(e) => setArrival(e.target.value)}>
                {hotel.arrivalTimes.map((a) => <option key={a.value} value={a.value}>{a.label}</option>)}
              </select>
              <p className="mt-1.5 text-sm text-muted">{t.checkout.arrivalHelp(HOTEL.checkIn)}</p>
            </div>
            <div>
              <label htmlFor="requests" className="label">{t.checkout.requests}</label>
              <div className="mb-2 flex flex-wrap gap-1.5">
                {hotel.requestIdeas.map((idea) => {
                  const added = requests.includes(idea);
                  return (
                    <button key={idea} type="button" onClick={() => addIdea(idea)} disabled={added}
                      className="rounded-full border border-line px-3 py-1 text-sm text-muted transition-colors hover:border-sea hover:text-sea disabled:border-sea disabled:bg-sea-tint disabled:text-sea">
                      {added ? t.checkout.added(idea) : `+ ${idea}`}
                    </button>
                  );
                })}
              </div>
              <textarea id="requests" className="field min-h-24" value={requests} onChange={(e) => setRequests(e.target.value)} placeholder={t.checkout.requestsPlaceholder} />
            </div>
          </fieldset>

          <fieldset className="card grid gap-4 p-6">
            <legend className="float-left mb-1 font-display text-xl font-semibold">{t.checkout.beforePay}</legend>
            <ul className="clear-both space-y-2 text-[15px]">
              {offer && (
                <li className={offer.refundable ? "text-good" : "text-sun"}>
                  {offer.refundable ? t.checkout.flexLine(offer.name, offer.free_cancel_hours) : t.checkout.nonRefLine(offer.name)}
                </li>
              )}
              <li className="text-muted">{t.checkout.bringId(name || t.checkout.theGuest, HOTEL.checkIn, HOTEL.checkOut)}</li>
              <li className="text-muted">{t.checkout.rulesShort}</li>
            </ul>
            <details className="disclose rounded-xl border border-line px-4">
              <summary className="flex items-center justify-between py-3 text-sm font-medium">
                {t.checkout.readAll}
                <Chevron className="chev h-4 w-4 text-muted" />
              </summary>
              <dl className="space-y-3 pb-4 text-sm">
                {hotel.policies.map((p) => (
                  <div key={p.title}><dt className="font-semibold">{p.title}</dt><dd className="text-muted">{p.body}</dd></div>
                ))}
              </dl>
            </details>
            <label className="flex cursor-pointer items-start gap-3 rounded-xl bg-sea-tint px-4 py-3.5">
              <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} className="mt-1 h-4 w-4 accent-[var(--sea)]" required />
              <span className="text-[15px]">{t.checkout.agree}</span>
            </label>
          </fieldset>

          {error && <Notice tone="error">{error === "MUST_AGREE" ? t.checkout.mustAgree : error === "RATE_GONE" ? t.checkout.rateGone : error}</Notice>}
          <button className="btn-primary py-3.5! text-base" disabled={busy || !offer}>
            {busy ? t.checkout.holding : offer ? t.checkout.pay(money(offer.total)) : t.checkout.payPlain}
          </button>
        </form>

        <aside className="lg:sticky lg:top-20 lg:self-start">
          <div className="card overflow-hidden">
            <div className="aspect-[16/9]"><RoomArt name={roomName || "Room"} /></div>
            <div className="p-6">
              <h2 className="text-2xl font-semibold">{roomName || "…"}</h2>
              <p className="text-muted">{offer?.name}</p>
              <dl className="mt-5 grid grid-cols-2 gap-y-2 text-[15px]">
                <dt className="text-muted">{t.booking.checkIn}</dt><dd className="text-right">{checkIn && fmtDate(checkIn, lang, true)}</dd>
                <dt className="text-muted">{t.booking.checkOut}</dt><dd className="text-right">{checkOut && fmtDate(checkOut, lang, true)}</dd>
                <dt className="text-muted">{t.booking.guests}</dt><dd className="text-right">{t.guests(adults, children)}</dd>
              </dl>
              {offer && (
                <ul className="mt-5 divide-y divide-line border-y border-line text-[15px]">
                  {offer.nightly.map((n) => (
                    <li key={n.date} className="flex justify-between py-2"><span className="text-muted">{fmtDate(n.date, lang)}</span><span>{money(n.price)}</span></li>
                  ))}
                </ul>
              )}
              <div className="mt-4 flex items-baseline justify-between">
                <span className="font-semibold">{t.checkout.totalFor(t.nights(nights))}</span>
                <span className="font-display text-3xl font-semibold">{offer ? money(offer.total) : "…"}</span>
              </div>
              <p className="mt-1 text-sm text-muted">{t.checkout.pesos}</p>
            </div>
          </div>
        </aside>
      </div>
    </>
  );
}
