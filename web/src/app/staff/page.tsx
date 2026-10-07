import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { StaffHome } from "./StaffHome";

export const metadata = { title: "Staff" };

export default function RoutePage() {
  return (
    <Page className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <StaffHome />
      </Suspense>
    </Page>
  );
}
