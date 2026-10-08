import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { StaffBooking } from "./StaffBooking";

export const metadata = { title: "Booking · Staff" };

export default function RoutePage() {
  return (
    <Page className="min-w-0 max-w-4xl pt-2 lg:pt-0">
      <Suspense fallback={<Spinner />}>
        <StaffBooking />
      </Suspense>
    </Page>
  );
}
