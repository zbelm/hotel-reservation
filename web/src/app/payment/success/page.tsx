import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { PaymentSuccess } from "./PaymentSuccess";

export const metadata = { title: "Payment received" };

export default function Page() {
  return (
    <div className="mx-auto max-w-xl px-4 py-14 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <PaymentSuccess />
      </Suspense>
    </div>
  );
}
