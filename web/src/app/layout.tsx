import type { Metadata, Viewport } from "next";
import "@fontsource-variable/bricolage-grotesque/standard.css";
import "@fontsource-variable/figtree";
import "./globals.css";
import { AuthProvider } from "@/components/AuthProvider";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { HOTEL } from "@/lib/hotel";
import { PHOTOS } from "@/lib/photos";

const description = `${HOTEL.name}: twelve rooms near Manila Bay with a rooftop pool. Book direct for the best rate and pay at the hotel.`;

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://hotel-reservation-smoky.vercel.app"),
  title: { default: HOTEL.name, template: `%s · ${HOTEL.name}` },
  description,
  manifest: "/manifest.webmanifest",
  icons: { icon: "/icon.svg", apple: "/icon.svg" },
  openGraph: {
    type: "website",
    siteName: HOTEL.name,
    title: HOTEL.name,
    description,
    images: [{ url: PHOTOS.exterior.src(1200), width: 1200, height: 630, alt: PHOTOS.exterior.alt }],
  },
};

export const viewport: Viewport = {
  themeColor: "#13303b",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full">
      <body className="flex min-h-full flex-col">
        <AuthProvider>
          <Header />
          <main className="flex-1">{children}</main>
          <Footer />
        </AuthProvider>
      </body>
    </html>
  );
}
