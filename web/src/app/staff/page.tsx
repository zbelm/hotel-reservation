import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { StaffHome } from "./StaffHome";

export const metadata = { title: "Staff" };

export default function RoutePage() {
  return (
    <Page className="min-w-0">
      <Suspense fallback={<Spinner />}>
        <StaffHome />
      </Suspense>
    </Page>
  );
}
