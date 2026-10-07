import { ViewTransition, type ReactNode } from "react";

// Wraps each page so moving through the booking steps slides forward, going back slides
// back, and any other navigation crossfades. The animations are in globals.css.
const motion = { "nav-forward": "nav-forward", "nav-back": "nav-back", default: "page-fade" };

export function Page({ children, className = "mx-auto max-w-6xl px-4 py-10 sm:px-6" }: { children: ReactNode; className?: string }) {
  return (
    <ViewTransition enter={motion} exit={motion} default="none">
      <div className={className}>{children}</div>
    </ViewTransition>
  );
}

export const FORWARD = ["nav-forward"];
export const BACK = ["nav-back"];
