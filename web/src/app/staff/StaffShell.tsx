"use client";

import Link from "next/link";
import { useEffect, useState, type ReactNode } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { CapizMark } from "@/components/Header";
import { Notice, Spinner } from "@/components/ui";
import { useRequireAuth } from "@/lib/useRequireAuth";
import { supabase } from "@/lib/supabase";
import { HOTEL } from "@/lib/hotel";
import { niceDate, todayManila } from "@/lib/format";
import type { Role } from "@/lib/types";

// The staff portal's own frame: who is signed in, the sections they can use, and
// counts of what needs doing. Sections live at /staff?tab=<key>.

export type TabKey = "today" | "calendar" | "find" | "walkin" | "rooms" | "dashboard" | "reviews" | "team";

// One staff role (admin) sees every section
export const NAV: { group: string; items: { key: TabKey; label: string }[] }[] = [
  {
    group: "Reservations",
    items: [
      { key: "today", label: "Today" },
      { key: "calendar", label: "Calendar" },
      { key: "find", label: "Find a booking" },
      { key: "walkin", label: "New booking" },
    ],
  },
  {
    group: "Hotel",
    items: [
      { key: "rooms", label: "Rooms" },
      { key: "dashboard", label: "Dashboard" },
      { key: "reviews", label: "Reviews" },
      { key: "team", label: "Team" },
    ],
  },
];

export const ROLE_LABEL: Record<Role, string> = { guest: "Guest", admin: "Admin" };

const TABS: TabKey[] = NAV.flatMap((g) => g.items.map((i) => i.key));

/** The section in the URL, or Today */
export function currentTab(asked: string | null): TabKey {
  return TABS.includes(asked as TabKey) ? (asked as TabKey) : "today";
}

type Counts = { arrivals: number; departures: number; dirty: number };

export function StaffShell({ children }: { children: ReactNode }) {
  const { session, profile, loading, profileLoading, isStaff } = useRequireAuth();
  const user = session?.user;
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const onHome = pathname === "/staff";
  const active = onHome ? currentTab(params.get("tab")) : null;
  const counts = useCounts(isStaff ? `${pathname}?${params}` : null);

  async function signOut() {
    await supabase().auth.signOut();
    router.push("/");
  }

  const groups = NAV;
  const badge = (key: TabKey) =>
    key === "today" ? (counts ? counts.arrivals + counts.departures : 0) : key === "rooms" ? (counts?.dirty ?? 0) : 0;
  const badgeLabel = (key: TabKey) =>
    key === "today" && counts
      ? `${counts.arrivals} arriving, ${counts.departures} leaving today`
      : key === "rooms" && counts
        ? `${counts.dirty} to clean`
        : "";

  return (
    <div className="flex min-h-dvh flex-col bg-sand">
      <header className="sticky top-0 z-30 bg-bay text-on-bay print:hidden">
        <div className="mx-auto flex max-w-7xl items-center gap-3 px-4 py-3 sm:px-6">
          <Link href="/staff" className="flex min-w-0 items-center gap-2.5 font-display text-lg font-semibold tracking-tight">
            <CapizMark />
            <span className="hidden truncate sm:inline">{HOTEL.name}</span>
            <span className="rounded-full border border-on-bay/30 px-2 py-0.5 font-sans text-[11px] font-semibold uppercase tracking-[0.12em] text-on-bay-muted">
              Staff
            </span>
          </Link>
          <p className="ml-auto hidden text-sm text-on-bay-muted md:block">{niceDate(todayManila(), true)}</p>
          {profile && (
            <div className="ml-auto min-w-0 text-right text-sm leading-tight md:ml-4">
              <p className="truncate font-semibold">{profile.full_name || user?.email}</p>
              <p className="text-on-bay-muted">{ROLE_LABEL[profile.role]}</p>
            </div>
          )}
          {session && (
            <Link href="/password" className="hidden rounded-full px-3 py-2 text-sm text-on-bay-muted transition-colors hover:text-on-bay sm:inline-flex">
              Password
            </Link>
          )}
          <Link href="/" className="hidden rounded-full px-3 py-2 text-sm text-on-bay-muted transition-colors hover:text-on-bay sm:inline-flex">
            Website
          </Link>
          {session && (
            <button onClick={signOut} className="shrink-0 rounded-full border border-on-bay/30 px-3.5 py-1.5 text-sm font-medium transition-colors hover:bg-on-bay/10">
              Sign out
            </button>
          )}
        </div>
      </header>

      {loading || !session || profileLoading ? (
        <div className="mx-auto w-full max-w-7xl px-4 sm:px-6"><Spinner /></div>
      ) : !isStaff ? (
        <div className="mx-auto w-full max-w-2xl px-4 py-12 sm:px-6">
          <Notice tone="warn">
            This area is for hotel staff. Ask an admin to add {user?.email ? <strong>{user.email}</strong> : "your email"} on the Team page.
          </Notice>
          <Link href="/" className="btn-quiet mt-6">Back to the website</Link>
        </div>
      ) : (
        <div className="mx-auto w-full max-w-7xl flex-1 px-4 pb-16 sm:px-6 lg:grid lg:grid-cols-[13.5rem_minmax(0,1fr)] lg:gap-10">
          {/* Phones and tablets: one scrolling row of sections */}
          <nav aria-label="Staff sections" className="-mx-4 flex gap-2 overflow-x-auto px-4 py-4 sm:-mx-6 sm:px-6 lg:hidden">
            {groups.flatMap((g) => g.items).map((i) => (
              <Link key={i.key} href={`/staff?tab=${i.key}`} aria-current={active === i.key ? "page" : undefined}
                className={`inline-flex shrink-0 items-center gap-2 rounded-full border px-3.5 py-2 text-sm font-medium transition-colors ${active === i.key ? "border-bay bg-bay text-on-bay" : "border-line bg-paper text-ink hover:border-sea"}`}>
                {i.label}
                <Count n={badge(i.key)} label={badgeLabel(i.key)} inverted={active === i.key} />
              </Link>
            ))}
            {/* The header has no room for these on phones */}
            <Link href="/password" className="inline-flex shrink-0 items-center rounded-full border border-dashed border-line px-3.5 py-2 text-sm text-muted sm:hidden">Password</Link>
            <Link href="/" className="inline-flex shrink-0 items-center rounded-full border border-dashed border-line px-3.5 py-2 text-sm text-muted sm:hidden">Website</Link>
          </nav>

          {/* Desktop: sections grouped by job */}
          <nav aria-label="Staff sections" className="sticky top-[4.5rem] hidden self-start py-10 lg:block">
            {groups.map((g) => (
              <div key={g.group} className="mb-6">
                <p className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-[0.12em] text-muted">{g.group}</p>
                <ul className="grid gap-0.5">
                  {g.items.map((i) => (
                    <li key={i.key}>
                      <Link href={`/staff?tab=${i.key}`} aria-current={active === i.key ? "page" : undefined}
                        className={`flex items-center justify-between rounded-lg px-3 py-2 text-[15px] transition-colors ${active === i.key ? "bg-bay font-semibold text-on-bay" : "text-ink hover:bg-paper"}`}>
                        {i.label}
                        <Count n={badge(i.key)} label={badgeLabel(i.key)} inverted={active === i.key} />
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </nav>

          <div className="min-w-0 lg:py-10">{children}</div>
        </div>
      )}
    </div>
  );
}

function Count({ n, label, inverted }: { n: number; label: string; inverted?: boolean }) {
  if (!n) return null;
  return (
    <span className={`min-w-6 rounded-full px-1.5 py-0.5 text-center text-xs font-semibold tabular-nums ${inverted ? "bg-mango text-bay" : "bg-sun-tint text-sun"}`}
      title={label} aria-label={label}>
      {n}
    </span>
  );
}

// What needs doing today, refreshed whenever staff move between sections
function useCounts(key: string | null): Counts | null {
  const [counts, setCounts] = useState<Counts | null>(null);
  useEffect(() => {
    if (!key) return;
    let active = true;
    const sb = supabase();
    const today = todayManila();
    const head = { count: "exact" as const, head: true };
    Promise.all([
      sb.from("bookings").select("id", head).eq("status", "confirmed").eq("check_in", today),
      sb.from("bookings").select("id", head).eq("status", "confirmed").eq("check_out", today),
      sb.from("rooms").select("id", head).eq("status", "dirty"),
    ]).then(([a, d, r]) => {
      if (active) setCounts({ arrivals: a.count ?? 0, departures: d.count ?? 0, dirty: r.count ?? 0 });
    });
    return () => { active = false; };
  }, [key]);
  return counts;
}
