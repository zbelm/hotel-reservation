import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { Login } from "./Login";

export const metadata = { title: "Sign in" };

export default function LoginPage() {
  return (
    <div className="mx-auto max-w-md px-4 py-14 sm:px-6">
      <Suspense fallback={<Spinner />}>
        <Login />
      </Suspense>
    </div>
  );
}
