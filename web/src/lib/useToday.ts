"use client";

import { useSyncExternalStore } from "react";
import { todayManila } from "./format";

const subscribe = () => () => {};

// Today's date in Manila. Empty while prerendering, so the build date never leaks into the page.
export function useToday(): string {
  return useSyncExternalStore(subscribe, todayManila, () => "");
}
