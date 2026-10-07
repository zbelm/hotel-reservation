import type { FacilityIcon } from "@/lib/hotel";

const paths: Record<FacilityIcon, React.ReactNode> = {
  pool: (
    <>
      <path d="M8 4v10M16 4v10M8 7h8M8 11h8" />
      <path d="M3 17c1.5 0 1.5 1 3 1s1.5-1 3-1 1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1" />
      <path d="M3 21c1.5 0 1.5 1 3 1s1.5-1 3-1 1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1" />
    </>
  ),
  food: (
    <>
      <path d="M6 3v7a2 2 0 0 0 4 0V3M8 10v11" />
      <path d="M17 21V3c-2 1.5-3 4-3 7h3" />
    </>
  ),
  wifi: (
    <>
      <path d="M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.5 16a5 5 0 0 1 7 0" />
      <circle cx="12" cy="19.5" r="1" fill="currentColor" />
    </>
  ),
  car: (
    <>
      <path d="M4 16v-4l2-5h12l2 5v4z" />
      <path d="M4 12h16M6.5 16v2.5M17.5 16v2.5" />
      <circle cx="8" cy="14" r="0.6" fill="currentColor" />
      <circle cx="16" cy="14" r="0.6" fill="currentColor" />
    </>
  ),
  plane: <path d="M10.5 21l1.5-1 1.5 1v-4l7-4v-2l-7 2V6a1.5 1.5 0 0 0-3 0v7l-7-2v2l7 4z" />,
  gym: <path d="M3 10v4M6 8v8M18 8v8M21 10v4M6 12h12" />,
  laundry: (
    <>
      <rect x="4" y="3" width="16" height="18" rx="2" />
      <circle cx="12" cy="13" r="4.5" />
      <path d="M7 6.5h2" />
    </>
  ),
  lift: (
    <>
      <rect x="5" y="3" width="14" height="18" rx="1.5" />
      <path d="M12 3v18M8.5 9l-1.5 2h3zM15.5 15l-1.5-2h3z" />
    </>
  ),
};

export function FacilityGlyph({ icon }: { icon: FacilityIcon }) {
  return (
    <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      {paths[icon]}
    </svg>
  );
}

export function Chevron({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={`h-5 w-5 ${className}`} fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M5 8l5 5 5-5" />
    </svg>
  );
}
