import type { ReactNode } from "react";
import type { BookingStatus, RoomStatus } from "@/lib/types";
import { bookingStatusLabel, roomStatusLabel } from "@/lib/format";

export function Spinner({ label = "Loading" }: { label?: string }) {
  return (
    <div className="flex items-center gap-3 py-10 text-muted" role="status">
      <span className="h-5 w-5 animate-spin rounded-full border-2 border-line border-t-sea" />
      <span>{label}…</span>
    </div>
  );
}

export function Notice({ tone = "info", children }: { tone?: "info" | "error" | "good" | "warn"; children: ReactNode }) {
  const tones = {
    info: "border-sea/30 bg-sea-tint text-ink",
    error: "border-bad/30 bg-bad-tint text-bad",
    good: "border-good/30 bg-good-tint text-good",
    warn: "border-sun/30 bg-sun-tint text-ink",
  };
  return <div className={`rounded-xl border px-4 py-3 text-sm ${tones[tone]}`} role={tone === "error" ? "alert" : undefined}>{children}</div>;
}

const bookingTone: Record<BookingStatus, string> = {
  held: "bg-sun-tint text-sun",
  confirmed: "bg-good-tint text-good",
  checked_in: "bg-sea-tint text-sea",
  checked_out: "bg-line/60 text-muted",
  cancelled: "bg-bad-tint text-bad",
  no_show: "bg-bad-tint text-bad",
  expired: "bg-line/60 text-muted",
};

export function BookingBadge({ status }: { status: BookingStatus }) {
  return (
    <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${bookingTone[status]}`}>
      {bookingStatusLabel[status]}
    </span>
  );
}

const roomTone: Record<RoomStatus, string> = {
  vacant_clean: "bg-good-tint text-good border-good/30",
  dirty: "bg-sun-tint text-sun border-sun/30",
  cleaning: "bg-sea-tint text-sea border-sea/30",
  occupied: "bg-paper text-ink border-line",
  out_of_order: "bg-bad-tint text-bad border-bad/30",
};

export function RoomBadge({ status }: { status: RoomStatus }) {
  return (
    <span className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-semibold ${roomTone[status]}`}>
      {roomStatusLabel[status]}
    </span>
  );
}

export function PageTitle({ eyebrow, title, children }: { eyebrow?: string; title: string; children?: ReactNode }) {
  return (
    <div className="mb-8">
      {eyebrow && <p className="mb-2 text-xs font-semibold uppercase tracking-[0.18em] text-sea">{eyebrow}</p>}
      <h1 className="text-3xl font-semibold sm:text-4xl">{title}</h1>
      {children && <div className="mt-3 max-w-2xl text-muted">{children}</div>}
    </div>
  );
}

// Rooms have no photos in the sample data; this draws a calm placeholder.
export function RoomArt({ name, photo, className = "" }: { name: string; photo?: string; className?: string }) {
  if (photo) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={photo} alt={name} className={`h-full w-full object-cover ${className}`} />;
  }
  const hue = [...name].reduce((h, c) => h + c.charCodeAt(0), 0) % 40;
  return (
    <div
      aria-hidden
      className={`relative h-full w-full overflow-hidden ${className}`}
      style={{ background: `linear-gradient(160deg, hsl(${168 + hue} 32% 34%), hsl(${30 + hue} 45% 78%))` }}
    >
      <svg viewBox="0 0 400 240" className="absolute inset-0 h-full w-full opacity-35" preserveAspectRatio="none">
        <path d="M0 170 Q100 140 200 165 T400 155 V240 H0Z" fill="white" />
        <path d="M0 195 Q120 170 230 192 T400 185 V240 H0Z" fill="white" />
        <circle cx="315" cy="70" r="26" fill="white" />
      </svg>
    </div>
  );
}
