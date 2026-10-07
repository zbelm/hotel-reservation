import Link from "next/link";
import { HOTEL, mapsUrl } from "@/lib/hotel";

export function Footer() {
  return (
    <footer className="bg-bay text-on-bay">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr]">
        <div>
          <p className="font-display text-2xl font-semibold">{HOTEL.name}</p>
          <p className="mt-3 max-w-xs text-on-bay-muted">{HOTEL.address}</p>
          <a href={mapsUrl} target="_blank" rel="noreferrer" className="mt-2 inline-block text-mango underline-offset-4 hover:underline">
            Get directions
          </a>
        </div>
        <div>
          <h2 className="text-base font-semibold">Talk to the front desk</h2>
          <ul className="mt-3 space-y-1.5 text-on-bay-muted">
            <li><a href={`tel:${HOTEL.phone.replace(/\s/g, "")}`} className="hover:text-on-bay">{HOTEL.phone}</a></li>
            <li><a href={`mailto:${HOTEL.email}`} className="hover:text-on-bay">{HOTEL.email}</a></li>
            <li>Open 24 hours, every day</li>
          </ul>
        </div>
        <div>
          <h2 className="text-base font-semibold">Your stay</h2>
          <ul className="mt-3 space-y-1.5 text-on-bay-muted">
            <li><Link href="/#rooms" className="hover:text-on-bay">Rooms and rates</Link></li>
            <li><Link href="/#policies" className="hover:text-on-bay">House rules and cancellation</Link></li>
            <li><Link href="/#faq" className="hover:text-on-bay">Questions guests ask</Link></li>
            <li><Link href="/bookings" className="hover:text-on-bay">Find my booking</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/10">
        <p className="mx-auto max-w-6xl px-4 py-5 text-sm text-on-bay-muted sm:px-6">
          Check-in from {HOTEL.checkIn}. Check-out by {HOTEL.checkOut}. Prices in Philippine pesos, taxes included.
        </p>
      </div>
    </footer>
  );
}
