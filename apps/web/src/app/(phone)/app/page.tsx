import type { Metadata } from "next";
import CustomerApp from "@/phone/customer/CustomerApp";

export const metadata: Metadata = {
  title: "Wheelio — Customer app (demo)",
  description: "Web version of the Wheelio customer app, running on sample data.",
  robots: { index: false },
};

export default function CustomerPage() {
  return <CustomerApp />;
}
