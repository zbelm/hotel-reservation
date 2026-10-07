import { CapizWindow } from "@/components/CapizHero";
import { Chevron, FacilityGlyph } from "@/components/Icons";
import { Page } from "@/components/Page";
import { SearchForm } from "@/components/SearchForm";
import { RoomsPreview } from "./RoomsPreview";
import { ABOUT, FACILITIES, FAQS, GETTING_HERE, HOTEL, POLICIES, mapEmbedUrl, mapsUrl } from "@/lib/hotel";

export default function Home() {
  return (
    <Page className="">
      <section className="relative overflow-hidden bg-bay text-on-bay">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 pb-28 pt-12 sm:px-6 sm:pt-16 lg:grid-cols-[1.2fr_0.8fr] lg:gap-16 lg:pb-32">
          <div>
            <p className="hero-rise text-on-bay-muted">{HOTEL.address}</p>
            <h1 className="hero-rise mt-4 text-[2.6rem] font-semibold leading-[0.98] sm:text-6xl lg:text-7xl" style={{ "--delay": "0.08s" } as React.CSSProperties}>
              Watch the sun set over Manila Bay from your room.
            </h1>
            <p className="hero-rise mt-6 max-w-lg text-lg text-on-bay-muted" style={{ "--delay": "0.16s" } as React.CSSProperties}>
              Twelve rooms, a rooftop pool and a café that bakes its own pandesal. Book here for our best rate and pay with GCash, Maya or card.
            </p>
          </div>
          <CapizWindow className="mx-auto max-w-[17rem] sm:max-w-xs lg:max-w-none" />
        </div>
      </section>

      <div className="relative z-10 mx-auto -mt-16 max-w-6xl px-4 sm:px-6">
        <SearchForm />
      </div>

      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <section id="about" className="grid gap-10 py-20 md:grid-cols-[1.3fr_1fr] md:gap-16">
          <div>
            <h2 className="text-3xl font-semibold sm:text-4xl">{ABOUT.heading}</h2>
            {ABOUT.body.map((p) => (
              <p key={p.slice(0, 20)} className="mt-5 max-w-[62ch] text-lg leading-relaxed text-muted">{p}</p>
            ))}
          </div>
          <dl className="grid self-start gap-px overflow-hidden rounded-2xl border border-line bg-line">
            {ABOUT.facts.map((f) => (
              <div key={f.term} className="flex items-baseline justify-between gap-6 bg-paper px-5 py-4">
                <dt className="text-muted">{f.term}</dt>
                <dd className="text-right font-semibold">{f.detail}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section id="rooms" className="border-t border-line py-20">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <h2 className="text-3xl font-semibold sm:text-4xl">Rooms</h2>
            <p className="max-w-md text-muted">Every room has air conditioning, fast Wi-Fi and a view of the water. Prices change by date; pick yours to see exact totals.</p>
          </div>
          <RoomsPreview />
        </section>

        <section id="facilities" className="border-t border-line py-20">
          <h2 className="text-3xl font-semibold sm:text-4xl">Around the hotel</h2>
          <ul className="mt-10 grid gap-x-10 gap-y-8 sm:grid-cols-2 lg:grid-cols-4">
            {FACILITIES.map((f) => (
              <li key={f.name}>
                <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-sea-tint text-sea"><FacilityGlyph icon={f.icon} /></span>
                <h3 className="mt-4 text-lg font-semibold">{f.name}</h3>
                <p className="mt-1.5 text-[15px] leading-relaxed text-muted">{f.detail}</p>
              </li>
            ))}
          </ul>
        </section>

        <section id="location" className="grid gap-10 border-t border-line py-20 lg:grid-cols-[1.5fr_1fr]">
          <div className="overflow-hidden rounded-2xl border-[6px] border-narra/80 bg-line">
            <iframe
              src={mapEmbedUrl}
              title={`Map showing ${HOTEL.name}`}
              loading="lazy"
              className="block h-80 w-full sm:h-[26rem]"
              referrerPolicy="no-referrer"
            />
          </div>
          <div>
            <h2 className="text-3xl font-semibold sm:text-4xl">Getting here</h2>
            <p className="mt-4 text-lg">{HOTEL.address}</p>
            <ul className="mt-5 space-y-3 text-muted">
              {GETTING_HERE.map((g) => (
                <li key={g} className="flex gap-3"><span aria-hidden className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-narra" />{g}</li>
              ))}
            </ul>
            <a href={mapsUrl} target="_blank" rel="noreferrer" className="btn-quiet mt-7">Open in Google Maps</a>
          </div>
        </section>

        <section id="policies" className="border-t border-line py-20">
          <h2 className="text-3xl font-semibold sm:text-4xl">House rules and cancellation</h2>
          <p className="mt-3 max-w-2xl text-muted">The short version: bring an ID, pay when you book, and flexible rates can be cancelled for free until 48 hours before you arrive.</p>
          <dl className="mt-10 divide-y divide-line border-y border-line">
            {POLICIES.map((p) => (
              <div key={p.title} className="grid gap-2 py-5 md:grid-cols-[16rem_1fr] md:gap-10">
                <dt className="font-semibold">{p.title}</dt>
                <dd className="max-w-[68ch] text-muted">{p.body}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section id="faq" className="grid gap-10 border-t border-line py-20 lg:grid-cols-[1fr_1.6fr]">
          <div>
            <h2 className="text-3xl font-semibold sm:text-4xl">Questions guests ask</h2>
            <p className="mt-4 text-muted">
              Something else? Call the front desk on{" "}
              <a href={`tel:${HOTEL.phone.replace(/\s/g, "")}`} className="font-medium text-sea underline-offset-4 hover:underline">{HOTEL.phone}</a>, any time of day.
            </p>
          </div>
          <div className="divide-y divide-line border-y border-line">
            {FAQS.map((f) => (
              <details key={f.q} name="faq" className="disclose group">
                <summary className="flex items-center justify-between gap-4 py-5 text-lg font-medium transition-colors hover:text-sea">
                  {f.q}
                  <Chevron className="chev shrink-0 text-muted" />
                </summary>
                <p className="max-w-[62ch] pb-6 text-muted">{f.a}</p>
              </details>
            ))}
          </div>
        </section>
      </div>
    </Page>
  );
}
