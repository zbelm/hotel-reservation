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
      {eyebrow && <p className="mb-2 text-sm font-semibold text-sea">{eyebrow}</p>}
      <h1 className="text-3xl font-semibold sm:text-4xl">{title}</h1>
      {children && <div className="mt-3 max-w-2xl text-muted">{children}</div>}
    </div>
  );
}

// Rooms have no photos in the sample data, so each room type gets an illustration:
// its bed, facing a capiz window open onto the bay. Real photos (room_types.photos) replace it.
export function RoomArt({ name, photo, className = "" }: { name: string; photo?: string; className?: string }) {
  if (photo) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={photo} alt={name} className={`h-full w-full object-cover ${className}`} />;
  }
  const seed = [...name].reduce((h, c) => h + c.charCodeAt(0), 0);
  const walls = ["#d9e3dd", "#e6ddd0", "#d6dfe4", "#e3dbd6"];
  const throws = ["#1b6b73", "#b8572e", "#13303b", "#7b4b2a"];
  const wall = walls[seed % walls.length];
  const accent = throws[seed % throws.length];
  const twoBeds = /suite|family|twin/i.test(name);
  return (
    <div aria-hidden className={`relative h-full w-full overflow-hidden ${className}`} style={{ background: wall }}>
      <svg viewBox="0 0 400 260" preserveAspectRatio="xMidYMid slice" className="absolute inset-0 h-full w-full">
        <defs>
          <linearGradient id={`dusk-${seed}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#7d4e6b" />
            <stop offset="0.55" stopColor="#e07b55" />
            <stop offset="1" stopColor="#f0a23b" />
          </linearGradient>
        </defs>
        {/* window onto the bay */}
        <rect x="118" y="26" width="164" height="118" fill="#7b4b2a" rx="3" />
        <rect x="126" y="34" width="148" height="102" fill={`url(#dusk-${seed})`} />
        <circle cx="212" cy="104" r="15" fill="#ffd27a" />
        <rect x="126" y="104" width="148" height="32" fill="#2c4558" />
        <rect x="198" y="110" width="28" height="2.5" rx="1" fill="#ffd27a" opacity="0.7" />
        <rect x="204" y="118" width="16" height="2.5" rx="1" fill="#ffd27a" opacity="0.5" />
        {/* capiz panes slid to the sides */}
        {[96, 282].map((x) => (
          <g key={x}>
            <rect x={x} y="26" width="22" height="118" fill="#efe9da" stroke="#7b4b2a" strokeWidth="3" />
            <path d={`M${x} 46h22M${x} 66h22M${x} 86h22M${x} 106h22M${x} 126h22M${x + 11} 26v118`} stroke="#7b4b2a" strokeWidth="1.5" />
          </g>
        ))}
        {/* floor */}
        <rect x="0" y="196" width="400" height="64" fill="#b98e66" opacity="0.55" />
        {/* bed(s) */}
        {(twoBeds ? [{ x: 48, w: 140 }, { x: 212, w: 140 }] : [{ x: 92, w: 216 }]).map((bed) => (
          <g key={bed.x}>
            <rect x={bed.x} y="150" width={bed.w} height="16" rx="3" fill="#7b4b2a" />
            <rect x={bed.x} y="166" width={bed.w} height="52" rx="6" fill="#fafcfa" />
            <rect x={bed.x + 10} y="158" width={bed.w / 2 - 16} height="18" rx="7" fill="#ffffff" stroke="#d3ddd8" />
            <rect x={bed.x + bed.w / 2 + 6} y="158" width={bed.w / 2 - 16} height="18" rx="7" fill="#ffffff" stroke="#d3ddd8" />
            <rect x={bed.x} y="196" width={bed.w} height="22" rx="4" fill={accent} opacity="0.9" />
            <rect x={bed.x + 4} y="218" width="6" height="14" fill="#7b4b2a" />
            <rect x={bed.x + bed.w - 10} y="218" width="6" height="14" fill="#7b4b2a" />
          </g>
        ))}
      </svg>
    </div>
  );
}
