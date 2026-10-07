import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { PaymentSuccess } from "./PaymentSuccess";

export const metadata = { title: "Payment received" };

export default function RoutePage() {
  return (
    <Page className="mx-auto max-w-xl px-4 py-14 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <PaymentSuccess />
      </Suspense>
    </Page>
  );
}
