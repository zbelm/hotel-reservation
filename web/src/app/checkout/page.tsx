import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { Checkout } from "./Checkout";

export const metadata = { title: "Guest details" };

export default function CheckoutPage() {
  return (
    <div className="mx-auto max-w-5xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <Checkout />
      </Suspense>
    </div>
  );
}
