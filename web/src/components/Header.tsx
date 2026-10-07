"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "./AuthProvider";
import { supabase } from "@/lib/supabase";
import { HOTEL } from "@/lib/hotel";

const sections = [
  { href: "/#rooms", label: "Rooms" },
  { href: "/#facilities", label: "Facilities" },
  { href: "/#location", label: "Location" },
  { href: "/#policies", label: "Policies" },
];

export function Header() {
  const { session, isStaff, loading } = useAuth();
  const router = useRouter();

  async function signOut() {
    await supabase().auth.signOut();
    router.push("/");
  }

  return (
    <header style={{ viewTransitionName: "site-header" }} className="sticky top-0 z-20 border-b border-line bg-sand/85 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
        <Link href="/" className="flex min-w-0 items-center gap-2.5 font-display text-[17px] font-semibold tracking-tight text-ink sm:text-xl">
          <CapizMark />
          <span className="truncate">{HOTEL.name}</span>
        </Link>
        <nav className="flex shrink-0 items-center gap-0.5 whitespace-nowrap text-[15px] font-medium sm:gap-1">
          {sections.map((s) => (
            <Link key={s.href} href={s.href} className="hidden rounded-full px-3 py-2 text-muted transition-colors hover:text-ink lg:inline-flex">
              {s.label}
            </Link>
          ))}
          {session && (
            <Link href="/bookings" className="rounded-full px-2.5 py-2 text-muted transition-colors hover:text-ink sm:px-3">My stays</Link>
          )}
          {isStaff && (
            <Link href="/staff" className="rounded-full px-2.5 py-2 text-muted transition-colors hover:text-ink sm:px-3">Staff</Link>
          )}
          {!loading && (session ? (
            <button onClick={signOut} className="btn-quiet ml-1 px-3.5! py-2! sm:px-4!">Sign out</button>
          ) : (
            <Link href="/login" className="btn-quiet ml-1 px-3.5! py-2! sm:px-4!">Sign in</Link>
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
