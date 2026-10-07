import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { StaffBooking } from "./StaffBooking";

export const metadata = { title: "Booking · Staff" };

export default function RoutePage() {
  return (
    <Page className="mx-auto max-w-4xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <StaffBooking />
      </Suspense>
    </Page>
  );
}
