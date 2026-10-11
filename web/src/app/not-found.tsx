import Link from "next/link";
import { Page } from "@/components/Page";

export const metadata = { title: "Page not found", robots: { index: false } };

export default function NotFound() {
  return (
    <Page className="mx-auto max-w-xl px-4 py-20 text-center sm:px-6">
      <p className="text-sm font-semibold uppercase tracking-[0.14em] text-sea">404</p>
      <h1 className="mt-3 text-4xl font-semibold">We couldn&apos;t find that page</h1>
      <p className="mt-3 text-muted">The link may be old or mistyped. Hindi namin mahanap ang pahinang ito.</p>
      <div className="mt-8 flex flex-wrap justify-center gap-3">
        <Link href="/" className="btn-primary">Back to the hotel</Link>
        <Link href="/bookings" className="btn-quiet">My stays</Link>
      </div>
    </Page>
  );
}
