"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "./AuthProvider";
import { supabase } from "@/lib/supabase";
import { HOTEL } from "@/lib/hotel";
import { setLang, useT } from "@/lib/i18n";

export function Header() {
  const { session, isStaff, loading } = useAuth();
  const { t, lang } = useT();
  const router = useRouter();

  const sections = [
    { href: "/#rooms", label: t.nav.rooms },
    { href: "/#facilities", label: t.nav.facilities },
    { href: "/#reviews", label: t.nav.reviews },
    { href: "/#location", label: t.nav.location },
    { href: "/#policies", label: t.nav.policies },
  ];

  async function signOut() {
    await supabase().auth.signOut();
    router.push("/");
  }

  return (
    <header style={{ viewTransitionName: "site-header" }} className="sticky top-0 z-30 border-b border-line bg-sand/85 backdrop-blur-md print:hidden">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-6">
        <Link href="/" className="flex min-w-0 items-center gap-2.5 font-display text-[17px] font-semibold tracking-tight text-ink sm:text-xl">
          <CapizMark />
          <span className="truncate">{HOTEL.name}</span>
        </Link>
        <nav className="flex shrink-0 items-center gap-0.5 whitespace-nowrap text-[15px] font-medium sm:gap-1">
          {sections.map((s) => (
            <Link key={s.href} href={s.href} className="hidden rounded-full px-3 py-2 text-muted transition-colors hover:text-ink xl:inline-flex">
              {s.label}
            </Link>
          ))}
          {session && (
            <Link href="/bookings" className="hidden rounded-full px-2.5 py-2 text-muted transition-colors hover:text-ink sm:inline-flex sm:px-3">{t.nav.myStays}</Link>
          )}
          {isStaff && (
            <Link href="/staff" className="rounded-full px-2.5 py-2 text-muted transition-colors hover:text-ink sm:px-3">{t.nav.staff}</Link>
          )}
          <button
            type="button"
            onClick={() => setLang(lang === "en" ? "fil" : "en")}
            className="rounded-full px-2.5 py-2 text-sm font-semibold text-sea transition-colors hover:text-sea-strong"
            aria-label={t.switchTo}
            title={t.switchTo}
            lang={lang === "en" ? "fil" : "en"}
          >
            {lang === "en" ? "FIL" : "EN"}
          </button>
          {!loading && (session ? (
            <>
              <Link href="/bookings" className="btn-quiet ml-1 px-3.5! py-2! sm:hidden">{t.nav.myStays}</Link>
              <button onClick={signOut} className="btn-quiet ml-1 hidden px-3.5! py-2! sm:inline-flex sm:px-4!">{t.nav.signOut}</button>
            </>
          ) : (
            <Link href="/login" className="btn-quiet ml-1 px-3.5! py-2! sm:px-4!">{t.nav.signIn}</Link>
          ))}
        </nav>
      </div>
    </header>
  );
}

// A single capiz pane: the hotel's mark
function CapizMark() {
  return (
    <svg viewBox="0 0 24 24" className="h-6 w-6 shrink-0" aria-hidden>
      <rect x="2" y="2" width="20" height="20" rx="2" fill="var(--narra)" />
      <g fill="#efe9da">
        <rect x="4.5" y="4.5" width="6.5" height="6.5" rx="0.6" />
        <rect x="13" y="4.5" width="6.5" height="6.5" rx="0.6" />
        <rect x="4.5" y="13" width="6.5" height="6.5" rx="0.6" />
        <rect x="13" y="13" width="6.5" height="6.5" rx="0.6" fill="var(--mango)" />
      </g>
    </svg>
  );
}
