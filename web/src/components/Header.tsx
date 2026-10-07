"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "./AuthProvider";
import { supabase } from "@/lib/supabase";
import { HOTEL } from "@/lib/hotel";

export function Header() {
  const { session, isStaff, loading } = useAuth();
  const router = useRouter();

  async function signOut() {
    await supabase().auth.signOut();
    router.push("/");
  }

  return (
    <header className="sticky top-0 z-20 border-b border-line bg-sand/90 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
        <Link href="/" className="truncate font-display text-lg font-semibold tracking-tight text-ink sm:text-xl">
          {HOTEL.name}
        </Link>
        <nav className="flex shrink-0 items-center gap-0.5 whitespace-nowrap text-sm font-medium sm:gap-2">
          <Link href="/" className="hidden rounded-full px-3 py-2 text-muted hover:text-ink sm:inline-flex">Book</Link>
          {session && (
            <Link href="/bookings" className="rounded-full px-2.5 py-2 text-muted hover:text-ink sm:px-3">My stays</Link>
          )}
          {isStaff && (
            <Link href="/staff" className="rounded-full px-2.5 py-2 text-muted hover:text-ink sm:px-3">Staff</Link>
          )}
          {!loading && (session ? (
            <button onClick={signOut} className="btn-quiet px-3.5! py-2! sm:px-4!">Sign out</button>
          ) : (
            <Link href="/login" className="btn-primary px-3.5! py-2! sm:px-4!">Sign in</Link>
          ))}
        </nav>
      </div>
    </header>
  );
}
