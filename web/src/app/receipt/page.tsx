import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { Receipt } from "./Receipt";

export const metadata = { title: "Receipt" };

export default function ReceiptPage() {
  return (
    <Page className="mx-auto max-w-3xl px-4 py-10 sm:px-6 print:max-w-none print:p-0">
      <Suspense fallback={<Spinner />}>
        <Receipt />
      </Suspense>
    </Page>
  );
}
