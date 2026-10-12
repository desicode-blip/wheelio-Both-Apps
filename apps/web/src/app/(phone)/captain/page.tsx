import type { Metadata } from "next";
import CaptainApp from "@/phone/captain/CaptainApp";

export const metadata: Metadata = {
  title: "Wheelio — Captain app (demo)",
  description: "Web version of the Wheelio captain (washer) app, running on sample data.",
  robots: { index: false },
};

export default function CaptainPage() {
  return <CaptainApp />;
}
