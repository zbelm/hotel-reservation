import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { BookingDetail } from "./BookingDetail";

export const metadata = { title: "Booking" };

export default function Page() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <BookingDetail />
      </Suspense>
    </div>
  );
}
