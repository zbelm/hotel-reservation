import type { BookingStatus, RoomStatus } from "./types";

const peso = new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP", maximumFractionDigits: 0 });
const pesoExact = new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" });

export const money = (n: number | string | null | undefined) => peso.format(Number(n ?? 0));
export const moneyExact = (n: number | string | null | undefined) => pesoExact.format(Number(n ?? 0));

// Dates are plain YYYY-MM-DD strings in the hotel's time zone (Asia/Manila)
export function todayManila(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Manila" }).format(new Date());
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
  held: "Awaiting payment",
  confirmed: "Confirmed",
  checked_in: "Checked in",
  checked_out: "Completed",
  cancelled: "Cancelled",
  no_show: "No-show",
  expired: "Expired",
};

export const roomStatusLabel: Record<RoomStatus, string> = {
  vacant_clean: "Clean",
  dirty: "Dirty",
  cleaning: "Cleaning",
  occupied: "Occupied",
  out_of_order: "Out of order",
};

export function plural(n: number, word: string, many?: string): string {
  return `${n} ${n === 1 ? word : (many ?? `${word}s`)}`;
}

export function guests(adults: number, children: number): string {
  return children ? `${plural(adults, "adult")}, ${plural(children, "child", "children")}` : plural(adults, "adult");
}
