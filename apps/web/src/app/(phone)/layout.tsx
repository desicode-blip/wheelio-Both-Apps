import type { Viewport } from "next";
import localFont from "next/font/local";
import "@/phone/ds/phone.css";

// The phone apps use all four Roboto weights the iOS apps bundle.
const roboto = localFont({
  src: [
    { path: "../fonts/Roboto-Regular.ttf", weight: "400", style: "normal" },
    { path: "../fonts/Roboto-Medium.ttf", weight: "500", style: "normal" },
    { path: "../fonts/Roboto-SemiBold.ttf", weight: "600", style: "normal" },
    { path: "../fonts/Roboto-Bold.ttf", weight: "700", style: "normal" },
  ],
  variable: "--font-wh",
  display: "swap",
});

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
  themeColor: "#ffffff",
};

export default function PhoneLayout({ children }: { children: React.ReactNode }) {
  return <div className={roboto.variable}>{children}</div>;
}
