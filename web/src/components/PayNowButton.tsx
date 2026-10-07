"use client";

import { useState } from "react";
import { functionError, supabase } from "@/lib/supabase";

// Opens PayMongo's checkout for a held booking
export function PayNowButton({ bookingId, label = "Pay now" }: { bookingId: string; label?: string }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function pay() {
    setBusy(true);
    setError("");
    const { data, error } = await supabase().functions.invoke("create-checkout", { body: { booking_id: bookingId } });
    if (error || !data?.checkout_url) {
      setError(error ? await functionError(error) : "Could not start payment");
      setBusy(false);
      return;
    }
    window.location.href = data.checkout_url;
  }

  return (
    <div>
      <button className="btn-primary" onClick={pay} disabled={busy}>{busy ? "Opening checkout…" : label}</button>
      {error && <p className="mt-2 text-sm text-bad">{error}</p>}
    </div>
  );
}
