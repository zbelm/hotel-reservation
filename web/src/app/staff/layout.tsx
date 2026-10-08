import { Suspense, type ReactNode } from "react";
import { Spinner } from "@/components/ui";
import { StaffShell } from "./StaffShell";

export default function StaffLayout({ children }: { children: ReactNode }) {
  return (
    <Suspense fallback={<div className="mx-auto max-w-7xl px-4 sm:px-6"><Spinner /></div>}>
      <StaffShell>{children}</StaffShell>
    </Suspense>
  );
}
