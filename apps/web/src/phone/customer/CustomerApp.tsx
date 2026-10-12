"use client";

// Customer app root: NavigationStack, splash, Screens gallery tab, in-app banner and toast.
// Ported from apps/ios/Customer/App/CustomerApp.swift.

import { useEffect, useState } from "react";
import { C } from "../ds/tokens";
import { Tap } from "../ds/components";
import { Fmt, Support } from "../lib/fmt";
import { useHub } from "../lib/reactive";
import { Layer, StackView } from "../shell/StackView";
import { PhoneShell } from "../shell/PhoneShell";
import { AppCtx, useApp, useOnAppear } from "./ctx";
import { createCustomerApp, type Route } from "./store";
import { SplashScreen, WelcomeScreen } from "./screens/start";
import {
  BookingDetailScreen, MainTabs, OfflineScreen, RepeatScreen, ServerErrorScreen, SessionExpiredScreen,
} from "./screens/home";
import {
  AddressSearchScreen, CameraScreen, EntryNotesScreen, FloorSlotScreen, LocationScreen, PhotosScreen, ReviewScreen, TimeSlotScreen,
  VehicleNumberScreen, VehicleTypeScreen, WashTypeScreen,
} from "./screens/booking";
import { BookedScreen, LoginScreen, NameScreen, NotifyAskScreen, OtpScreen, PayingScreen, WhatsAppScreen } from "./screens/authpay";
import { LiveOrderScreen, PhotoCompareScreen, RateScreen } from "./screens/live";
import { DisputeStatusScreen, ProblemPhotosScreen, RefundScreen, ReportProblemScreen } from "./screens/problem";
import { ChangePhoneScreen, EmergencyHelpScreen, HelpCaptainScreen, HelpScreen, RefundUPIScreen } from "./screens/support";
import { LiveNotificationBanner, NotificationSettingsScreen, NotificationsScreen } from "./screens/notifications";
import { GalleryScreen } from "./screens/gallery";

export default function CustomerApp() {
  const [app] = useState(createCustomerApp);
  useHub(app.hub);
  const { store, router } = app;

  useEffect(() => {
    if (process.env.NODE_ENV !== "production") (window as unknown as { __wh: unknown }).__wh = app;
    store.refreshSystemPermission();
    const vis = () => { if (document.visibilityState === "visible") store.refreshSystemPermission(); };
    const onCall = (e: Event) => { store.toast = `Demo: this would call ${Fmt.phone(String((e as CustomEvent).detail).replace("+91", ""))}`; };
    document.addEventListener("visibilitychange", vis);
    window.addEventListener("wh-call", onCall);
    return () => { document.removeEventListener("visibilitychange", vis); window.removeEventListener("wh-call", onCall); };
  }, [store]);

  const top = router.last;
  const statusLight = router.showSplash || (top?.n === "camera" && !top.denied) || top?.n === "photoCompare";

  return (
    <AppCtx.Provider value={app}>
      <PhoneShell app="customer" statusLight={statusLight}>
        <StackView
          root={store.isLoggedIn || store.hasSeenWelcome ? <MainTabs /> : <WelcomeScreen />}
          entries={router.path}
          render={(r) => <Destination route={r} />}
        />
        {router.showSplash && (
          <Layer className="wh-layer wh-fade-in" style={{ zIndex: 20 }}>
            <SplashScreen onDone={() => { router.showSplash = false; }} />
          </Layer>
        )}
        <GalleryTab />
        <LiveNotificationBanner />
      </PhoneShell>
    </AppCtx.Provider>
  );
}

/** Small "Screens" tab on the left edge in demo mode that opens the screen gallery. */
function GalleryTab() {
  const { router } = useApp();
  return (
    <Tap onClick={() => { router.showSplash = false; if (!router.is("gallery")) router.push({ n: "gallery" }); }} label="Screens gallery"
      style={{ position: "absolute", left: 0, top: "42%", zIndex: 55, padding: "5px 10px", borderRadius: "0 12px 12px 0", background: "rgba(27,37,51,.72)", color: "#fff", fontSize: 11, fontWeight: 600 }}>
      Screens
    </Tap>
  );
}

/** Booked and live screens tell the store which order is open, so no banner shows for it. */
function Viewing({ children }: { children: React.ReactNode }) {
  const { store, router } = useApp();
  useOnAppear(() => {
    store.viewingOrderId = store.currentOrderId;
    return () => { if (!router.is("live") && !router.is("booked")) store.viewingOrderId = null; };
  });
  return <>{children}</>;
}

function Destination({ route: r }: { route: Route }) {
  switch (r.n) {
    case "welcome": return <WelcomeScreen />;
    case "vehicleType": return <VehicleTypeScreen large={r.large} />;
    case "washType": return <WashTypeScreen />;
    case "vehicleNumber": return <VehicleNumberScreen />;
    case "photos": return <PhotosScreen />;
    case "camera": return <CameraScreen angle={r.angle} forceDenied={r.denied} />;
    case "location": return <LocationScreen forceOff={r.off} />;
    case "addressSearch": return <AddressSearchScreen />;
    case "floorSlot": return <FloorSlotScreen />;
    case "entryNotes": return <EntryNotesScreen />;
    case "timeSlot": return <TimeSlotScreen />;
    case "review": return <ReviewScreen />;
    case "login": return <LoginScreen showError={r.error} />;
    case "otp": return <OtpScreen start={r.start} />;
    case "name": return <NameScreen />;
    case "paying": return <PayingScreen initial={r.view} />;
    case "booked": return <Viewing><BookedScreen /></Viewing>;
    case "whatsApp": return <WhatsAppScreen />;
    case "notifyAsk": return <NotifyAskScreen />;
    case "live": return <LiveOrderScreen />;
    case "photoCompare": return <PhotoCompareScreen />;
    case "rate": return <RateScreen />;
    case "reportProblem": return <ReportProblemScreen />;
    case "problemPhotos": return <ProblemPhotosScreen kind={r.kind} />;
    case "disputeStatus": return <DisputeStatusScreen />;
    case "refund": return <RefundScreen />;
    case "bookingDetail": return <BookingDetailScreen orderId={r.id} />;
    case "repeatBooking": return <RepeatScreen id={r.id} />;
    case "help": return <HelpScreen />;
    case "helpCaptain": return <HelpCaptainScreen topic={r.topic} />;
    case "helpEmergency": return <EmergencyHelpScreen />;
    case "changePhone": return <ChangePhoneScreen />;
    case "notifications": return <NotificationsScreen />;
    case "refundUPI": return <RefundUPIScreen orderId={r.id} />;
    case "notificationSettings": return <NotificationSettingsScreen />;
    case "offline": return <OfflineScreen />;
    case "serverError": return <ServerErrorScreen />;
    case "sessionExpired": return <SessionExpiredScreen />;
    case "gallery": return <GalleryScreen />;
  }
}

