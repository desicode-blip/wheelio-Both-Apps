"use client";

// Captain (washer) app root, ported from apps/ios/Captain/App/CaptainApp.swift.

import { useEffect, useState } from "react";
import { Tap, VStack, HStack } from "../ds/components";
import { Fmt } from "../lib/fmt";
import { useHub } from "../lib/reactive";
import { StackView } from "../shell/StackView";
import { PhoneShell } from "../shell/PhoneShell";
import { CaptainCtx, useCaptain } from "./ctx";
import { createCaptainApp, type Route } from "./store";
import { LanguageScreen, SignUpScreen, WelcomeScreen, WOtpScreen } from "./screens/welcome";
import {
  AadhaarScreen, BankScreen, LiveScreen, QuizResultScreen, QuizScreen, RulesScreen, SelfieScreen, StepsScreen, TrainingScreen, UnderReviewScreen, VideoScreen,
} from "./screens/onboarding";
import { CantFindScreen, CaptainTabs, GateProblemScreen, GoToVehicleScreen, JobAlertScreen, JobMissedScreen, OwnerCancelledScreen } from "./screens/home";
import { AiCheckScreen, FaceCheckScreen, JobCameraScreen, JobDoneScreen, JobPhotosScreen, OwnerNoteScreen, PhotoDarkScreen, UploadingScreen, WashingScreen } from "./screens/wash";
import { BlockedScreen, LevelScreen, PayoutDetailScreen, PayoutHeldScreen, ProbationScreen, RefresherScreen, WHelpScreen } from "./screens/money";
import { WChangePhoneScreen, WEditUPIScreen, WLiveBanner, WNoShowCancelledScreen, WNotificationSettingsScreen, WNotificationsScreen } from "./screens/account";
import { HelpFlowScreen, WorkAreaScreen } from "./screens/help";
import { allEntries, openEntry, WGalleryScreen } from "./screens/gallery";

export default function CaptainApp() {
  const [app] = useState(createCaptainApp);
  useHub(app.hub);
  const { store, router } = app;

  useEffect(() => {
    if (process.env.NODE_ENV !== "production") (window as unknown as { __wc: unknown }).__wc = app;
    store.refreshSystemPermission();
    const vis = () => { if (document.visibilityState === "visible") store.refreshSystemPermission(); };
    const onCall = (e: Event) => { store.toast = `Demo: this would call ${Fmt.phone(String((e as CustomEvent).detail).replace("+91", ""))}`; };
    document.addEventListener("visibilitychange", vis);
    window.addEventListener("wh-call", onCall);
    return () => { document.removeEventListener("visibilitychange", vis); window.removeEventListener("wh-call", onCall); };
  }, [app, store]);

  // Seed the inbox the first time the captain registers.
  useEffect(() => { if (store.registered && !store.notifications.length) store.seedNotifications(); }, [store, store.registered]);

  const top = router.last?.n;
  const statusLight = top === "selfie" || top === "camera" || top === "jobAlert";

  return (
    <CaptainCtx.Provider value={app}>
      <PhoneShell app="captain" statusLight={statusLight}>
        <StackView root={store.signedUp || store.exploring ? <CaptainTabs /> : <LanguageScreen />} entries={router.path} render={(r) => <Destination route={r} />} />
        <GalleryTab />
        <WLiveBanner />
      </PhoneShell>
    </CaptainCtx.Provider>
  );
}

/** "Screens" tab on the left edge (demo), plus ‹ › to step through every screen. */
function GalleryTab() {
  const { store, router } = useCaptain();
  const i = router.tour;
  const step = (j: number) => {
    if (j < 0 || j >= allEntries.length) return;
    router.tour = j;
    openEntry(allEntries[j], store, router);
  };
  const pill = { background: "rgba(27,37,51,.72)", color: "#fff", borderRadius: "0 12px 12px 0" } as const;
  return (
    <>
      <Tap onClick={() => { if (!router.is("gallery")) router.push({ n: "gallery" }); }} label="Screens gallery"
        style={{ ...pill, position: "absolute", left: 0, top: "42%", zIndex: 55, padding: "5px 10px", fontSize: 11, fontWeight: 600 }}>
        Screens
      </Tap>
      {i != null && !router.is("gallery") && (
        <VStack gap={4} align="center" style={{ ...pill, position: "absolute", left: 0, top: "calc(42% + 30px)", zIndex: 55, padding: 4 }}>
          <span style={{ fontSize: 11, fontWeight: 600 }}>{allEntries[i].id}</span>
          <HStack>
            <Tap label="Previous screen" onClick={() => step(i - 1)} style={{ width: 26, height: 30, fontSize: 18, fontWeight: 700, color: "#fff" }}>‹</Tap>
            <Tap label="Next screen" onClick={() => step(i + 1)} style={{ width: 26, height: 30, fontSize: 18, fontWeight: 700, color: "#fff" }}>›</Tap>
          </HStack>
        </VStack>
      )}
    </>
  );
}

function Destination({ route: r }: { route: Route }) {
  switch (r.n) {
    case "welcome": return <WelcomeScreen />;
    case "signUp": return <SignUpScreen login={r.login} />;
    case "otp": return <WOtpScreen login={r.login} />;
    case "steps": return <StepsScreen problem={r.problem} />;
    case "aadhaar": return <AadhaarScreen unclear={r.unclear} />;
    case "selfie": return <SelfieScreen />;
    case "bank": return <BankScreen />;
    case "training": return <TrainingScreen />;
    case "video": return <VideoScreen index={r.index} />;
    case "quiz": return <QuizScreen />;
    case "quizResult": return <QuizResultScreen passed={r.passed} />;
    case "rules": return <RulesScreen />;
    case "underReview": return <UnderReviewScreen />;
    case "live": return <LiveScreen />;
    case "jobAlert": return <JobAlertScreen batched={r.batched} />;
    case "jobMissed": return <JobMissedScreen />;
    case "goToVehicle": return <GoToVehicleScreen />;
    case "gateProblem": return <GateProblemScreen />;
    case "cantFind": return <CantFindScreen />;
    case "ownerCancelled": return <OwnerCancelledScreen />;
    case "faceCheck": return <FaceCheckScreen />;
    case "beforePhotos": return <JobPhotosScreen after={false} />;
    case "camera": return <JobCameraScreen after={r.after} side={r.side} />;
    case "photoDark": return <PhotoDarkScreen />;
    case "washing": return <WashingScreen />;
    case "afterPhotos": return <JobPhotosScreen after />;
    case "aiCheck": return <AiCheckScreen />;
    case "uploading": return <UploadingScreen />;
    case "jobDone": return <JobDoneScreen late={r.late} />;
    case "payoutDetail": return <PayoutDetailScreen />;
    case "payoutHeld": return <PayoutHeldScreen />;
    case "level": return <LevelScreen />;
    case "probationExtended": return <ProbationScreen />;
    case "refresher": return <RefresherScreen />;
    case "blocked": return <BlockedScreen />;
    case "help": return <WHelpScreen />;
    case "notifications": return <WNotificationsScreen />;
    case "notificationSettings": return <WNotificationSettingsScreen />;
    case "changePhone": return <WChangePhoneScreen />;
    case "editUPI": return <WEditUPIScreen />;
    case "noShowCancelled": return <WNoShowCancelledScreen />;
    case "workArea": return <WorkAreaScreen />;
    case "ownerNote": return <OwnerNoteScreen />;
    case "helpFlow": return <HelpFlowScreen topic={r.topic} />;
    case "gallery": return <WGalleryScreen />;
  }
}
