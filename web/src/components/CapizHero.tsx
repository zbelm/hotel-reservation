// The view from the lobby: capiz shell panes slide open onto the bay at sunset.
// Pure CSS/SVG; the motion lives in globals.css (.capiz-*, .bay-*), and stops for reduced motion.
export function CapizWindow({ className = "" }: { className?: string }) {
  return (
    <div className={`capiz-window aspect-[4/5] w-full ${className}`} role="img" aria-label="Sunset over the bay, seen through a capiz shell window">
      <svg viewBox="0 0 400 500" preserveAspectRatio="xMidYMid slice" className="absolute inset-0 h-full w-full" aria-hidden>
        <defs>
          <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#24395a" />
            <stop offset="0.38" stopColor="#7d4e6b" />
            <stop offset="0.62" stopColor="#d9705a" />
            <stop offset="0.82" stopColor="#f0a23b" />
          </linearGradient>
          <linearGradient id="water" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#c8663f" />
            <stop offset="0.35" stopColor="#5b4659" />
            <stop offset="1" stopColor="#13303b" />
          </linearGradient>
          <radialGradient id="glow">
            <stop offset="0" stopColor="#ffd987" stopOpacity="0.85" />
            <stop offset="1" stopColor="#ffd987" stopOpacity="0" />
          </radialGradient>
          <clipPath id="above-water">
            <rect x="0" y="0" width="400" height="318" />
          </clipPath>
        </defs>

        <rect width="400" height="500" fill="url(#sky)" />

        <g clipPath="url(#above-water)">
          <g className="bay-sun">
            <circle cx="214" cy="292" r="120" fill="url(#glow)" />
            <circle cx="214" cy="292" r="44" fill="#ffd27a" />
          </g>
        </g>

        {/* far shore */}
        <path d="M0 312 L40 306 L70 309 L96 301 L130 307 L170 304 L230 309 L268 303 L300 307 L340 300 L372 306 L400 303 V320 H0Z" fill="#3a2c45" opacity="0.85" />

        <rect y="318" width="400" height="182" fill="url(#water)" />

        {/* sun's path on the water */}
        <g fill="#ffd27a">
          <rect x="190" y="326" width="48" height="3" rx="1.5" opacity="0.8" />
          <rect x="198" y="338" width="34" height="3" rx="1.5" opacity="0.6" />
          <rect x="182" y="351" width="62" height="3" rx="1.5" opacity="0.45" />
          <rect x="203" y="366" width="24" height="3" rx="1.5" opacity="0.35" />
        </g>

        {/* a bangka heading home */}
        <g transform="translate(92 323)" fill="#1d2433">
          <path d="M0 6 Q22 13 46 6 L42 10 Q22 15 4 10Z" />
          <rect x="21" y="-14" width="2" height="20" />
          <path d="M23 -13 L38 4 L23 4Z" opacity="0.9" />
          <rect x="-8" y="11" width="62" height="1.6" rx="0.8" />
        </g>

        <g stroke="#f6e3c4" strokeWidth="2" fill="none" strokeLinecap="round" opacity="0.35">
          <path className="bay-wave" d="M-40 392 q20 -6 40 0 t40 0 t40 0 t40 0 t40 0 t40 0 t40 0 t40 0 t40 0 t40 0 t40 0 t40 0" />
          <path className="bay-wave slow" d="M-40 428 q24 -7 48 0 t48 0 t48 0 t48 0 t48 0 t48 0 t48 0 t48 0 t48 0 t48 0" />
          <path className="bay-wave" d="M-40 466 q28 -8 56 0 t56 0 t56 0 t56 0 t56 0 t56 0 t56 0 t56 0 t56 0" />
        </g>
      </svg>

      <div className="capiz-pane left" aria-hidden />
      <div className="capiz-pane right" aria-hidden />
    </div>
  );
}
