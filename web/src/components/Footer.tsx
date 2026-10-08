"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { HOTEL, mapsUrl } from "@/lib/hotel";
import { useT } from "@/lib/i18n";

export function Footer() {
  const { t } = useT();
  const pathname = usePathname();
  if (pathname.startsWith("/staff")) return null; // the staff portal has no guest footer
  return (
    <footer className="bg-bay text-on-bay print:hidden">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr]">
        <div>
          <p className="font-display text-2xl font-semibold">{HOTEL.name}</p>
          <p className="mt-3 max-w-xs text-on-bay-muted">{HOTEL.address}</p>
          <a href={mapsUrl} target="_blank" rel="noreferrer" className="mt-2 inline-block text-mango underline-offset-4 hover:underline">
            {t.footer.directions}
          </a>
        </div>
        <div>
          <h2 className="text-base font-semibold">{t.footer.talk}</h2>
          <ul className="mt-3 space-y-1.5 text-on-bay-muted">
            <li><a href={`tel:${HOTEL.phone.replace(/\s/g, "")}`} className="hover:text-on-bay">{HOTEL.phone}</a></li>
            <li><a href={`mailto:${HOTEL.email}`} className="hover:text-on-bay">{HOTEL.email}</a></li>
            <li>{t.footer.open}</li>
          </ul>
        </div>
        <div>
          <h2 className="text-base font-semibold">{t.footer.yourStay}</h2>
          <ul className="mt-3 space-y-1.5 text-on-bay-muted">
            <li><Link href="/#rooms" className="hover:text-on-bay">{t.footer.roomsAndRates}</Link></li>
            <li><Link href="/#policies" className="hover:text-on-bay">{t.footer.rules}</Link></li>
            <li><Link href="/#faq" className="hover:text-on-bay">{t.footer.questions}</Link></li>
            <li><Link href="/bookings" className="hover:text-on-bay">{t.footer.findBooking}</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/10">
        <p className="mx-auto max-w-6xl px-4 py-5 text-sm text-on-bay-muted sm:px-6">{t.footer.bottom(HOTEL.checkIn, HOTEL.checkOut)}</p>
      </div>
    </footer>
  );
}
