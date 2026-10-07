import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { PaymentCancelled } from "./PaymentCancelled";

export const metadata = { title: "Payment not completed" };

export default function RoutePage() {
  return (
    <Page className="mx-auto max-w-xl px-4 py-14 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <PaymentCancelled />
      </Suspense>
    </Page>
  );
}
