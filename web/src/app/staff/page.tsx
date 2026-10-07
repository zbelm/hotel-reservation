import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { StaffHome } from "./StaffHome";

export const metadata = { title: "Staff" };

export default function Page() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <StaffHome />
      </Suspense>
    </div>
  );
}
