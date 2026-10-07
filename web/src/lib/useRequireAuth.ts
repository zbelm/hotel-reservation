"use client";

import { useEffect } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";

// Sends signed-out visitors to /login and brings them back afterwards
export function useRequireAuth() {
  const auth = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

  useEffect(() => {
    if (!auth.loading && !auth.session) {
      const here = params.size ? `${pathname}?${params}` : pathname;
      router.replace(`/login?next=${encodeURIComponent(here)}`);
    }
  }, [auth.loading, auth.session, pathname, params, router]);

  return auth;
}
