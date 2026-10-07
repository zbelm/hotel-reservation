import { SearchForm } from "@/components/SearchForm";
import { HOTEL } from "@/lib/hotel";

const perks = [
  { title: "Pay your way", body: "GCash, Maya, GrabPay, QR Ph or card, through PayMongo's secure checkout." },
  { title: "Room held while you pay", body: "Your room is set aside for 15 minutes the moment you reserve it." },
  { title: "Free cancellation", body: "Flexible rates are free to cancel up to 48 hours before check-in." },
];

export default function Home() {
  return (
    <>
      <section className="relative overflow-hidden">
        <div aria-hidden className="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_top_right,var(--sea-tint),transparent_60%)]" />
        <div className="mx-auto max-w-6xl px-4 pb-14 pt-14 sm:px-6 sm:pt-20">
          <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-sea">{HOTEL.address}</p>
          <h1 className="max-w-3xl text-4xl font-semibold leading-[1.05] sm:text-6xl">
            Slow mornings, sea air, and a room that&rsquo;s ready when you are.
          </h1>
          <p className="mt-5 max-w-xl text-lg text-muted">
            Book direct with {HOTEL.name} for the best rate. Check-in from {HOTEL.checkIn}, check-out by {HOTEL.checkOut}.
          </p>
          <div className="mt-10">
            <SearchForm />
          </div>
        </div>
      </section>

      <section className="mx-auto grid max-w-6xl gap-4 px-4 pb-20 sm:grid-cols-3 sm:px-6">
        {perks.map((p) => (
          <div key={p.title} className="border-t border-line pt-5">
            <h2 className="text-lg font-semibold">{p.title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-muted">{p.body}</p>
          </div>
        ))}
      </section>
    </>
  );
}
