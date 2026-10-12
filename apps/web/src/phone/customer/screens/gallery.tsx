"use client";

import { C } from "../../ds/tokens";
import { AppBar, Button, Divider, Screen, Tap, T, TD, ToggleRow, VStack } from "../../ds/components";
import { Icon } from "../../ds/icons";
import { useApp } from "../ctx";
import { VehicleTypes } from "../model";
import { SAMPLE_PHONE, type AppStore, type Route } from "../store";

type Entry = { id: string; title: string; prep: (s: AppStore) => void; route?: Route; tab?: number };

const E = (id: string, title: string, prep: (s: AppStore) => void, route?: Route, tab?: number): Entry => ({ id, title, prep, route, tab });
const none = () => {};

/** Screens gallery (demo mode only). Opens every designed screen and state with the right sample data. */
export const sections: [string, Entry[]][] = [
  ["01 · Book a wash", [
    E("C01", "Splash", none, undefined, -1),
    E("C02", "Welcome", (s) => s.signOut(), { n: "welcome" }),
    E("C05", "Vehicle type", (s) => s.draftBasics(), { n: "vehicleType" }),
    E("C05w", "Wash type – car", (s) => { s.draftBasics(); s.draft.wash = null; }, { n: "washType" }),
    E("C05wb", "Wash type – bike", (s) => { s.draftBasics(); s.draft.type = VehicleTypes[0]; s.draft.wash = null; }, { n: "washType" }),
    E("C06", "Vehicle number", (s) => s.draftBasics(), { n: "vehicleNumber" }),
    E("C07", "Vehicle photos – empty", (s) => s.draftBasics(), { n: "photos" }),
    E("C07b", "Vehicle photos – one failed", (s) => { s.draftBasics(); s.draft.photos.front = "done"; s.draft.photos.back = "failed"; }, { n: "photos" }),
    E("C07c", "Vehicle photos – all done", (s) => { s.draftFull(); s.draft.place = null; }, { n: "photos" }),
    E("C08", "Camera – guided angle", (s) => s.draftBasics(), { n: "camera", angle: "front" }),
    E("C08b", "Camera access needed", none, { n: "camera", angle: "front", denied: true }),
    E("C09", "Confirm location", (s) => { s.draftFull(); s.draft.place = null; }, { n: "location" }),
    E("C09b", "Location is off", none, { n: "location", off: true }),
    E("C09c", "Search address", (s) => s.draftFull(), { n: "addressSearch" }),
    E("C10", "Floor and slot", (s) => s.draftFull(), { n: "floorSlot" }),
    E("C11", "Notes for the captain", (s) => s.draftFull(), { n: "entryNotes" }),
    E("C12", "Pick a time", (s) => s.draftFull(), { n: "timeSlot" }),
    E("C12b", "No captains free today", (s) => { s.draftFull(); s.demo.noCaptainsToday = true; }, { n: "timeSlot" }),
    E("C13", "Check and pay", (s) => s.draftFull(), { n: "review" }),
    E("C14", "Log in with phone", (s) => { s.signOut(); s.draftFull(); }, { n: "login" }),
    E("C14b", "Phone number – invalid", (s) => s.signOut(), { n: "login", error: true }),
    E("C15", "Enter code", (s) => { s.pendingPhone = SAMPLE_PHONE; }, { n: "otp", start: "entering" }),
    E("C15b", "Code – wrong", (s) => { s.pendingPhone = SAMPLE_PHONE; }, { n: "otp", start: "wrong" }),
    E("C15c", "Code – expired", (s) => { s.pendingPhone = SAMPLE_PHONE; }, { n: "otp", start: "expired" }),
    E("C16", "Your name", (s) => s.signInAsSample(), { n: "name" }),
    E("C17", "Payment method sheet", (s) => { s.signInAsSample(); s.draftFull(); }, { n: "review" }),
    E("C18", "Payment processing", (s) => { s.signInAsSample(); s.draftFull(); }, { n: "paying", view: "processing" }),
    E("C18b", "Payment failed", (s) => { s.signInAsSample(); s.draftFull(); }, { n: "paying", view: "failed" }),
    E("C18c", "Payment pending", (s) => { s.signInAsSample(); s.draftFull(); s.sampleOrder("paymentPending"); }, { n: "paying", view: "pending" }),
    E("C19", "Booked – send entry pass", (s) => { s.signInAsSample(); s.sampleOrder("searching"); }, { n: "booked" }),
    E("C19b", "WhatsApp bot (reference)", (s) => { s.signInAsSample(); s.sampleOrder("searching"); }, { n: "whatsApp" }),
  ]],
  ["02 · Live order, approve, cancel", [
    E("C20", "Finding a captain", (s) => { s.signInAsSample(); s.sampleOrder("searching"); }, { n: "live" }),
    E("C21", "No captain found – add UPI for refund", (s) => { s.signInAsSample(); if (s.customer) s.customer.refundUPI = null; s.sampleOrder("noCaptain"); }, { n: "live" }),
    E("C21u", "Refund UPI ID", (s) => { s.signInAsSample(); if (s.customer) s.customer.refundUPI = null; s.sampleOrder("noCaptain"); }, { n: "refundUPI", id: "current" }),
    E("C24x", "Captain no-show – checking", (s) => { s.signInAsSample(); s.markNoShowChecking(); }, { n: "live" }),
    E("C24y", "Captain no-show – refunded", (s) => { s.signInAsSample(); if (s.customer) s.customer.refundUPI = null; s.sampleOrder("captainNoShow"); }, { n: "live" }),
    E("C22", "Captain on the way", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay"); }, { n: "live" }),
    E("C22b", "Entry pass missing", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay", { passMissing: true }); }, { n: "live" }),
    E("C24", "Captain running late", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay", { late: true }); }, { n: "live" }),
    E("C30", "Captain can’t find vehicle", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay", { cantFind: true }); }, { n: "live" }),
    E("C23", "Washing in progress", (s) => { s.signInAsSample(); s.sampleOrder("washing"); }, { n: "live" }),
    E("C25", "Wash done – check photos", (s) => { s.signInAsSample(); s.sampleOrder("photosReady"); }, { n: "live" }),
    E("C26", "Photo compare", (s) => { s.signInAsSample(); s.sampleOrder("photosReady"); }, { n: "photoCompare" }),
    E("C27", "Rate the captain", (s) => { s.signInAsSample(); s.sampleOrder("approved"); }, { n: "rate" }),
    E("C28", "Approved automatically", (s) => { s.signInAsSample(); s.sampleOrder("autoApproved"); }, { n: "live" }),
    E("C29", "Cancel sheet (open from C20)", (s) => { s.signInAsSample(); s.sampleOrder("searching"); }, { n: "live" }),
    E("C29c", "Cancel after accept (open from C22)", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay"); }, { n: "live" }),
    E("C29b", "Booking cancelled", (s) => { s.signInAsSample(); s.sampleOrder("cancelled"); }, { n: "live" }),
  ]],
  ["03 · Problems, disputes, refunds", [
    E("C31", "Report a problem", (s) => { s.signInAsSample(); s.sampleOrder("photosReady"); }, { n: "reportProblem" }),
    E("C31s", "Report a problem – photos skipped", (s) => { s.signInAsSample(); s.sampleOrder("photosReady", { skippedPhotos: true }); }, { n: "reportProblem" }),
    E("C32", "Show us the problem", (s) => { s.signInAsSample(); s.sampleOrder("photosReady"); }, { n: "problemPhotos", kind: "notClean" }),
    E("C33", "Report sent – under review", (s) => { s.signInAsSample(); s.sampleOrder("disputed", { dispute: "underReview" }); }, { n: "disputeStatus" }),
    E("C34", "Dispute upheld", (s) => { s.signInAsSample(); s.sampleOrder("disputeUpheld", { dispute: "upheld" }); }, { n: "disputeStatus" }),
    E("C35", "Dispute rejected", (s) => { s.signInAsSample(); s.sampleOrder("disputeRejected", { dispute: "rejected" }); }, { n: "disputeStatus" }),
    E("C36", "Damage report", (s) => { s.signInAsSample(); s.sampleOrder("disputed", { dispute: "damagePriority", damage: true }); }, { n: "disputeStatus" }),
    E("C37", "Refund status", (s) => { s.signInAsSample(); s.sampleOrder("cancelled"); }, { n: "refund" }),
  ]],
  ["04 · Home, bookings, account, system", [
    E("C40", "Home – first time", (s) => { s.signInAsSample(); s.demo.emptyHistory = true; }, undefined, 0),
    E("C41", "Home – active booking", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay"); }, undefined, 0),
    E("C42", "Home – free washes", (s) => s.signInAsSample(2), undefined, 0),
    E("C43", "Bookings – upcoming", (s) => { s.signInAsSample(); s.sampleOrder("onTheWay"); }, undefined, 1),
    E("C43b", "Bookings – empty", (s) => { s.signInAsSample(); s.demo.emptyHistory = true; }, undefined, 1),
    E("C43c", "Bookings – past", (s) => s.signInAsSample(), undefined, 1),
    E("C44", "Booking detail", (s) => s.signInAsSample(), { n: "bookingDetail", id: "ord_past1" }),
    E("C45", "Book again", (s) => s.signInAsSample(), { n: "repeatBooking", id: "veh_car" }),
    E("C46", "Your vehicles", (s) => s.signInAsSample(), undefined, 2),
    E("C47", "Profile", (s) => s.signInAsSample(2), undefined, 3),
    E("C48", "Help", none, { n: "help" }),
    E("N1", "Notifications", (s) => s.signInAsSample(), { n: "notifications" }),
    E("N2", "Notification settings", (s) => s.signInAsSample(), { n: "notificationSettings" }),
    E("C49", "Notifications ask", (s) => { s.signInAsSample(); s.sampleOrder("searching"); }, { n: "notifyAsk" }),
    E("C50", "Offline", none, { n: "offline" }),
    E("C51", "Server error", none, { n: "serverError" }),
    E("C52", "200% text", (s) => s.draftBasics(), { n: "vehicleType", large: true }),
    E("C53", "Delete account (Profile → Delete)", (s) => s.signInAsSample(2), undefined, 3),
    E("C54", "Session expired", (s) => s.signInAsSample(), { n: "sessionExpired" }),
  ]],
];

export function GalleryScreen() {
  const { store, router } = useApp();
  const open = (e: Entry) => {
    store.resetDemo();
    e.prep(store);
    if (e.tab === -1) { router.popToRoot(); router.showSplash = true; return; }
    if (e.tab != null) { store.hasSeenWelcome = true; router.tab = e.tab; router.popToRoot(); return; }
    if (e.route) {
      if (e.route.n === "welcome") { store.hasSeenWelcome = false; router.popToRoot(); return; }
      router.replace([e.route]);
      if (e.id === "C17") setTimeout(() => { router.showPaySheet = true; }, 600);
    }
  };
  const d = store.demo;
  const toggle = (title: string, on: boolean, set: (v: boolean) => void) => (
    <ToggleRow key={title} on={on} onChange={set} style={{ padding: "6px 0" }}><T k="body" s={15} c={C.heading}>{title}</T></ToggleRow>
  );
  return (
    <Screen header={<AppBar title="Screens" subtitle="Demo mode · sample data" trailing={null} onLeading={() => router.pop()} style={{ padding: "0 14px" }} />}>
      <TD k="label" style={{ paddingTop: 10, paddingBottom: 6 }}>Switches for the live flow</TD>
      <VStack style={{ paddingBottom: 8 }}>
        {toggle("Payment fails", d.payment === "failed", (v) => { store.demo.payment = v ? "failed" : "success"; })}
        {toggle("Payment stays pending", d.payment === "pending", (v) => { store.demo.payment = v ? "pending" : "success"; })}
        {toggle("No captain found", d.noCaptainFound, (v) => { store.demo.noCaptainFound = v; })}
        {toggle("Captain runs late", d.captainRunsLate, (v) => { store.demo.captainRunsLate = v; })}
        {toggle("Captain doesn’t show up", d.captainNoShow, (v) => { store.demo.captainNoShow = v; })}
        {toggle("Captain can’t find vehicle", d.captainCantFind, (v) => { store.demo.captainCantFind = v; })}
        {toggle("Entry pass never arrives", d.entryPassNeverArrives, (v) => { store.demo.entryPassNeverArrives = v; })}
        {toggle("Back photo fails once", d.failBackPhotoOnce, (v) => { store.demo.failBackPhotoOnce = v; })}
        {toggle("Dispute gets rejected", d.disputeRejected, (v) => { store.demo.disputeRejected = v; })}
      </VStack>
      <Button title="Reset demo" kind="tonal" onClick={() => store.resetDemo()} style={{ marginBottom: 10 }} />
      <Button title="Open the Captain app" kind="outline" icon="arrowRight" onClick={() => { window.location.href = "/captain"; }} style={{ marginBottom: 10 }} />
      {sections.map(([title, list]) => (
        <div key={title}>
          <TD k="section" w={600} style={{ paddingTop: 22, paddingBottom: 4 }}>{title}</TD>
          {list.map((e) => (
            <div key={e.id}>
              <Tap className="wh-nopress wh-row" onClick={() => open(e)} style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 0", width: "100%", textAlign: "left" }}>
                <T k="label" c={C.primaryStrong} style={{ width: 46, flexShrink: 0 }}>{e.id}</T>
                <T k="rowTitle" style={{ flex: 1 }}>{e.title}</T>
                <Icon name="chevron" size={14} color={C.secondary} />
              </Tap>
              <Divider />
            </div>
          ))}
        </div>
      ))}
    </Screen>
  );
}
