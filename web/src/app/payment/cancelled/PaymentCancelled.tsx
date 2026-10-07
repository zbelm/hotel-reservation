"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";
import { PayNowButton } from "@/components/PayNowButton";

export function PaymentCancelled() {
  const id = useSearchParams().get("booking") ?? "";
  const { session, loading } = useAuth();

  return (
    <div className="card p-8 text-center">
      <h1 className="text-3xl font-semibold">Payment not completed</h1>
      <p className="mt-3 text-muted">
        No money was taken. Your room stays on hold for a few more minutes if you&rsquo;d like to try again.
      </p>
      {!loading && (session ? (
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <PayNowButton bookingId={id} label="Try paying again" />
          <Link href={`/booking?id=${id}`} className="btn-quiet">View booking</Link>
        </div>
      ) : (
        <p className="mt-6 text-sm text-muted">Booked in the app? Go back to the app to try again.</p>
      ))}
    </div>
  );
}
