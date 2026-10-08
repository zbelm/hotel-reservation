"use client";

import { useT } from "@/lib/i18n";
import { useState } from "react";
import { functionError, supabase } from "@/lib/supabase";

// Opens PayMongo's checkout for a held booking
export function PayNowButton({ bookingId, label }: { bookingId: string; label?: string }) {
  const { t } = useT();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function pay() {
    setBusy(true);
    setError("");
    const { data, error } = await supabase().functions.invoke("create-checkout", { body: { booking_id: bookingId } });
    if (error || !data?.checkout_url) {
      setError(error ? await functionError(error) : t.payment.couldNotStart);
      setBusy(false);
      return;
    }
    window.location.href = data.checkout_url;
  }

  return (
    <div>
      <button className="btn-primary" onClick={pay} disabled={busy}>{busy ? t.booking.openingCheckout : label ?? t.booking.payNow}</button>
      {error && <p className="mt-2 text-sm text-bad">{error}</p>}
    </div>
  );
}
