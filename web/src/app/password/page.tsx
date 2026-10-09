import { Suspense } from "react";
import { Page } from "@/components/Page";
import { Spinner } from "@/components/ui";
import { SetPassword } from "./SetPassword";

export const metadata = { title: "Your password" };

export default function PasswordPage() {
  return (
    <Page className="mx-auto max-w-md px-4 py-14 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <SetPassword />
      </Suspense>
    </Page>
  );
}
