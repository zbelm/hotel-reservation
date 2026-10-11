"use client";

import { Chevron, FacilityGlyph } from "@/components/Icons";
import { Reviews } from "@/components/Reviews";
import { SearchForm } from "@/components/SearchForm";
import { RoomsPreview } from "./RoomsPreview";
import { HOTEL, mapEmbedUrl, mapsUrl } from "@/lib/hotel";
import { PHOTOS } from "@/lib/photos";
import { useT } from "@/lib/i18n";

export function HomeContent() {
  const { t, hotel, lang } = useT();
  return (
    <>
      <section className="relative overflow-hidden bg-bay text-on-bay">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 pb-28 pt-12 sm:px-6 sm:pt-16 lg:grid-cols-[1.2fr_0.8fr] lg:gap-16 lg:pb-32">
          <div>
            <p className="hero-rise text-on-bay-muted">{HOTEL.address}</p>
            <h1 className="hero-rise mt-4 text-[2.6rem] font-semibold leading-[0.98] sm:text-6xl lg:text-7xl" style={{ "--delay": "0.08s" } as React.CSSProperties}>
              {t.home.title}
            </h1>
            <p className="hero-rise mt-6 max-w-lg text-lg text-on-bay-muted" style={{ "--delay": "0.16s" } as React.CSSProperties}>
              {t.home.intro}
            </p>
          </div>
          <figure className="hero-rise relative mx-auto aspect-[4/5] w-full max-w-[20rem] overflow-hidden rounded-[2rem] shadow-2xl ring-1 ring-white/15 sm:max-w-sm lg:max-w-none" style={{ "--delay": "0.12s" } as React.CSSProperties}>
            {/* eslint-disable-next-line @next/next/no-img-element -- Unsplash serves the right size */}
            <img
              src={PHOTOS.exterior.src(900)}
              srcSet={`${PHOTOS.exterior.src(600)} 600w, ${PHOTOS.exterior.src(900)} 900w, ${PHOTOS.exterior.src(1300)} 1300w`}
              sizes="(min-width: 1024px) 400px, 90vw"
              alt={lang === "fil" ? PHOTOS.exterior.altFil : PHOTOS.exterior.alt}
              className="h-full w-full object-cover"
              fetchPriority="high"
            />
          </figure>
        </div>
      </section>

      <div className="relative z-10 mx-auto -mt-16 max-w-6xl px-4 sm:px-6">
        <SearchForm />
      </div>

      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <section id="about" className="grid gap-10 py-20 md:grid-cols-[1.3fr_1fr] md:gap-16">
          <div>
            <h2 className="text-3xl font-semibold sm:text-4xl">{hotel.about.heading}</h2>
            {hotel.about.body.map((p) => (
              <p key={p.slice(0, 20)} className="mt-5 max-w-[62ch] text-lg leading-relaxed text-muted">{p}</p>
            ))}
          </div>
          <dl className="grid self-start gap-px overflow-hidden rounded-2xl border border-line bg-line">
            {hotel.about.facts.map((f) => (
              <div key={f.term} className="flex items-baseline justify-between gap-6 bg-paper px-5 py-4">
                <dt className="text-muted">{f.term}</dt>
                <dd className="text-right font-semibold">{f.detail}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section id="rooms" className="border-t border-line py-20">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <h2 className="text-3xl font-semibold sm:text-4xl">{t.home.rooms}</h2>
            <p className="max-w-md text-muted">{t.home.roomsIntro}</p>
          </div>
          <RoomsPreview />
        </section>

        <section id="facilities" className="border-t border-line py-20">
          <h2 className="text-3xl font-semibold sm:text-4xl">{t.home.facilities}</h2>
          <div className="mt-10 grid gap-4 sm:grid-cols-2">
            {([[PHOTOS.pool, hotel.facilities[0]?.name], [PHOTOS.cafe, hotel.facilities[1]?.name]] as const).map(([photo, label]) => (
              <figure key={photo.id} className="lift relative aspect-[16/10] overflow-hidden rounded-2xl">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={photo.src(1000)} alt={lang === "fil" ? photo.altFil : photo.alt} loading="lazy" className="lift-art h-full w-full object-cover" />
                <figcaption className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/65 to-transparent px-5 pb-4 pt-12 font-display text-xl font-semibold text-white">{label}</figcaption>
              </figure>
            ))}
          </div>
          <ul className="mt-12 grid gap-x-10 gap-y-8 sm:grid-cols-2 lg:grid-cols-4">
            {hotel.facilities.map((f) => (
              <li key={f.icon}>
                <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-sea-tint text-sea"><FacilityGlyph icon={f.icon} /></span>
                <h3 className="mt-4 text-lg font-semibold">{f.name}</h3>
                <p className="mt-1.5 text-[15px] leading-relaxed text-muted">{f.detail}</p>
              </li>
            ))}
          </ul>
        </section>

        <section id="reviews" className="border-t border-line py-20">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <h2 className="text-3xl font-semibold sm:text-4xl">{t.reviews.heading}</h2>
            <p className="max-w-md text-muted">{t.reviews.intro}</p>
          </div>
          <Reviews />
        </section>

        <section id="location" className="grid gap-10 border-t border-line py-20 lg:grid-cols-[1.5fr_1fr]">
          <div className="overflow-hidden rounded-2xl border-[6px] border-narra/80 bg-line">
            <iframe src={mapEmbedUrl} title={t.home.mapTitle(HOTEL.name)} loading="lazy" className="block h-80 w-full sm:h-[26rem]" referrerPolicy="no-referrer" />
          </div>
          <div>
            <h2 className="text-3xl font-semibold sm:text-4xl">{t.home.gettingHere}</h2>
            <p className="mt-4 text-lg">{HOTEL.address}</p>
            <ul className="mt-5 space-y-3 text-muted">
              {hotel.gettingHere.map((g) => (
                <li key={g} className="flex gap-3"><span aria-hidden className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-narra" />{g}</li>
              ))}
            </ul>
            <a href={mapsUrl} target="_blank" rel="noreferrer" className="btn-quiet mt-7">{t.home.openMaps}</a>
          </div>
        </section>

        <section id="policies" className="border-t border-line py-20">
          <h2 className="text-3xl font-semibold sm:text-4xl">{t.home.policies}</h2>
          <p className="mt-3 max-w-2xl text-muted">{t.home.policiesIntro}</p>
          <dl className="mt-10 divide-y divide-line border-y border-line">
            {hotel.policies.map((p) => (
              <div key={p.title} className="grid gap-2 py-5 md:grid-cols-[16rem_1fr] md:gap-10">
                <dt className="font-semibold">{p.title}</dt>
                <dd className="max-w-[68ch] text-muted">{p.body}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section id="faq" className="grid gap-10 border-t border-line py-20 lg:grid-cols-[1fr_1.6fr]">
          <div>
            <h2 className="text-3xl font-semibold sm:text-4xl">{t.home.faq}</h2>
            <p className="mt-4 text-muted">
              {t.home.faqBefore}{" "}
              <a href={`tel:${HOTEL.phone.replace(/\s/g, "")}`} className="font-medium text-sea underline-offset-4 hover:underline">{HOTEL.phone}</a>{t.home.faqAfter}
            </p>
          </div>
          <div className="divide-y divide-line border-y border-line">
            {hotel.faqs.map((f) => (
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
    </>
  );
}
