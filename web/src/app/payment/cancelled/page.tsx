import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { PaymentCancelled } from "./PaymentCancelled";

export const metadata = { title: "Payment not completed" };

export default function Page() {
  return (
    <div className="mx-auto max-w-xl px-4 py-14 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <PaymentCancelled />
      </Suspense>
    </div>
  );
}
