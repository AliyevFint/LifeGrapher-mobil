import type { Metadata } from "next";
import "../styles/globals.css";

export const metadata: Metadata = {
  title: "LifeGrapher",
  description: "Personal health and life tracking dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
