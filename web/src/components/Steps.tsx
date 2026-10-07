// Where the guest is in the booking: these four steps really are a sequence, so they're numbered.
const STEPS = ["Dates", "Room and rate", "Your details", "Payment"];

export function Steps({ current }: { current: 1 | 2 | 3 | 4 }) {
  return (
    <nav aria-label="Booking progress" className="mb-8">
      <ol className="flex flex-wrap items-center gap-x-2 gap-y-2 text-sm">
        {STEPS.map((label, i) => {
          const n = i + 1;
          const done = n < current;
          const here = n === current;
          return (
            <li key={label} className="flex items-center gap-2" aria-current={here ? "step" : undefined}>
              <span
                className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold transition-colors ${
                  here ? "bg-mango text-[#13303b]" : done ? "bg-sea text-paper" : "border border-line text-muted"
                }`}
              >
                {done ? (
                  <svg viewBox="0 0 16 16" className="h-3.5 w-3.5" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden>
                    <path d="M3.5 8.5l3 3 6-7" />
                  </svg>
                ) : (
                  n
                )}
              </span>
              <span className={here ? "font-semibold text-ink" : "text-muted"}>{label}</span>
              {n < STEPS.length && <span aria-hidden className={`mx-1 hidden h-px w-8 sm:block ${done ? "bg-sea" : "bg-line"}`} />}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
