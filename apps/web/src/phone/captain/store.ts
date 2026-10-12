// Captain app state with sample data from the designs (Raju, TS 09 EA 4521).
// Ported from apps/ios/Captain/Data/CaptainStore.swift and WNotifications.swift.

import type { IconName } from "../ds/icons";
import type { Tone } from "../ds/tokens";
import { addDays, Fmt, newId, sleep, startOfDay } from "../lib/fmt";
import { appIsActive, buzz, ding, requestPermission, systemNotify, systemPermission, type Permission } from "../lib/device";
import { Hub, reactive, run, type Job as Task } from "../lib/reactive";
import { Nav } from "../lib/nav";

/** Captain app language. Captains pick it on the first screen (W01). */
export type Lang = "en" | "hi" | "te";
export const Langs: Lang[] = ["en", "hi", "te"];

/** What the owner booked (mirrors the customer app's wash choices). */
export type WashType = "dryDusting" | "wetOutside" | "wetOutsideDryInside";
export const washWater = (w: WashType) => w !== "dryDusting";
export const washInside = (w: WashType) => w === "wetOutsideDryInside";

export type JobStatus = "now" | "next" | "done";

export type Job = {
  id: string; plate: string; type: string; isBike: boolean; pay: number; tower: string; floor: string; slot: string;
  window: string; time: string; distance: string; status: JobStatus; reachBy: string; finishBy: string; owner: string;
  society: string; wash: WashType; area: string;
};

const job = (p: Partial<Job> & Pick<Job, "id" | "plate" | "type" | "isBike" | "pay" | "tower" | "floor" | "slot" | "window" | "time">): Job => ({
  distance: "600 m", status: "next", reachBy: "8:40 AM", finishBy: "8:55 AM", owner: "Ananya", society: "My Home Avatar", wash: "wetOutside", area: "Narsingi", ...p,
});

export const JobFmt = {
  /** "Tower 3 · Floor B2 · Slot 41" */
  spot: (j: Job) => [j.tower, `Floor ${j.floor}`, j.slot ? `Slot ${j.slot}` : null].filter(Boolean).join(" · "),
  fullAddress: (j: Job) => `${JobFmt.spot(j)}, ${j.society}, ${j.area}, Hyderabad`,
  km: (j: Job) => { const n = parseFloat(j.distance.replace(/[^0-9.]/g, "")) || 0; return j.distance.includes("km") ? n : n / 1000; },
};

/** Gated societies the captain can choose to work in (sample data). */
export type Society = { name: string; area: string; km: number };
export const societies: Society[] = [
  { name: "My Home Avatar", area: "Narsingi", km: 0.6 },
  { name: "Lanco Hills", area: "Manikonda", km: 2.1 },
  { name: "Aparna Sarovar Zenith", area: "Nallagandla", km: 3.2 },
  { name: "Prestige High Fields", area: "Gachibowli", km: 4.5 },
  { name: "SMR Vinay Iconia", area: "Kondapur", km: 6.8 },
];
export const currentSociety = societies[0];
export const places = ["Narsingi", "Manikonda", "Nallagandla", "Gachibowli", "Kondapur", "Kokapet", "Madhapur", "Financial District"];

/** Which jobs the captain wants to be offered. */
export type WorkMode = "all" | "radius" | "societies" | "place";

export type KycStep = "aadhaar" | "photo" | "bank" | "training" | "quiz";
export const KycSteps: KycStep[] = ["aadhaar", "photo", "bank", "training", "quiz"];
export type StepState = "todo" | "done" | "problem";

export const sampleQueue = (): Job[] => [
  job({ id: "j1", plate: "TS 09 EA 4521", type: "Hatchback", isBike: false, pay: 116, tower: "Tower 3", floor: "B2", slot: "41", window: "8–10", time: "8:30", status: "now" }),
  job({ id: "j2", plate: "TS 09 HB 0731", type: "Scooter", isBike: true, pay: 54, tower: "Tower 3", floor: "B1", slot: "", window: "8–10", time: "9:00", status: "next", wash: "wetOutside" }),
  job({ id: "j3", plate: "TS 08 GK 2210", type: "Sedan", isBike: false, pay: 140, tower: "Tower 1", floor: "B1", slot: "", window: "6–8", time: "7:40", status: "done", society: "Lanco Hills", area: "Manikonda" }),
  job({ id: "j4", plate: "AP 28 BQ 9911", type: "Scooter", isBike: true, pay: 54, tower: "Tower 1", floor: "Open", slot: "", window: "6–8", time: "7:05", status: "done", society: "Lanco Hills", wash: "dryDusting", area: "Manikonda" }),
];

/** Other jobs that can ring while an alert is already open (demo). */
export const offerPool: Job[] = [
  job({ id: "o1", plate: "TS 08 HK 1207", type: "Hatchback", isBike: false, pay: 116, tower: "Tower 3", floor: "B2", slot: "27", window: "8–10", time: "8:40", owner: "Ravi" }),
  job({ id: "o2", plate: "TS 07 FK 3390", type: "SUV", isBike: false, pay: 140, tower: "Tower 2", floor: "Open", slot: "12", window: "8–10", time: "8:45", distance: "2.1 km", owner: "Kiran", society: "Lanco Hills", wash: "wetOutsideDryInside", area: "Manikonda" }),
  job({ id: "o3", plate: "TS 10 MB 6614", type: "Scooter", isBike: true, pay: 54, tower: "Tower 5", floor: "B1", slot: "", window: "8–10", time: "9:10", distance: "3.2 km", owner: "Sneha", society: "Aparna Sarovar Zenith", wash: "dryDusting", area: "Nallagandla" }),
];

// MARK: Routes

export type HelpTopic = "money" | "job" | "rating" | "app";
export const HelpTopics: HelpTopic[] = ["money", "job", "rating", "app"];

/** One route per captain screen ID (W01–W57). */
export type Route =
  | { n: "welcome" } | { n: "signUp"; login: boolean } | { n: "otp"; login: boolean } | { n: "steps"; problem: boolean }
  | { n: "aadhaar"; unclear: boolean } | { n: "selfie" } | { n: "bank" } | { n: "training" } | { n: "video"; index: number } | { n: "quiz" }
  | { n: "quizResult"; passed: boolean } | { n: "rules" } | { n: "underReview" } | { n: "live" } | { n: "jobAlert"; batched: boolean }
  | { n: "jobMissed" } | { n: "goToVehicle" } | { n: "gateProblem" } | { n: "cantFind" } | { n: "ownerCancelled" } | { n: "faceCheck" }
  | { n: "beforePhotos" } | { n: "camera"; after: boolean; side: number } | { n: "photoDark" } | { n: "washing" } | { n: "afterPhotos" }
  | { n: "aiCheck" } | { n: "uploading" } | { n: "jobDone"; late: boolean } | { n: "payoutDetail" } | { n: "payoutHeld" } | { n: "level" }
  | { n: "probationExtended" } | { n: "refresher" } | { n: "blocked" } | { n: "help" } | { n: "notifications" } | { n: "notificationSettings" }
  | { n: "changePhone" } | { n: "editUPI" } | { n: "noShowCancelled" } | { n: "workArea" } | { n: "ownerNote" } | { n: "helpFlow"; topic: HelpTopic }
  | { n: "gallery" };

export class WRouter extends Nav<Route> {
  /** Index into the gallery while stepping through screens (demo only). */
  tour: number | null = null;
  tourLang: Lang | null = null;
  home() { this.path = []; this.tab = 0; }
  /** Replace the top screen (dropLast + append). */
  swapTop(r: Route) { this.replace([...this.path.slice(0, -1).map((e) => e.route), r]); }
}

// MARK: Notifications

export type WNotifCategory = "jobs" | "money" | "level" | "account";
export const WNotifCategories: WNotifCategory[] = ["jobs", "money", "level", "account"];

export type WNotifKind =
  | "newJob" | "jobTaken" | "ownerCancelled" | "gatePassReady" | "runningLate" | "slotEnded" | "noShowPenalty"
  | "washApproved" | "problemReported" | "payoutSent" | "upiChanged" | "levelUp" | "probation" | "blocked" | "phoneChanged";

export const WKind = {
  category: (k: WNotifKind): WNotifCategory =>
    ["washApproved", "problemReported", "payoutSent", "upiChanged"].includes(k) ? "money" : k === "levelUp" || k === "probation" ? "level" : k === "blocked" || k === "phoneChanged" ? "account" : "jobs",
  icon: (k: WNotifKind): IconName => ({
    newJob: "bell", jobTaken: "clock", ownerCancelled: "close", gatePassReady: "door", runningLate: "clock", slotEnded: "warning", noShowPenalty: "ban",
    washApproved: "check", problemReported: "lock", payoutSent: "rupee", upiChanged: "rupee", levelUp: "star", probation: "calendar", blocked: "ban", phoneChanged: "lock",
  } as const)[k],
  tone: (k: WNotifKind): Tone => {
    if (["slotEnded", "noShowPenalty", "blocked", "phoneChanged"].includes(k)) return "error";
    if (["runningLate", "problemReported", "probation", "jobTaken"].includes(k)) return "wait";
    if (["washApproved", "payoutSent", "levelUp", "gatePassReady"].includes(k)) return "ok";
    return "info";
  },
};

export type WNotif = { id: string; kind: WNotifKind; date: Date; jobId: string | null; plate: string; amount: number; read: boolean };
export type WNotifPrefs = { soundOn: boolean; mutedUntil: Date | null; quietHours: boolean; off: WNotifCategory[] };
export const wIsMuted = (p: WNotifPrefs) => !!p.mutedUntil && p.mutedUntil.getTime() > Date.now();
const inQuietHours = () => { const h = new Date().getHours(); return h >= 22 || h < 7; };

// MARK: Store

export class CaptainStore {
  lang: Lang = "en";
  phone = "9876543210";
  name = "Raju Yadav";
  upi = "raju.yadav@ybl";
  rating = 4.8;
  /** KYC done and approved: can accept jobs. */
  signedUp = false;
  /** Past the welcome page: browsing the app as a guest. */
  exploring = false;
  /** Name and number verified with a code (light sign-up). */
  registered = false;
  /** Go online right after the light sign-up finishes. */
  onlineAfterSignUp = false;
  /** KYC was started by tapping Accept on a job. */
  kycFromJob = false;
  /** The "save your spot" nudge was shown once. */
  nudgeShown = false;

  steps: Partial<Record<KycStep, StepState>> = {};
  videosWatched = 1;

  online = false;
  levelDay = 2;
  jobsToday = 6;
  jobLimit = 8;
  earnedToday = 1040;
  approvedToday = 820;
  waitingToday = 220;

  // Demo switches (Screens gallery)
  lowSignal = false;
  batchedAlert = false;
  lateWash = false;
  darkPhoto = false;
  aiFlag = true;

  profilePhoto: string | null = null;
  pendingPhone = "";
  pendingUPI = "";

  notifications: WNotif[] = [];
  notificationsOn = true;
  notifPrefs: WNotifPrefs = { soundOn: true, mutedUntil: null, quietHours: false, off: [] };
  systemPermission: Permission = "unknown";
  liveBanner: WNotif | null = null;
  toast: string | null = null;

  // No-show (accepted but didn't reach / update the job)
  noShowDemo = false;
  jobLate = false;
  slotEnded = false;
  noShowCancelled = false;
  noShowPlate = "";
  noShowTask: Task | null = null;

  queue: Job[] = sampleQueue();
  /** Photos taken for the current job (before / after), 4 sides each. */
  beforeDone: number[] = [];
  afterDone: number[] = [];

  // Where I work
  workMode: WorkMode = "all";
  radiusKm = 3;
  chosenSocieties: string[] = [];
  workPlace = "Narsingi";
  /** How many more jobs ring while the alert is open (demo; 0 = single job). */
  extraOffers = 2;
  /** The owner's voice note was played for the current job. */
  ownerNoteHeard = false;
  acceptedToday = 0;

  get firstName() { return this.name.split(" ").filter(Boolean)[0] ?? "Raju"; }
  get canGoOnline() { return this.registered; }
  get canAccept() { return this.signedUp; }
  get current(): Job { return this.queue.find((j) => j.status === "now") ?? sampleQueue()[0]; }
  get upNext() { return this.queue.filter((j) => j.status !== "done"); }
  get nextStep(): KycStep | null { return KycSteps.find((s) => this.steps[s] !== "done") ?? null; }
  get stepsDone() { return Object.values(this.steps).filter((s) => s === "done").length; }
  /** KYC as the captain sees it: Aadhaar, photo, bank, onboarding (videos + quiz). */
  get kycStagesDone() {
    return [this.steps.aadhaar, this.steps.photo, this.steps.bank].filter((s) => s === "done").length
      + (this.steps.training === "done" && this.steps.quiz === "done" ? 1 : 0);
  }
  get langName() { return this.lang === "hi" ? "हिन्दी" : this.lang === "te" ? "తెలుగు" : "English"; }

  /** Inline translation: English, Hindi, Telugu. */
  t(en: string, hi: string, te: string) { return this.lang === "hi" ? hi : this.lang === "te" ? te : en; }

  /** Light sign-up finished (name + number + code). */
  finishRegistration() {
    this.registered = true;
    this.exploring = true;
    if (!this.notifications.length) this.seedNotifications();
    if (this.onlineAfterSignUp) this.online = true;
    this.onlineAfterSignUp = false;
    this.toast = this.t(`Welcome, ${this.firstName}!`, `स्वागत है, ${this.firstName}!`, `స్వాగతం, ${this.firstName}!`);
  }

  /** KYC approved: jobs can be accepted now. */
  finishKyc() {
    this.signedUp = true; this.registered = true; this.exploring = true; this.kycFromJob = false;
    this.levelDay = 1; this.jobsToday = 0; this.jobLimit = 2; this.earnedToday = 0; this.approvedToday = 0; this.waitingToday = 0;
  }

  logOut() { this.signedUp = false; this.registered = false; this.exploring = false; this.online = false; this.notifications = []; }

  wantsJob(j: Job) {
    switch (this.workMode) {
      case "all": return true;
      case "radius": return JobFmt.km(j) <= this.radiusKm;
      case "societies": return !this.chosenSocieties.length || this.chosenSocieties.includes(j.society);
      case "place": return j.area === this.workPlace;
    }
  }

  get workSummary() {
    switch (this.workMode) {
      case "all": return this.t("All jobs", "सभी काम", "అన్ని పనులు");
      case "radius": return this.t(`Within ${this.radiusKm} km`, `${this.radiusKm} km के अंदर`, `${this.radiusKm} కి.మీ లోపు`);
      case "societies": {
        const list = societies.map((s) => s.name).filter((n) => this.chosenSocieties.includes(n));
        if (!list.length) return this.t("All jobs", "सभी काम", "అన్ని పనులు");
        return list.length > 1 ? `${list[0]} +${list.length - 1}` : list[0];
      }
      case "place": return this.workPlace;
    }
  }

  /** Accept a job from the alert stack: it joins today's jobs and shows on Home. */
  acceptOffer(j: Job) {
    if (this.queue.some((x) => x.id === j.id)) return;
    const nj: Job = { ...j, status: this.queue.some((x) => x.status === "now") ? "next" : "now" };
    let insertAt = 0;
    this.queue.forEach((x, i) => { if (x.status !== "done") insertAt = i + 1; });
    this.queue = [...this.queue.slice(0, insertAt), nj, ...this.queue.slice(insertAt)];
    this.acceptedToday += 1;
  }

  complete(s: KycStep) { this.steps[s] = "done"; }
  resetJob() { this.beforeDone = []; this.afterDone = []; }

  /** The captain picked a different job to do first: it becomes the current one. */
  startJob(id: string) {
    const j = this.queue.find((x) => x.id === id);
    if (!j || j.status !== "next") return;
    const n = this.queue.find((x) => x.status === "now");
    if (n) n.status = "next";
    j.status = "now";
  }

  finishJob() {
    this.ownerNoteHeard = false;
    const j = this.queue.find((x) => x.status === "now");
    if (j) {
      j.status = "done";
      this.jobsToday += 1;
      this.earnedToday += j.pay;
      this.waitingToday += j.pay;
      const n = this.queue.find((x) => x.status === "next");
      if (n) n.status = "now";
    }
    this.resetJob();
  }

  /** BACKEND: send a code to the new number / verify it. */
  async requestPhoneChange(p: string) { await sleep(700); this.pendingPhone = p; }
  async confirmPhoneChange(code: string) {
    await sleep(600);
    if (code !== "123456") return false;
    this.phone = this.pendingPhone;
    this.notify("phoneChanged", { deliver: false });
    return true;
  }

  /** BACKEND: payout UPI changes need a code to the registered phone first. */
  async requestUPIChange(u: string) { await sleep(700); this.pendingUPI = u.toLowerCase(); }
  async confirmUPIChange(code: string) {
    await sleep(600);
    if (code !== "123456") return false;
    this.upi = this.pendingUPI;
    this.notify("upiChanged", { deliver: false });
    return true;
  }

  resetDemo() {
    this.captainArrived();
    this.extraOffers = 2; this.acceptedToday = 0; this.workMode = "all"; this.chosenSocieties = []; this.kycFromJob = false;
    this.onlineAfterSignUp = false; this.noShowCancelled = false; this.noShowDemo = false; this.notificationsOn = true;
    this.liveBanner = null; this.toast = null; this.lowSignal = false; this.batchedAlert = false; this.lateWash = false;
    this.darkPhoto = false; this.aiFlag = true; this.queue = sampleQueue(); this.resetJob(); this.online = false;
    this.jobsToday = 6; this.jobLimit = 8; this.earnedToday = 1040; this.waitingToday = 220; this.levelDay = 2;
  }

  // MARK: Notification copy (English · Hindi · Telugu)

  title(n: WNotif) {
    const rs = Fmt.rupees(n.amount);
    switch (n.kind) {
      case "newJob": return this.t(`New job: ${rs}`, `नया काम: ${rs}`, `కొత్త పని: ${rs}`);
      case "jobTaken": return this.t("Job went to someone else", "काम किसी और को मिल गया", "పని వేరొకరికి వెళ్ళింది");
      case "ownerCancelled": return this.t("Owner cancelled the job", "मालिक ने काम रद्द किया", "యజమాని పని రద్దు చేశారు");
      case "gatePassReady": return this.t("Gate pass is ready", "गेट पास तैयार है", "గేట్ పాస్ సిద్ధం");
      case "runningLate": return this.t(`You’re late for ${n.plate}`, `आप ${n.plate} के लिए लेट हैं`, `${n.plate} కి మీరు ఆలస్యం`);
      case "slotEnded": return this.t("Slot is over. Update the job", "समय खत्म। काम अपडेट करें", "సమయం ముగిసింది. పని అప్‌డేట్ చేయండి");
      case "noShowPenalty": return this.t("Job cancelled: penalty applied", "काम रद्द: जुर्माना लगा", "పని రద్దు: జరిమానా విధించబడింది");
      case "washApproved": return this.t("Owner approved your wash", "मालिक ने धुलाई मंज़ूर की", "యజమాని మీ వాష్ ఆమోదించారు");
      case "problemReported": return this.t(`Money on hold: ${rs}`, `पैसे रोके गए: ${rs}`, `డబ్బు నిలిపివేయబడింది: ${rs}`);
      case "payoutSent": return this.t(`${rs} sent to your UPI`, `${rs} आपके UPI पर भेजे गए`, `${rs} మీ UPI కి పంపబడింది`);
      case "upiChanged": return this.t("Payout UPI changed", "पेमेंट UPI बदला गया", "చెల్లింపు UPI మార్చబడింది");
      case "levelUp": return this.t("Day 2 done. Now 4 jobs a day", "दिन 2 पूरा। अब रोज़ 4 काम", "రోజు 2 పూర్తి. ఇప్పుడు రోజుకు 4 పనులు");
      case "probation": return this.t("1 more day at 4 jobs", "4 कामों पर 1 दिन और", "4 పనులతో ఇంకో రోజు");
      case "blocked": return this.t("You can’t take jobs now", "आप अभी काम नहीं ले सकते", "మీరు ఇప్పుడు పనులు తీసుకోలేరు");
      case "phoneChanged": return this.t("Your phone number was changed", "आपका फ़ोन नंबर बदला गया", "మీ ఫోన్ నంబర్ మార్చబడింది");
    }
  }

  body(n: WNotif) {
    const rs = Fmt.rupees(n.amount);
    switch (n.kind) {
      case "newJob": return `${n.plate} · ` + this.t("Tap to see", "देखने के लिए दबाएं", "చూడటానికి నొక్కండి");
      case "jobTaken": return this.t("Keep the app open. Next job comes soon.", "ऐप खुला रखें। अगला काम जल्दी आएगा।", "యాప్ తెరిచి ఉంచండి. తదుపరి పని త్వరలో వస్తుంది.");
      case "ownerCancelled": return this.t("You get ₹[CANCELLATION FEE] for the trip.", "सफ़र के ₹[CANCELLATION FEE] मिलेंगे।", "ప్రయాణానికి ₹[CANCELLATION FEE] వస్తుంది.");
      case "gatePassReady": return this.t(`Show it at the gate for ${n.plate}.`, `${n.plate} के लिए गेट पर दिखाएं।`, `${n.plate} కోసం గేట్ వద్ద చూపించండి.`);
      case "runningLate": return this.t("Reach now. −₹1 for every late minute.", "अभी पहुँचें। हर लेट मिनट पर −₹1।", "ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1.");
      case "slotEnded": return this.t("Tap I’m at the vehicle, or tell us in Help. Otherwise the job is cancelled.",
        "‘मैं गाड़ी के पास हूँ’ दबाएं या मदद में बताएं। नहीं तो काम रद्द होगा।",
        "‘నేను వాహనం దగ్గర ఉన్నాను’ నొక్కండి లేదా సహాయంలో చెప్పండి. లేదంటే పని రద్దవుతుంది.");
      case "noShowPenalty": return this.t(`You didn’t reach ${n.plate} in time. Owner got a full refund.`,
        `आप ${n.plate} तक समय पर नहीं पहुँचे। मालिक को पूरे पैसे वापस मिले।`,
        `మీరు ${n.plate} కి సమయానికి చేరుకోలేదు. యజమానికి పూర్తి డబ్బు తిరిగి వచ్చింది.`);
      case "washApproved": return this.t(`${rs} comes tonight before 12.`, `${rs} आज रात 12 से पहले आएंगे।`, `${rs} ఈ రాత్రి 12 లోపు వస్తుంది.`);
      case "problemReported": return this.t("Owner reported a problem. We decide in 24 hours.", "मालिक ने समस्या बताई। 24 घंटे में फ़ैसला होगा।", "యజమాని సమస్య చెప్పారు. 24 గంటల్లో నిర్ణయం.");
      case "payoutSent": return this.t("For 9 jobs on Fri, 9 Oct.", "शुक्र, 9 अक्टू के 9 कामों के लिए।", "శుక్ర, 9 అక్టో 9 పనులకు.");
      case "upiChanged": return this.t(`Money now goes to ${this.upi}.`, `अब पैसे ${this.upi} पर जाएंगे।`, `ఇకపై డబ్బు ${this.upi} కి వెళ్తుంది.`);
      case "levelUp": return this.t("Keep ratings at 4★ or more.", "रेटिंग 4★ या ज़्यादा रखें।", "రేటింగ్ 4★ లేదా ఎక్కువ ఉంచండి.");
      case "probation": return this.t("An owner gave 3★. Watch the 30-sec tip.", "एक मालिक ने 3★ दिए। 30 सेकंड की टिप देखें।", "ఒక యజమాని 3★ ఇచ్చారు. 30 సెకన్ల టిప్ చూడండి.");
      case "blocked": return this.t("Too many low ratings. You can ask us to check.", "बहुत सी कम रेटिंग। हमसे जाँच करवा सकते हैं।", "చాలా తక్కువ రేటింగ్‌లు. మమ్మల్ని తనిఖీ చేయమని అడగవచ్చు.");
      case "phoneChanged": return this.t("If this wasn’t you, open Help now.", "अगर यह आपने नहीं किया, तो अभी मदद खोलें।", "ఇది మీరు కాకపోతే, ఇప్పుడే సహాయం తెరవండి.");
    }
  }

  categoryTitle(c: WNotifCategory) {
    return { jobs: this.t("Jobs", "काम", "పనులు"), money: this.t("Money", "पैसे", "డబ్బు"), level: this.t("Level", "लेवल", "స్థాయి"), account: this.t("Account", "अकाउंट", "ఖాతా") }[c];
  }

  categoryDetail(c: WNotifCategory) {
    return {
      jobs: this.t("New jobs, gate pass, cancellations", "नए काम, गेट पास, रद्द काम", "కొత్త పనులు, గేట్ పాస్, రద్దులు"),
      money: this.t("Approvals, payouts, money on hold", "मंज़ूरी, पेमेंट, रोके गए पैसे", "ఆమోదాలు, చెల్లింపులు, నిలిపివేసిన డబ్బు"),
      level: this.t("Your level and job limit", "आपका लेवल और काम की सीमा", "మీ స్థాయి మరియు పనుల పరిమితి"),
      account: this.t("Blocks and number changes. Always on.", "ब्लॉक और नंबर बदलना। हमेशा चालू।", "బ్లాక్ మరియు నంబర్ మార్పులు. ఎప్పుడూ ఆన్."),
    }[c];
  }

  // MARK: Notification actions

  get unreadCount() { return this.notifications.filter((n) => !n.read).length; }

  /** Records a notification and, if settings allow, alerts the captain. New-job alerts always ring while Online. */
  notify(kind: WNotifKind, o: { job?: Job; amount?: number; deliver?: boolean } = {}) {
    const jobId = o.job?.id ?? null;
    const last = this.notifications.find((n) => n.kind === kind && n.jobId === jobId);
    if (last && Date.now() - last.date.getTime() < 60000) return;
    const n: WNotif = { id: newId("w"), kind, date: new Date(), jobId, plate: o.job?.plate ?? "", amount: o.amount ?? o.job?.pay ?? 0, read: false };
    this.notifications = [n, ...this.notifications];
    if (!(o.deliver ?? true)) return;
    const ringsAnyway = kind === "newJob" && this.online;
    if (!this.notificationsOn && !ringsAnyway) return;
    if (!ringsAnyway && WKind.category(kind) !== "account" && this.notifPrefs.off.includes(WKind.category(kind))) return;
    if (!ringsAnyway && wIsMuted(this.notifPrefs)) return;
    const silent = !ringsAnyway && (!this.notifPrefs.soundOn || (this.notifPrefs.quietHours && inQuietHours()));
    if (appIsActive()) {
      this.liveBanner = n;
      if (!silent) ding();
      buzz([30, 40, 30]);
    } else if (this.systemPermission !== "denied") {
      systemNotify(this.title(n), this.body(n), silent);
    }
  }

  markRead(id: string) { const n = this.notifications.find((x) => x.id === id); if (n) n.read = true; }
  markUnread(id: string) { const n = this.notifications.find((x) => x.id === id); if (n) n.read = false; }
  markAllRead() { this.notifications.forEach((n) => { n.read = true; }); }
  deleteNotification(id: string) { this.notifications = this.notifications.filter((n) => n.id !== id); }
  clearNotifications() { this.notifications = []; }

  setNotifications(on: boolean) {
    this.notificationsOn = on;
    if (on) requestPermission().then((p) => { this.systemPermission = p; });
  }
  refreshSystemPermission() { this.systemPermission = systemPermission(); }
  mute(seconds: number | null) { this.notifPrefs.mutedUntil = seconds == null ? null : new Date(Date.now() + seconds * 1000); }
  muteUntilMorning() { const d = addDays(startOfDay(new Date()), 1); d.setHours(8); this.notifPrefs.mutedUntil = d; }

  seedNotifications() {
    const now = Date.now();
    const h = (x: number) => new Date(now - x * 3600000);
    const j = sampleQueue()[0];
    const mk = (id: string, kind: WNotifKind, date: Date, x: Partial<WNotif> = {}): WNotif => ({ id, kind, date, jobId: null, plate: "", amount: 0, read: false, ...x });
    this.notifications = [
      mk("w_gate", "gatePassReady", h(0.2), { jobId: j.id, plate: j.plate }),
      mk("w_approved", "washApproved", h(1.5), { jobId: "j3", plate: "TS 08 GK 2210", amount: 140 }),
      mk("w_held", "problemReported", h(3), { jobId: "j_old", plate: "TS 09 EA 4521", amount: 116 }),
      mk("w_oldjob", "newJob", h(5), { jobId: "j_gone", plate: "TS 07 CC 1188", amount: 116, read: true }),
      mk("w_payout", "payoutSent", h(17), { amount: 1262 }),
      mk("w_level", "levelUp", h(20), { read: true }),
      mk("w_phone", "phoneChanged", h(60), { read: true }),
    ];
  }

  // MARK: No-show (captain accepted but doesn't reach / update the job)

  /** Demo: late → slot over, update the job → job cancelled + penalty. Stops if the captain taps "I'm at the vehicle". */
  startNoShowDemo(onCancelled: () => void) {
    if (this.noShowTask || this.noShowCancelled) return;
    const j = this.current;
    this.noShowTask = run(async (task) => {
      await sleep(5000);
      if (task.cancelled) return;
      this.jobLate = true;
      this.notify("runningLate", { job: j });
      await sleep(8000);
      if (task.cancelled) return;
      this.slotEnded = true;
      this.notify("slotEnded", { job: j });
      await sleep(9000);
      if (task.cancelled) return;
      this.noShowCancelled = true;
      this.noShowPlate = j.plate;
      this.queue = this.queue.filter((x) => x.id !== j.id);
      const n = this.queue.find((x) => x.status === "next");
      if (n) n.status = "now";
      this.notify("noShowPenalty", { job: j });
      this.noShowTask = null;
      onCancelled();
    });
  }

  /** The captain reached the car in time: no penalty. */
  captainArrived() {
    this.noShowTask?.cancel();
    this.noShowTask = null;
    this.jobLate = false;
    this.slotEnded = false;
  }
}

/** Where a tapped notification goes, with the "moved on" / "gone" edge cases. Returns an info message, if any. */
export function openWNotif(n: WNotif, store: CaptainStore, router: WRouter): string | null {
  store.markRead(n.id);
  store.liveBanner = null;
  const isCurrent = n.jobId != null && store.queue.some((j) => j.id === n.jobId && j.status === "now");
  switch (n.kind) {
    case "newJob":
      if (!store.online || !store.queue.some((j) => j.id === n.jobId && j.status !== "done")) {
        return store.t("This job is no longer available.", "यह काम अब उपलब्ध नहीं है।", "ఈ పని ఇప్పుడు అందుబాటులో లేదు.");
      }
      router.push({ n: "jobAlert", batched: false });
      break;
    case "jobTaken": return null;
    case "ownerCancelled": router.push({ n: "ownerCancelled" }); break;
    case "gatePassReady": case "runningLate": case "slotEnded":
      if (!isCurrent || (store.noShowCancelled && n.kind !== "gatePassReady")) return store.t("This job has moved on.", "यह काम आगे बढ़ चुका है।", "ఈ పని ముందుకు వెళ్ళింది.");
      router.push({ n: "goToVehicle" });
      break;
    case "noShowPenalty": router.push({ n: "noShowCancelled" }); break;
    case "washApproved": case "payoutSent": router.push({ n: "payoutDetail" }); break;
    case "problemReported": router.push({ n: "payoutHeld" }); break;
    case "levelUp": router.push({ n: "level" }); break;
    case "probation": router.push({ n: "probationExtended" }); break;
    case "blocked": router.push({ n: "blocked" }); break;
    case "phoneChanged": case "upiChanged": router.home(); router.tab = 3; break;
  }
  return null;
}

export function createCaptainApp() {
  const hub = new Hub();
  const store = reactive(new CaptainStore(), hub);
  const router = reactive(new WRouter(), hub);
  return { hub, store, router };
}

