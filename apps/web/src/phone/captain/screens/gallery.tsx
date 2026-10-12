"use client";

import { C, S } from "../../ds/tokens";
import { AppBar, Button, Divider, Screen, Segmented, Tap, T, TD, ToggleRow, VStack } from "../../ds/components";
import { Icon } from "../../ds/icons";
import { useCaptain } from "../ctx";
import { Langs, type CaptainStore, type Route, type WRouter } from "../store";

/** stage: 0 new (language), 1 guest exploring, 2 signed up (no KYC), 3 ready for jobs. */
type E = { id: string; title: string; prep?: (s: CaptainStore) => void; routes?: Route[]; tab?: number; stage?: number };

const ROUTES = {
  goTo: { n: "goToVehicle" } as Route,
};

/** Screens gallery (demo only): opens every captain screen with sample data. */
export const sections: [string, E[]][] = [
  ["06 · Welcome, sign-up, KYC", [
    { id: "W01", title: "Choose language", stage: 0 },
    { id: "W00", title: "Welcome: earnings and benefits", routes: [{ n: "welcome" }], stage: 0 },
    { id: "W00g", title: "Home as a guest (exploring)", tab: 0, stage: 1 },
    { id: "W00m", title: "Me as a guest", tab: 3, stage: 1 },
    { id: "W00j", title: "Jobs as a guest (example day)", tab: 1, stage: 1 },
    { id: "W02", title: "Sign up: name and number", routes: [{ n: "signUp", login: false }], stage: 1 },
    { id: "W02l", title: "Log in: number only", routes: [{ n: "signUp", login: true }], stage: 1 },
    { id: "W03", title: "Enter the code", routes: [{ n: "otp", login: false }], stage: 1 },
    { id: "W03h", title: "Home after sign-up (KYC card)", tab: 0, stage: 2 },
    { id: "W16", title: "Accept a job → quick KYC", prep: (s) => { s.steps = {}; s.kycFromJob = true; }, routes: [{ n: "steps", problem: false }], stage: 2 },
    { id: "W16a", title: "Job rings for a new captain (accept → KYC)", routes: [{ n: "jobAlert", batched: false }], stage: 2 },
    { id: "W04", title: "4 steps (process overview)", prep: (s) => { s.steps = {}; }, routes: [{ n: "steps", problem: false }], stage: 2 },
    { id: "W05", title: "Verify Aadhaar", routes: [{ n: "aadhaar", unclear: false }], stage: 2 },
    { id: "W05b", title: "Aadhaar photo not clear", routes: [{ n: "aadhaar", unclear: true }], stage: 2 },
    { id: "W06", title: "Your photo (selfie)", routes: [{ n: "selfie" }], stage: 2 },
    { id: "W07", title: "Get paid (UPI or bank)", routes: [{ n: "bank" }], stage: 2 },
    { id: "W08", title: "Training videos", prep: (s) => { s.videosWatched = 1; }, routes: [{ n: "training" }], stage: 2 },
    { id: "W09", title: "Video player", routes: [{ n: "video", index: 1 }], stage: 2 },
    { id: "W10", title: "Quiz", routes: [{ n: "quiz" }], stage: 2 },
    { id: "W11", title: "Quiz passed", routes: [{ n: "quizResult", passed: true }], stage: 2 },
    { id: "W11b", title: "Quiz failed", routes: [{ n: "quizResult", passed: false }], stage: 2 },
    { id: "W12", title: "Rules", routes: [{ n: "rules" }], stage: 2 },
    { id: "W13", title: "Verification call", routes: [{ n: "underReview" }], stage: 2 },
    { id: "W14", title: "You’re in", routes: [{ n: "live" }], stage: 2 },
    { id: "W15", title: "1 thing to fix (selfie mismatch)", routes: [{ n: "steps", problem: true }], stage: 2 },
  ]],
  ["07 · Home and jobs", [
    { id: "W20", title: "Home – offline", prep: (s) => { s.online = false; s.jobsToday = 0; s.jobLimit = 2; }, tab: 0 },
    { id: "W21", title: "Home – online (a job rings in 4 s)", prep: (s) => { s.online = true; }, tab: 0 },
    { id: "W50", title: "Home – low battery, no internet", prep: (s) => { s.online = true; s.lowSignal = true; }, tab: 0 },
    { id: "W22", title: "New job alert", routes: [{ n: "jobAlert", batched: false }] },
    { id: "W22m", title: "Many jobs: 3 ring, stacked (swipe left to skip)", routes: [{ n: "jobAlert", batched: false }] },
    { id: "W22s", title: "Single job (no others ring)", prep: (s) => { s.extraOffers = 0; }, routes: [{ n: "jobAlert", batched: false }] },
    { id: "W57", title: "Where I work (societies, distance, place)", routes: [{ n: "workArea" }] },
    { id: "W22o", title: "Job alert – only My Home Avatar", prep: (s) => { s.workMode = "societies"; s.chosenSocieties = ["My Home Avatar"]; }, routes: [{ n: "jobAlert", batched: false }] },
    { id: "W22b", title: "New job alert – batched", routes: [{ n: "jobAlert", batched: true }] },
    { id: "W22h", title: "New job alert – Hindi", prep: (s) => { s.lang = "hi"; }, routes: [{ n: "jobAlert", batched: false }] },
    { id: "W22t", title: "New job alert – Telugu", prep: (s) => { s.lang = "te"; }, routes: [{ n: "jobAlert", batched: false }] },
    { id: "W23", title: "Job went to someone else", routes: [{ n: "jobMissed" }] },
    { id: "W24", title: "Daily limit reached", prep: (s) => { s.online = true; s.jobsToday = 4; s.jobLimit = 4; s.earnedToday = 464; }, tab: 0 },
    { id: "W25", title: "Today’s jobs", tab: 1 },
    { id: "W26", title: "Go to vehicle", routes: [ROUTES.goTo] },
    { id: "W27", title: "Can’t get in (gate pass)", routes: [ROUTES.goTo, { n: "gateProblem" }] },
    { id: "W28", title: "Can’t find vehicle", routes: [ROUTES.goTo, { n: "cantFind" }] },
    { id: "W26o", title: "Owner’s note (plays first, must listen)", routes: [ROUTES.goTo, { n: "ownerNote" }] },
    { id: "W29", title: "Owner cancelled", routes: [{ n: "ownerCancelled" }] },
    { id: "W26n", title: "Didn’t show up: late → slot over → cancelled (≈20 s)", prep: (s) => { s.noShowDemo = true; }, routes: [ROUTES.goTo] },
    { id: "W55", title: "Job cancelled: didn’t reach in time", prep: (s) => { s.noShowCancelled = true; s.noShowPlate = "TS 09 EA 4521"; }, routes: [{ n: "noShowCancelled" }] },
  ]],
  ["08 · Wash and photos", [
    { id: "W30", title: "Quick face check", routes: [ROUTES.goTo, { n: "faceCheck" }] },
    { id: "W31", title: "Before photos", prep: (s) => { s.beforeDone = [0, 1]; s.ownerNoteHeard = true; }, routes: [ROUTES.goTo, { n: "beforePhotos" }] },
    { id: "W32", title: "Camera – guided side", routes: [ROUTES.goTo, { n: "beforePhotos" }, { n: "camera", after: false, side: 2 }] },
    { id: "W33", title: "Photo too dark", routes: [ROUTES.goTo, { n: "beforePhotos" }, { n: "photoDark" }] },
    { id: "W34", title: "Washing – timer", prep: (s) => { s.ownerNoteHeard = true; }, routes: [ROUTES.goTo, { n: "washing" }] },
    { id: "W34b", title: "Washing – late", prep: (s) => { s.lateWash = true; }, routes: [ROUTES.goTo, { n: "washing" }] },
    { id: "W35", title: "After photos", prep: (s) => { s.afterDone = [0, 1, 2]; }, routes: [ROUTES.goTo, { n: "afterPhotos" }] },
    { id: "W36", title: "AI photo check", prep: (s) => { s.afterDone = [0, 1, 2, 3]; }, routes: [ROUTES.goTo, { n: "afterPhotos" }, { n: "aiCheck" }] },
    { id: "W37", title: "Sending photos (weak signal)", prep: (s) => { s.lowSignal = true; }, routes: [{ n: "uploading" }] },
    { id: "W38", title: "Shine done", routes: [{ n: "jobDone", late: false }] },
    { id: "W38b", title: "Done, late", routes: [{ n: "jobDone", late: true }] },
  ]],
  ["09 · Money, level, account", [
    { id: "W40", title: "Money", tab: 2 },
    { id: "W41", title: "Payout detail", routes: [{ n: "payoutDetail" }] },
    { id: "W42", title: "Money held", routes: [{ n: "payoutHeld" }] },
    { id: "W43", title: "My level", routes: [{ n: "level" }] },
    { id: "W44", title: "Probation extended", routes: [{ n: "probationExtended" }] },
    { id: "W45", title: "Refresher video lock", routes: [{ n: "refresher" }] },
    { id: "W46", title: "Account blocked, appeal", routes: [{ n: "blocked" }] },
    { id: "W47", title: "Me (profile)", tab: 3 },
    { id: "W48", title: "Help: pick a problem", routes: [{ n: "help" }] },
    { id: "W48a", title: "Help · money (check → owner → team)", routes: [{ n: "help" }, { n: "helpFlow", topic: "money" }] },
    { id: "W48b", title: "Help · problem at a job", routes: [{ n: "help" }, { n: "helpFlow", topic: "job" }] },
    { id: "W48c", title: "Help · rating or photo check", routes: [{ n: "help" }, { n: "helpFlow", topic: "rating" }] },
    { id: "W48d", title: "Help · app not working (skips owner)", routes: [{ n: "help" }, { n: "helpFlow", topic: "app" }] },
    { id: "W51", title: "Notifications", prep: (s) => s.seedNotifications(), routes: [{ n: "notifications" }] },
    { id: "W51e", title: "Notifications – empty", prep: (s) => { s.notifications = []; }, routes: [{ n: "notifications" }] },
    { id: "W51o", title: "Notifications – alerts off", prep: (s) => { s.seedNotifications(); s.notificationsOn = false; }, routes: [{ n: "notifications" }] },
    { id: "W52", title: "Notification settings", routes: [{ n: "notificationSettings" }] },
    { id: "W53", title: "Change phone number", routes: [{ n: "changePhone" }] },
    { id: "W54", title: "Change payout UPI", routes: [{ n: "editUPI" }] },
    { id: "W56", title: "Live banner: new job (in-app)", prep: (s) => { s.seedNotifications(); s.online = true; s.notify("newJob", { job: s.current }); }, tab: 0 },
  ]],
];

export const allEntries = sections.flatMap(([, l]) => l);

export function openEntry(e: E, store: CaptainStore, router: WRouter) {
  const lang = router.tourLang ?? store.lang;
  const stage = e.stage ?? 3;
  store.resetDemo();
  store.lang = lang;
  store.signedUp = stage >= 3;
  store.registered = stage >= 2;
  store.exploring = stage >= 1;
  store.nudgeShown = true;
  if (stage >= 2 && !store.notifications.length) store.seedNotifications();
  e.prep?.(store);
  if (e.tab != null) { router.home(); router.tab = e.tab; return; }
  router.replace(e.routes ?? []);
}

export function WGalleryScreen() {
  const { store, router } = useCaptain();
  const open = (e: E) => { router.tourLang = store.lang; router.tour = allEntries.findIndex((x) => x.id === e.id); openEntry(e, store, router); };
  const toggle = (title: string, on: boolean, set: (v: boolean) => void) => (
    <ToggleRow key={title} on={on} onChange={set} style={{ padding: "6px 0" }}><T k="body" s={15} c={C.heading}>{title}</T></ToggleRow>
  );
  return (
    <Screen gutter={S.gutterCaptain} header={<AppBar title="Screens" subtitle="Demo mode · sample data" trailing={null} onLeading={() => router.pop()} />}>
      <TD k="label" style={{ paddingTop: 10, paddingBottom: 6 }}>Language</TD>
      <Segmented options={["English", "हिन्दी", "తెలుగు"]} selection={Langs.indexOf(store.lang)} onChange={(i) => { store.lang = Langs[i]; }} />
      <VStack style={{ paddingTop: 10 }}>
        {toggle("Dark photo on left side (W33)", store.darkPhoto, (v) => { store.darkPhoto = v; })}
        {toggle("AI flags the left mirror (W36)", store.aiFlag, (v) => { store.aiFlag = v; })}
        {toggle("Wash runs late (W34b)", store.lateWash, (v) => { store.lateWash = v; })}
        {toggle("Weak signal (W37, W50)", store.lowSignal, (v) => { store.lowSignal = v; })}
        {toggle("Batched job alert (W22b)", store.batchedAlert, (v) => { store.batchedAlert = v; })}
      </VStack>
      <Button title="Reset demo" kind="tonal" style={{ margin: "10px 0" }} onClick={() => store.resetDemo()} />
      <Button title="Step through all screens" kind="tonal" style={{ marginBottom: 10 }} onClick={() => { router.tour = 0; router.tourLang = store.lang; openEntry(allEntries[0], store, router); }} />
      <Button title="Open the Customer app" kind="outline" icon="arrowRight" style={{ marginBottom: 10 }} onClick={() => { window.location.href = "/app"; }} />
      {sections.map(([title, list]) => (
        <div key={title}>
          <TD k="section" w={600} style={{ paddingTop: 20, paddingBottom: 4 }}>{title}</TD>
          {list.map((e) => (
            <div key={e.id}>
              <Tap className="wh-nopress wh-row" onClick={() => open(e)} style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 0", width: "100%", textAlign: "left" }}>
                <T k="label" c={C.primaryStrong} style={{ width: 48, flexShrink: 0 }}>{e.id}</T>
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

