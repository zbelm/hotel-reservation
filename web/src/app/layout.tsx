import type { Metadata, Viewport } from "next";
import "@fontsource-variable/bricolage-grotesque/standard.css";
import "@fontsource-variable/figtree";
import "./globals.css";
import { AuthProvider } from "@/components/AuthProvider";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { HOTEL } from "@/lib/hotel";

export const metadata: Metadata = {
  title: { default: HOTEL.name, template: `%s · ${HOTEL.name}` },
  description: `${HOTEL.name}: twelve rooms on Manila Bay. Book direct and pay with GCash, Maya or card.`,
  manifest: "/manifest.webmanifest",
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
