import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "VidGrab Admin Panel",
  description: "Admin panel for VidGrab video downloader",
  manifest: "/manifest.json",
  icons: {
    icon: "/assets/app-logo.png",
  },
  other: {
    "theme-color": "#38bdf8",
    "apple-mobile-web-app-capable": "yes",
    "apple-mobile-web-app-title": "VidGrab",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className={inter.className}>
        {children}
        <Toaster />
      </body>
    </html>
  );
}
