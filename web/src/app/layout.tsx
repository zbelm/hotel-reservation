import type { Metadata, Viewport } from "next";
import "@fontsource-variable/fraunces";
import "@fontsource-variable/inter";
import "./globals.css";
import { AuthProvider } from "@/components/AuthProvider";
import { Header } from "@/components/Header";
import { HOTEL } from "@/lib/hotel";

export const metadata: Metadata = {
  title: { default: HOTEL.name, template: `%s · ${HOTEL.name}` },
  description: `Book your stay at ${HOTEL.name}. Pay with GCash, Maya or card.`,
  manifest: "/manifest.webmanifest",
};

export const viewport: Viewport = {
  themeColor: "#0e5e5a",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full">
      <body className="flex min-h-full flex-col">
        <AuthProvider>
          <Header />
          <main className="flex-1">{children}</main>
          <footer className="border-t border-line px-4 py-8 text-center text-sm text-muted">
            {HOTEL.name} · {HOTEL.address} · {HOTEL.phone}
          </footer>
        </AuthProvider>
      </body>
    </html>
  );
}
