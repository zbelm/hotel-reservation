import type { BookingStatus, Occupancy, RoomStatus } from "./types";

const peso = new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP", maximumFractionDigits: 0 });
const pesoExact = new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" });

export const money = (n: number | string | null | undefined) => peso.format(Number(n ?? 0));
export const moneyExact = (n: number | string | null | undefined) => pesoExact.format(Number(n ?? 0));

// Dates are plain YYYY-MM-DD strings in the hotel's time zone (Asia/Manila)
export function todayManila(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Manila" }).format(new Date());
}

// True once check-in time on that date has passed at the hotel (Manila is UTC+8 all year)
export function stayStarted(checkIn: string, checkInTime: string): boolean {
  const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(checkInTime.trim());
  const h = m ? (Number(m[1]) % 12) + (m[3].toUpperCase() === "PM" ? 12 : 0) : 14;
  const min = m ? Number(m[2]) : 0;
  const pad = (n: number) => String(n).padStart(2, "0");
  return Date.now() >= Date.parse(`${checkIn}T${pad(h)}:${pad(min)}:00+08:00`);
}

export function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export function nightsBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
}

export function niceDate(iso: string, withYear = false): string {
  return new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-PH", {
    timeZone: "UTC",
    weekday: "short",
    month: "short",
    day: "numeric",
    ...(withYear ? { year: "numeric" } : {}),
  });
}

export function niceTime(ts: string): string {
  return new Date(ts).toLocaleTimeString("en-PH", { timeZone: "Asia/Manila", hour: "numeric", minute: "2-digit" });
}

export const bookingStatusLabel: Record<BookingStatus, string> = {
  held: "On hold",
  confirmed: "Confirmed",
  checked_out: "Completed",
  cancelled: "Cancelled",
  no_show: "No-show",
  expired: "Expired",
};

export const roomStatusLabel: Record<RoomStatus, string> = {
  vacant_clean: "Clean",
  dirty: "Needs cleaning",
  cleaning: "Cleaning",
  out_of_order: "Out of order",
};

export const occupancyLabel: Record<Occupancy, string> = {
  occupied: "Occupied",
  leaving_soon: "Leaving soon",
  not_arrived: "Vacant – not arrived yet",
  empty: "Empty",
  out_of_order: "Out of order",
};

export function plural(n: number, word: string, many?: string): string {
  return `${n} ${n === 1 ? word : (many ?? `${word}s`)}`;
}

export function guests(adults: number, children: number): string {
  return children ? `${plural(adults, "adult")}, ${plural(children, "child", "children")}` : plural(adults, "adult");
}
