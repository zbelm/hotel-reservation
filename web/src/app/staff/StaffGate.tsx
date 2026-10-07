"use client";

import type { ReactNode } from "react";
import { Notice, Spinner } from "@/components/ui";
import { useRequireAuth } from "@/lib/useRequireAuth";

// UI guard only; the database enforces the real rules
export function StaffGate({ children }: { children: ReactNode }) {
  const { session, profile, loading, isStaff } = useRequireAuth();
  if (loading || !session || (session && !profile)) return <Spinner />;
  if (!isStaff) {
    return (
      <Notice tone="error">
        This area is for hotel staff. Ask a manager to give your account a staff role.
      </Notice>
    );
  }
  return <>{children}</>;
}
