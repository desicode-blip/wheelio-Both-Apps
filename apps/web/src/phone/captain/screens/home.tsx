"use client";

import { useContext, useEffect, useRef, useState } from "react";
import { Brand, C, S, toneBanner, toneBg, type Tone } from "../../ds/tokens";
import {
  AppBar, Badge, Banner, BottomNav, Button, FullState, HStack, IconBox, Link, PhotoPlaceholder, Plate, Screen, Sheet, StateCircle, Tap, T,
  TD, Toggle, VStack, card,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { buzz, ding } from "../../lib/device";
import { Fmt, Support } from "../../lib/fmt";
import { IsTop } from "../../shell/StackView";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import { JobFmt, offerPool, type Job, type JobStatus } from "../store";
import { BookingChip, VehiclePhotoView, VehiclePhotosViewer, WNotificationBell, WorkAreaChip, WProfilePhoto } from "./parts";
import { GuestNotice, SignUpNudge } from "./welcome";
import { MeTab, MoneyTab } from "./money";

// MARK: Tabs (Home · Jobs · Money · Me)

export function CaptainTabs() {
  const { store, router } = useCaptain();
  const [showNudge, setShowNudge] = useState(false);
  useEffect(() => {
    // After a guest has looked around for a while, offer the light sign-up once.
    if (!store.exploring || store.registered || store.nudgeShown) return;
    const t = setTimeout(() => {
      if (store.registered || store.nudgeShown || router.path.length) return;
      store.nudgeShown = true;
      setShowNudge(true);
    }, 45000);
    return () => clearTimeout(t);
  }, [store, router, store.registered]);
  return (
    <div className="wh-fill" style={{ background: C.canvas }}>
      <div style={{ flex: 1, minHeight: 0, position: "relative" }}>
        {router.tab === 1 ? <JobsTab /> : router.tab === 2 ? <MoneyTab /> : router.tab === 3 ? <MeTab /> : <CaptainHome />}
      </div>
      <BottomNav selection={router.tab} onSelect={(t) => { router.tab = t; }} items={[
        { id: 0, title: store.t("Home", "होम", "హోమ్"), icon: "home" },
        { id: 1, title: store.t("Jobs", "काम", "పనులు"), icon: "list" },
        { id: 2, title: store.t("Money", "पैसे", "డబ్బు"), icon: "rupee" },
        { id: 3, title: store.t("Me", "मैं", "నేను"), icon: "user" },
      ]} />
      <Sheet open={showNudge} onClose={() => setShowNudge(false)} height={400} gutter={S.gutterCaptain}>
        <SignUpNudge onClose={() => setShowNudge(false)} />
      </Sheet>
    </div>
  );
}

// MARK: W20 offline · W21 online · W24 daily limit · W50 low signal

export function CaptainHome() {
  const { store, router } = useCaptain();
  const isTop = useContext(IsTop);
  const limitReached = store.jobsToday >= store.jobLimit;
  const hasPlan = store.signedUp && store.queue.length > 0;

  // Demo: a job rings a few seconds after going online.
  useEffect(() => {
    if (!store.online || !isTop || router.tab !== 0 || limitReached) return;
    const t = setTimeout(() => {
      if (!store.online || router.path.length || router.tab !== 0) return;
      store.notify("newJob", { job: offerPool[0], deliver: false });
      router.push({ n: "jobAlert", batched: store.batchedAlert });
    }, 4000);
    return () => clearTimeout(t);
  }, [store, router, store.online, isTop, router.tab, limitReached]);

  /** Guests sign up (name, number, code) before going online. */
  const setOnline = (on: boolean) => {
    if (on && !store.registered) { store.onlineAfterSignUp = true; router.push({ n: "signUp", login: false }); }
    else store.online = on;
  };

  const alertBox = (icon: IconName, tone: Tone, title: string, text: string) => (
    <HStack align="start" gap={12} style={{ padding: 16, borderRadius: 14, background: toneBg[tone] }}>
      <Icon name={icon} size={18} color={toneBanner[tone]} />
      <TD k="caption" c={toneBanner[tone]} s={14.5}><b>{title} </b>{text}</TD>
    </HStack>
  );

  const miniStat = (icon: IconName, big: string, small: string) => (
    <HStack gap={8} style={{ flex: 1, justifyContent: "center" }}>
      <Icon name={icon} size={16} color={C.primaryStrong} />
      <VStack>
        <T k="title" s={17} mono lines={1}>{big}</T>
        <T k="small" c={C.secondary}>{small}</T>
      </VStack>
    </HStack>
  );

  const stat = (icon: IconName, tone: Tone, big: string, small: string) => (
    <VStack gap={6} style={{ flex: 1, padding: 14, borderRadius: 14, background: toneBg[tone] }}>
      <Icon name={icon} size={22} color={tone === "ok" ? C.heading : C.primaryStrong} />
      <T k="section" w={600}>{big}</T>
      <T k="caption" c={C.heading}>{small}</T>
    </VStack>
  );

  return (
    <div className="wh-fill" style={{ background: C.canvas }}>
      {/* Header stays put while the page scrolls. */}
      <HStack gap={10} style={{ padding: `calc(var(--sat) + 10px) ${S.gutterCaptain}px 10px`, background: C.canvas, borderBottom: `1px solid ${C.divider}` }}>
        {store.registered ? (
          <>
            <WProfilePhoto size={40} badge={false} />
            <T k="title" s={18} lines={1} style={{ minWidth: 0 }}>{store.firstName}</T>
          </>
        ) : (
          // Guest: tap to sign up (name, number, code), then back to Home.
          <Tap onClick={() => router.push({ n: "signUp", login: false })} label={store.t("Guest. Tap to sign up", "मेहमान। साइन अप के लिए दबाएं", "అతిథి. సైన్ అప్‌కి నొక్కండి")}
            style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span style={{ width: 40, height: 40, borderRadius: 20, background: C.primaryTint, display: "grid", placeItems: "center" }}><Icon name="user" size={19} color={C.primaryStrong} /></span>
            <T k="title" s={18}>{store.t("Guest", "मेहमान", "అతిథి")}</T>
          </Tap>
        )}
        <div style={{ flex: 1 }} />
        <OnlineSwitch online={store.online} label={store.online ? store.t("Online", "ऑनलाइन", "ఆన్‌లైన్") : store.t("Offline", "ऑफ़लाइन", "ఆఫ్‌లైన్")} set={setOnline} />
        {store.registered && <WNotificationBell />}
      </HStack>
      <div className="wh-scroll" style={{ flex: 1 }}>
        <VStack gap={14} style={{ padding: `12px ${S.gutterCaptain}px 16px` }}>
          <WorkAreaChip />
          {store.lowSignal && (
            <>
              {alertBox("battery", "wait", store.t("Battery 12%.", "बैटरी 12%।", "బ్యాటరీ 12%."), store.t("Plug in soon. Jobs stop at 5%.", "जल्दी चार्ज करें। 5% पर काम रुक जाएगा।", "త్వరగా ఛార్జ్ చేయండి. 5% వద్ద పనులు ఆగుతాయి."))}
              {alertBox("wifiOff", "error", store.t("No internet.", "इंटरनेट नहीं।", "ఇంటర్నెట్ లేదు."), store.t("2 photos saved on phone. They upload when signal comes back.", "2 फ़ोटो फ़ोन में सेव हैं। सिग्नल आने पर अपलोड होंगी।", "2 ఫోటోలు ఫోన్‌లో ఉన్నాయి. సిగ్నల్ వచ్చాక అప్‌లోడ్ అవుతాయి."))}
            </>
          )}
          {store.signedUp ? (
            store.queue.length === 0 ? (
              <VStack gap={10} style={card(18)}>
                <T k="body">{store.t("Today", "आज", "ఈరోజు")}</T>
                <T k="hugeMoney" mono>{Fmt.rupees(store.online || store.jobsToday > 0 ? store.earnedToday : 0)}</T>
                <HStack gap={10}>
                  {stat("check", "ok", `${store.jobsToday} ${store.t("of", "/", "/")} ${store.jobLimit}`, store.t("Jobs done", "काम पूरे", "పూర్తైన పనులు"))}
                  {stat("star", "info", store.rating.toFixed(1), store.t("Rating", "रेटिंग", "రేటింగ్"))}
                </HStack>
              </VStack>
            ) : (
              <>
                {/* Once jobs come in, money/jobs/rating shrink to one line and the day's plan takes the space. */}
                <Tap onClick={() => { router.tab = 2; }} style={{ display: "flex", alignItems: "center", padding: "12px 0", borderRadius: 16, background: "#fff", boxShadow: `inset 0 0 0 1px ${C.border}` }}>
                  {miniStat("rupee", Fmt.rupees(store.earnedToday), store.t("Today", "आज", "ఈరోజు"))}
                  <span style={{ width: 1, height: 30, background: C.divider }} />
                  {miniStat("check", `${store.jobsToday}/${store.jobLimit}`, store.t("Jobs", "काम", "పనులు"))}
                  <span style={{ width: 1, height: 30, background: C.divider }} />
                  {miniStat("star", store.rating.toFixed(1), store.t("Rating", "रेटिंग", "రేటింగ్"))}
                </Tap>
                <DayPlan />
              </>
            )
          ) : (
            <>
              <WelcomeBanner />
              {store.registered && (
                <Tap onClick={() => { store.kycFromJob = false; router.push({ n: "steps", problem: false }); }} style={{ ...card(16), display: "flex", alignItems: "center", gap: 14, textAlign: "left" }}>
                  <IconBox icon="idCard" size={48} tone="wait" radius={12} />
                  <VStack gap={3} style={{ flex: 1 }}>
                    <TD k="title" s={17}>{store.t("Finish KYC to take jobs", "काम लेने के लिए KYC पूरा करें", "పనులకు KYC పూర్తి చేయండి")}</TD>
                    <TD k="caption">{`${store.kycStagesDone}/4 · ` + store.t("Aadhaar, photo, bank, training", "आधार, फ़ोटो, बैंक, ट्रेनिंग", "ఆధార్, ఫోటో, బ్యాంక్, శిక్షణ")}</TD>
                  </VStack>
                  <Icon name="chevron" size={15} color={C.secondary} />
                </Tap>
              )}
            </>
          )}
          {limitReached && store.online && store.signedUp ? (
            <HStack align="start" gap={12} style={{ padding: 16, borderRadius: 14, background: C.primaryTint }}>
              <Icon name="calendar" size={18} />
              <TD k="caption" c={C.inverse} s={14.5}>
                <b>{store.t(`Day ${store.levelDay} limit done: ${store.jobsToday} of ${store.jobLimit}. `, `दिन ${store.levelDay} की सीमा पूरी: ${store.jobsToday}/${store.jobLimit}। `, `రోజు ${store.levelDay} పరిమితి పూర్తి: ${store.jobsToday}/${store.jobLimit}. `)}</b>
                {store.t("All good ratings? Tomorrow you get 6 to 8 jobs.", "सब रेटिंग अच्छी? कल 6 से 8 काम मिलेंगे।", "అన్ని రేటింగ్‌లు బాగుంటే రేపు 6 నుండి 8 పనులు.")}
              </TD>
            </HStack>
          ) : !store.online && !hasPlan ? (
            <VStack gap={8} align="center" style={{ paddingTop: 34 }}>
              <Icon name="power" size={36} color={C.secondary} />
              <TD k="section" w={600}>{store.t("You’re offline", "आप ऑफ़लाइन हैं", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు")}</TD>
              <TD k="body">{store.t("Go online to get jobs near you", "पास के काम पाने के लिए ऑनलाइन जाएं", "దగ్గరి పనుల కోసం ఆన్‌లైన్‌కి వెళ్ళండి")}</TD>
            </VStack>
          ) : null}
        </VStack>
      </div>
      {store.online && !store.lowSignal && !(limitReached && store.signedUp) && (
        <LiveStrip text={store.t("Online · Looking for jobs near you", "ऑनलाइन · आपके पास काम ढूँढ रहे हैं", "ఆన్‌లైన్ · మీ దగ్గర పనులు వెతుకుతున్నాం")} />
      )}
      {!store.online && !hasPlan && (
        <WFooter><Button title={store.t("Go online", "ऑनलाइन जाएं", "ఆన్‌లైన్‌కి వెళ్ళండి")} icon="power" size="captain" onClick={() => setOnline(true)} /></WFooter>
      )}
    </div>
  );
}

/** Soft welcome for guests and new captains, with a quiet hint of what's possible. */
function WelcomeBanner() {
  const { store } = useCaptain();
  return (
    <div style={{ position: "relative", padding: "18px 58px 18px 18px", borderRadius: 18, background: `linear-gradient(135deg, ${C.primaryTint}, #FFF6E3)` }}>
      <VStack gap={8}>
        <HStack gap={8}>
          <Icon name="sparkle" size={15} color={C.primaryStrong} fill />
          <T k="label" c={C.primaryStrong}>{store.registered ? store.t(`Welcome, ${store.firstName}`, `स्वागत है, ${store.firstName}`, `స్వాగతం, ${store.firstName}`) : store.t(`Welcome to ${Brand.name}`, `${Brand.name} में स्वागत है`, `${Brand.name} కి స్వాగతం`)}</T>
        </HStack>
        <TD k="title" w={400} s={18} c={C.heading}>
          {store.t("Captains here earn up to ", "यहाँ कैप्टन महीने में ", "ఇక్కడ కెప్టెన్లు నెలకు ")}<b>₹80,000</b>{store.t(" a month.", " तक कमाते हैं।", " వరకు సంపాదిస్తారు.")}
        </TD>
        <TD k="caption">{store.t("Your hours, jobs near home, money every night.", "आपका समय, घर के पास काम, हर रात पैसे।", "మీ సమయం, ఇంటి దగ్గర పని, ప్రతి రాత్రి డబ్బు.")}</TD>
      </VStack>
      <div style={{ position: "absolute", right: 14, bottom: 14 }}><Icon name="figure" size={54} color="rgba(49,96,255,.14)" /></div>
    </div>
  );
}

// MARK: Online / Offline switch with a subtle, always-on animation

/** Online: a green dot sends out a slow ripple. Offline: a grey dot gently breathes. */
export function OnlineSwitch({ online, label, set }: { online: boolean; label: string; set: (v: boolean) => void }) {
  return (
    <HStack gap={8} style={{ flexShrink: 0 }}>
      <span key={String(online)} style={{ position: "relative", width: 14, height: 14, display: "grid", placeItems: "center" }}>
        {online && <span className="wh-ripple" style={{ position: "absolute", width: 10, height: 10, borderRadius: 5, boxShadow: `inset 0 0 0 2px ${C.success}` }} />}
        <span className={online ? undefined : "wh-breathe"} style={{ width: 10, height: 10, borderRadius: 5, background: online ? C.success : C.muted }} />
      </span>
      <T k="title" c={online ? C.heading : C.secondary} style={{ whiteSpace: "nowrap" }}>{label}</T>
      <span className={online ? "wh-glow-on" : "wh-glow-off"} style={{ borderRadius: 16, transform: "scale(1.08)", marginRight: 4 }}>
        <Toggle on={online} onChange={set} tint={C.success} label={label} />
      </span>
    </HStack>
  );
}

// MARK: Today's plan (calendar): one job after another, by time

const minutes = (t: string) => { const [h, m] = t.split(":").map(Number); return (h || 0) * 60 + (m || 0); };

/** A simple day calendar: time on the left, a line with dots, and each job as a compact card. */
export function DayPlan() {
  const { store, router } = useCaptain();
  const [doneDetail, setDoneDetail] = useState<Job | null>(null);
  const jobs = [...store.queue].sort((a, b) => minutes(a.time) - minutes(b.time));
  const done = store.queue.filter((j) => j.status === "done").length;
  const dot = (st: JobStatus) =>
    st === "done" ? <span style={{ width: 24, height: 24, borderRadius: 12, background: C.success, display: "grid", placeItems: "center" }}><Icon name="check" size={12} color={C.onSuccess} weight={700} /></span>
      : st === "now" ? <span style={{ width: 24, height: 24, borderRadius: 12, background: C.primary, boxShadow: "0 0 0 5px rgba(49,96,255,.25)", display: "grid", placeItems: "center" }}><span style={{ width: 9, height: 9, borderRadius: 5, background: "#fff" }} /></span>
      : <span style={{ width: 24, height: 24, borderRadius: 12, background: "#fff", boxShadow: `inset 0 0 0 2.5px ${C.muted}` }} />;
  const open = (j: Job) => {
    if (j.status === "done") setDoneDetail(j);
    else if (j.status === "now") router.push({ n: "goToVehicle" });
    else { store.startJob(j.id); router.push({ n: "goToVehicle" }); } // Captain chose to do this one first.
  };
  return (
    <VStack gap={12}>
      <HStack align="start">
        <VStack gap={2} style={{ flex: 1 }}>
          <TD k="section" w={600} s={21}>{store.t("Today’s plan", "आज का प्लान", "ఈరోజు ప్లాన్")}</TD>
          <TD k="caption">{`${Fmt.day(new Date())} · ` + store.t(`${done} of ${store.queue.length} done`, `${store.queue.length} में से ${done} पूरे`, `${store.queue.length} లో ${done} పూర్తి`)}</TD>
        </VStack>
        <span style={{ width: 36, height: 36, borderRadius: 18, background: C.primaryTint, display: "grid", placeItems: "center" }}><Icon name="calendar" size={18} color={C.primaryStrong} /></span>
      </HStack>
      <VStack>
        {jobs.map((j, i) => {
          const m = minutes(j.time), h = Math.floor(m / 60), mm = m % 60;
          const isDone = j.status === "done", now = j.status === "now", last = i === jobs.length - 1;
          return (
            <HStack key={j.id} align="stretch" gap={10}>
              <VStack align="end" style={{ width: 46, paddingTop: 12, flexShrink: 0 }}>
                <T k="title" s={17} mono c={isDone ? C.secondary : C.heading}>{`${h % 12 === 0 ? 12 : h % 12}:${String(mm).padStart(2, "0")}`}</T>
                <T k="small" c={C.secondary}>{h < 12 ? "AM" : "PM"}</T>
              </VStack>
              <VStack align="center" style={{ width: 26, flexShrink: 0 }}>
                <div style={{ paddingTop: 12 }}>{dot(j.status)}</div>
                {!last && <div style={{ width: 3, flex: 1, background: isDone ? C.success : C.border }} />}
              </VStack>
              <div style={{ flex: 1, minWidth: 0, paddingBottom: last ? 0 : 10 }}>
                <Tap onClick={() => open(j)} style={{
                  display: "flex", flexDirection: "column", gap: 6, padding: "11px 12px", width: "100%", textAlign: "left", borderRadius: 14,
                  background: now ? C.primaryTint : isDone ? C.canvas : "#fff", boxShadow: `inset 0 0 0 ${now ? 2 : 1}px ${now ? C.primary : C.border}`, opacity: isDone ? 0.8 : 1,
                }}>
                  <HStack gap={6} align="baseline">
                    <Icon name="location" size={13} color={isDone ? C.muted : C.primaryStrong} />
                    <T k="title" s={16} c={isDone ? C.secondary : C.heading} lines={1} style={{ flex: 1 }}>{j.society}</T>
                    <T k="title" s={16} mono c={isDone ? C.secondary : C.heading}>{Fmt.rupees(j.pay)}</T>
                  </HStack>
                  <HStack gap={8}>
                    <Icon name={j.isBike ? "bike" : "car"} size={14} color={isDone ? C.muted : C.secondary} />
                    <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: 1, color: isDone ? C.secondary : C.heading, padding: "2px 6px", borderRadius: 5, boxShadow: `inset 0 0 0 1.2px ${isDone ? C.border : C.heading}`, whiteSpace: "nowrap" }}>{j.plate}</span>
                    <T k="caption" s={13.5} lines={1} style={{ flex: 1 }}>{`${j.tower} · ${j.floor}`}</T>
                    {isDone ? <T k="small" c={C.onSuccess} w={600}>{store.t("Done", "पूरा", "పూర్తి")}</T> : <Icon name="chevron" size={12} color={now ? C.primaryStrong : C.muted} />}
                  </HStack>
                </Tap>
              </div>
            </HStack>
          );
        })}
      </VStack>
      <Sheet open={doneDetail != null} onClose={() => setDoneDetail(null)} height={330} gutter={20}>
        {doneDetail && <DoneJobSheet job={doneDetail} />}
      </Sheet>
    </VStack>
  );
}

/** Small pop-up for a finished job. */
function DoneJobSheet({ job }: { job: Job }) {
  const { store } = useCaptain();
  return (
    <VStack gap={14}>
      <HStack gap={12}>
        <span style={{ width: 44, height: 44, borderRadius: 22, background: C.success, display: "grid", placeItems: "center" }}><Icon name="check" size={20} color={C.onSuccess} weight={700} /></span>
        <VStack gap={2} style={{ flex: 1 }}>
          <TD k="section" w={600}>{store.t("Completed", "पूरा हुआ", "పూర్తయింది")}</TD>
          <TD k="caption">{`${job.time} · ${job.society}`}</TD>
        </VStack>
        <T k="section" w={600} mono>{Fmt.rupees(job.pay)}</T>
      </HStack>
      <HStack gap={10}><Plate text={job.plate} /><T k="caption">{JobFmt.spot(job)}</T></HStack>
      <HStack gap={8}>
        <PhotoPlaceholder height={76} icon={job.isBike ? "bike" : "car"} tag={store.t("Before", "पहले", "ముందు")} />
        <PhotoPlaceholder height={76} icon="sparkle" tag={store.t("After", "बाद", "తర్వాత")} tagTone="ok" />
      </HStack>
      <Badge text={store.t("Waiting for owner’s OK · paid tonight", "मालिक की मंज़ूरी का इंतज़ार · आज रात भुगतान", "యజమాని ఆమోదం కోసం · ఈ రాత్రి చెల్లింపు")} tone="wait" icon="clock" style={{ alignSelf: "flex-start" }} />
    </VStack>
  );
}

/** Slim, edge-to-edge strip shown only while online: a live green dot and one line. */
function LiveStrip({ text }: { text: string }) {
  return (
    <HStack gap={10} className="wh-slide-up" style={{ height: 38, padding: `0 ${S.gutterCaptain}px`, background: C.successTint, borderTop: "1px solid rgba(75,208,140,.35)", paddingBottom: 0 }}>
      <span style={{ position: "relative", width: 16, height: 16, display: "grid", placeItems: "center" }}>
        <span className="wh-ripple" style={{ position: "absolute", width: 9, height: 9, borderRadius: 5, background: "rgba(75,208,140,.35)" }} />
        <span style={{ width: 9, height: 9, borderRadius: 5, background: C.success }} />
      </span>
      <T k="label" s={14} c={C.onSuccess} lines={1}>{text}</T>
    </HStack>
  );
}

// MARK: W22 New job alert: a stack of offers (W22b batched, W22h Hindi, W22t Telugu, W22m many)

const OFFER_SECONDS = 30;
type Offer = { job: Job; arrived: number };

/** Every job that rings gets its own 30-second timer. New jobs slide in behind the top card.
 *  Reject (or swipe left) sends the top card to the back; Accept adds it to today's jobs. */
export function JobAlertScreen({ batched = false }: { batched?: boolean }) {
  const { store, router } = useCaptain();
  const [offers, setOffers] = useState<Offer[]>([]);
  const [now, setNow] = useState(Date.now());
  const [drag, setDrag] = useState(0);
  const [dragging, setDragging] = useState(false);
  const [newPill, setNewPill] = useState(false);
  const [acceptedHere, setAcceptedHere] = useState(0);
  const [flying, setFlying] = useState<{ job: Job; dir: "right" } | null>(null);
  const handled = useRef(false);
  const offersRef = useRef<Offer[]>([]);
  offersRef.current = offers;
  const startX = useRef(0);

  const left = (o: Offer) => Math.max(0, OFFER_SECONDS - (now - o.arrived) / 1000);
  const nudge = () => { ding(); buzz([60, 40, 60]); };

  useEffect(() => {
    // Only jobs that match "Where I work".
    const pool = offerPool.filter((j) => store.wantsJob(j));
    if (!pool.length) {
      handled.current = true;
      store.toast = store.t("No jobs in your area right now", "अभी आपके इलाके में काम नहीं", "ఇప్పుడు మీ ప్రాంతంలో పనులు లేవు");
      router.pop();
      return;
    }
    const start = Date.now();
    setOffers([{ job: pool[0], arrived: start }]);
    nudge();
    // Demo: more jobs ring while this one is open.
    const extra = pool.slice(1, 1 + store.extraOffers);
    const timers = [6, 13].slice(0, extra.length).map((s, i) => setTimeout(() => {
      if (handled.current) return;
      setOffers((o) => [...o, { job: extra[i], arrived: Date.now() }]);
      store.notify("newJob", { job: extra[i], deliver: false });
      nudge();
      setNewPill(true);
      setTimeout(() => setNewPill(false), 1600);
    }, s * 1000));
    const tick = setInterval(() => setNow(Date.now()), 100);
    return () => { timers.forEach(clearTimeout); clearInterval(tick); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Jobs whose 30 seconds ran out go to someone else.
  useEffect(() => {
    if (handled.current || !offers.length) return;
    const expired = offers.filter((o) => left(o) <= 0);
    if (!expired.length) return;
    expired.forEach((o) => store.notify("jobTaken", { job: o.job, deliver: false }));
    const rest = offers.filter((o) => left(o) > 0);
    setOffers(rest);
    if (!rest.length) {
      handled.current = true;
      if (acceptedHere > 0) router.home(); else router.replace([{ n: "jobMissed" }]);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [now]);

  const leave = () => { if (handled.current) return; handled.current = true; router.home(); };

  /** Reject: the top card goes to the back of the stack (its timer keeps running). With one card left, Reject closes. */
  const reject = () => {
    if (handled.current || !offers.length) return;
    if (offers.length === 1) { leave(); return; }
    buzz(10);
    setOffers((o) => [...o.slice(1), o[0]]);
  };

  /** Accept: the job moves to Home (today's jobs) and the next offer shows. */
  const accept = () => {
    const top = offersRef.current[0];
    if (handled.current || !top) return;
    if (!store.signedUp) {
      // First job: a quick KYC before accepting.
      handled.current = true;
      store.kycFromJob = true;
      router.replace([{ n: "steps", problem: false }]);
      return;
    }
    store.acceptOffer(top.job);
    buzz(20);
    setFlying({ job: top.job, dir: "right" });
    setTimeout(() => setFlying(null), 450);
    const rest = offersRef.current.slice(1);
    setOffers(rest);
    setAcceptedHere((n) => n + 1);
    if (!rest.length) {
      handled.current = true;
      store.toast = store.t("Added to your jobs", "आपके कामों में जोड़ा गया", "మీ పనుల్లో చేర్చబడింది");
      setTimeout(() => router.home(), 400);
    }
  };

  const fact = (icon: IconName, big: string, small: string) => (
    <VStack gap={4} style={{ flex: 1, minWidth: 0, padding: 12, borderRadius: 14, background: C.primaryTint }}>
      <Icon name={icon} size={20} color={C.primaryStrong} />
      <T k="section" w={600} lines={1}>{big}</T>
      <T k="caption" c={C.heading}>{small}</T>
    </VStack>
  );

  const offerCard = (o: Offer, i: number, fly = false) => {
    const j = o.job, isTop = i === 0 && !fly;
    const dx = isTop ? drag : 0;
    return (
      <div key={j.id + (fly ? "_fly" : "")} className={fly ? "wh-fly-right" : i === offers.length - 1 && offers.length > 1 && !isTop ? "wh-card-in" : undefined}
        onPointerDown={isTop ? (e) => { (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId); startX.current = e.clientX; setDragging(true); } : undefined}
        onPointerMove={isTop ? (e) => { if (dragging) setDrag(Math.min(40, e.clientX - startX.current)); } : undefined}
        onPointerUp={isTop ? () => {
          setDragging(false);
          if (drag < -110) { setDrag(-600); setTimeout(() => { setDrag(0); reject(); }, 220); } else setDrag(0);
        } : undefined}
        style={{
          position: i === 0 ? "relative" : "absolute", top: 0, left: 0, right: 0, zIndex: 10 - i, touchAction: "pan-y",
          padding: 18, borderRadius: 22, background: "#fff", boxShadow: `0 4px 12px rgba(0,0,0,${isTop ? 0.12 : 0.06})`,
          transform: `translateY(${i * 14}px) scale(${1 - i * 0.05}) translateX(${dx}px) rotate(${dx / 22}deg)`, transformOrigin: "bottom center",
          opacity: i === 0 ? 1 : i === 1 ? 0.85 : 0.6, transition: dragging && isTop ? "none" : "transform .35s cubic-bezier(.2,.8,.2,1), opacity .3s",
          display: "flex", flexDirection: "column", gap: 14, cursor: isTop ? "grab" : undefined,
        }}>
        <HStack gap={16}>
          <IconBox icon={j.isBike ? "bike" : "car"} size={72} radius={16} iconSize={32} />
          <VStack style={{ flex: 1 }}>
            <T k="body">{store.t("Your pay", "आपकी कमाई", "మీ సంపాదన")}</T>
            <T k="bigMoney" mono>{Fmt.rupees(j.pay)}</T>
          </VStack>
          {!isTop && <T k="label" c={C.secondary} mono>{`0:${String(Math.ceil(left(o))).padStart(2, "0")}`}</T>}
        </HStack>
        <HStack gap={8}>
          {fact("location", j.distance, store.t("away", "दूर", "దూరం"))}
          {fact("layers", j.floor, store.t("Floor", "फ्लोर", "ఫ్లోర్"))}
          {fact("clock", j.window, store.t("Today", "आज", "ఈరోజు"))}
        </HStack>
        {/* Where the job is: society first, then the full address. */}
        <HStack align="start" gap={10} style={{ padding: 12, borderRadius: 14, background: C.canvas }}>
          <Icon name="location" size={19} color={C.primaryStrong} style={{ marginTop: 2 }} />
          <VStack gap={3}>
            <TD k="title" s={17.5}>{j.society}</TD>
            <TD k="caption" s={14}>{JobFmt.fullAddress(j)}</TD>
          </VStack>
        </HStack>
        <HStack gap={10}><Plate text={j.plate} /><T k="caption">{j.type}</T></HStack>
        <BookingChip job={j} />
        {batched && isTop && offers.length === 1 && (
          <HStack align="start" gap={10} style={{ padding: 14, borderRadius: 14, background: C.successTint }}>
            <Icon name="list" size={16} color={C.onSuccess} />
            <TD k="caption" c={C.onSuccess} s={14.5}><b>{store.t("Next to your current job. ", "आपके अभी के काम के पास। ", "మీ ప్రస్తుత పని పక్కనే. ")}</b>{store.t("Starts after you finish at 8:55 AM.", "8:55 AM पर ख़त्म होने के बाद शुरू।", "8:55 AM కి పూర్తయ్యాక మొదలు.")}</TD>
          </HStack>
        )}
        {isTop && drag < -30 && (
          <span style={{ position: "absolute", top: 18, right: 18, padding: "0 12px", height: 30, borderRadius: 999, boxShadow: `inset 0 0 0 2px ${C.destructive}`, transform: "rotate(12deg)", display: "grid", placeItems: "center", opacity: Math.min(1, (-drag - 30) / 60) }}>
            <T k="label" c={C.destructive} w={700}>{store.t("LATER", "बाद में", "తర్వాత")}</T>
          </span>
        )}
      </div>
    );
  };

  const top = offers[0];
  return (
    <div className="wh-fill" style={{ background: C.primary, padding: `var(--sat) ${S.gutterCaptain}px calc(12px + var(--sab))` }}>
      <HStack gap={10} style={{ paddingTop: 14 }}>
        <Tap onClick={leave} label={store.t("Close", "बंद करें", "మూసివేయండి")} style={{ width: 36, height: 36, borderRadius: 18, background: "rgba(255,255,255,.18)", display: "grid", placeItems: "center" }}>
          <Icon name="close" size={17} color="#fff" weight={600} />
        </Tap>
        <T k="screen" s={23} c="#fff">{offers.length > 1 ? store.t("New jobs", "नए काम", "కొత్త పనులు") : store.t("New job", "नया काम", "కొత్త పని")}</T>
        {offers.length > 1 && <span style={{ padding: "0 10px", height: 26, borderRadius: 999, background: "#fff", display: "grid", placeItems: "center" }}><T k="label" c={C.primaryStrong}>{`1 / ${offers.length}`}</T></span>}
        <div style={{ flex: 1 }} />
        {top && <T k="screen" s={23} c="#fff" mono>{`0:${String(Math.ceil(left(top))).padStart(2, "0")}`}</T>}
      </HStack>
      {top && (
        <div style={{ height: 8, borderRadius: 4, background: "rgba(255,255,255,.35)", margin: "12px 0 16px", overflow: "hidden" }}>
          <div style={{ height: 8, borderRadius: 4, width: `${(left(top) / OFFER_SECONDS) * 100}%`, background: left(top) / OFFER_SECONDS < 0.25 ? "#FFD27A" : "#fff", transition: "width .1s linear" }} />
        </div>
      )}
      <div style={{ position: "relative" }}>
        {offers.slice(0, 3).map((o, i) => offerCard(o, i)).reverse()}
        {flying && <div style={{ position: "absolute", inset: 0, zIndex: 20, pointerEvents: "none" }}>{offerCard({ job: flying.job, arrived: 0 }, 0, true)}</div>}
        {newPill && (
          <span className="wh-scale-in" style={{ position: "absolute", top: -16, left: "50%", marginLeft: -60, width: 120, height: 32, borderRadius: 999, background: "#fff", boxShadow: "0 3px 8px rgba(0,0,0,.15)", display: "grid", placeItems: "center", zIndex: 30 }}>
            <T k="label" c={C.primaryStrong}>{store.t("+1 new job", "+1 नया काम", "+1 కొత్త పని")}</T>
          </span>
        )}
      </div>
      {offers.length > 1 && (
        <HStack gap={6} style={{ justifyContent: "center", paddingTop: (Math.min(offers.length, 3) - 1) * 12 + 18 }}>
          <Icon name="wipe" size={15} color="rgba(255,255,255,.9)" />
          <T k="caption" c="rgba(255,255,255,.9)">{store.t("Swipe left to see the next job", "अगला काम देखने के लिए बाएँ स्वाइप करें", "తదుపరి పని చూడటానికి ఎడమకు స్వైప్ చేయండి")}</T>
        </HStack>
      )}
      <div style={{ flex: 1, minHeight: 12 }} />
      {acceptedHere > 0 && (
        <HStack gap={8} className="wh-fade-in" style={{ justifyContent: "center", paddingBottom: 12 }}>
          <Icon name="checkCircle" size={17} color="#fff" fill={false} />
          <T k="label" c="#fff">{store.t(`${acceptedHere} accepted · on your Home`, `${acceptedHere} स्वीकार · होम पर`, `${acceptedHere} అంగీకరించారు · హోమ్‌లో`)}</T>
        </HStack>
      )}
      <div style={{ paddingBottom: 12 }}><WorkAreaChip onDark /></div>
      {/* Reject on the left, Accept (primary) on the right. */}
      <HStack gap={12}>
        <Tap onClick={reject} disabled={!offers.length} style={{ width: 150, flexShrink: 0, height: 72, borderRadius: 36, boxShadow: "inset 0 0 0 2px rgba(255,255,255,.85)", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          <Icon name="close" size={19} color="#fff" weight={600} />
          <T k="section" c="#fff" w={600}>{store.t("Reject", "मना करें", "తిరస్కరించు")}</T>
        </Tap>
        <Button title={store.t("Accept", "स्वीकार करें", "అంగీకరించండి")} icon="check" kind="success" size="accept" enabled={offers.length > 0} onClick={accept} />
      </HStack>
    </div>
  );
}

// MARK: W23 Job went to someone else

export function JobMissedScreen() {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}>
      <FullState icon="clock" tone="mute" captain title={store.t("Job went to someone else", "काम किसी और को मिल गया", "పని వేరొకరికి వెళ్ళింది")}
        message={store.t("Time ran out. Keep the app open. Next job comes soon.", "समय ख़त्म हो गया। ऐप खुला रखें। अगला काम जल्दी आएगा।", "సమయం ముగిసింది. యాప్ తెరిచి ఉంచండి. త్వరలో పని వస్తుంది.")}
        primary={store.t("Back to home", "होम पर वापस", "హోమ్‌కి తిరిగి")} onPrimary={() => router.home()} />
    </Screen>
  );
}

// MARK: W25 Today's jobs

export function JobsTab() {
  const { store, router } = useCaptain();
  const status = (s: JobStatus) =>
    s === "now" ? <Badge text={store.t("Now", "अभी", "ఇప్పుడు")} tone="info" icon="drop" />
      : s === "next" ? <Badge text={store.t("Next", "अगला", "తదుపరి")} tone="info" icon="check" />
      : <Badge text={store.t("Done", "पूरा", "పూర్తి")} tone="ok" icon="sparkle" />;
  return (
    <div className="wh-scroll" style={{ position: "absolute", inset: 0, background: C.canvas, paddingTop: "var(--sat)" }}>
      <VStack gap={12} style={{ padding: `0 ${S.gutterCaptain}px 20px` }}>
        <WTitle style={{ paddingTop: 22, paddingBottom: 4 }}>{store.t("Today’s jobs", "आज के काम", "ఈరోజు పనులు")}</WTitle>
        {!store.signedUp && <GuestNotice text={store.t("This is an example day. Your real jobs show here once you start.", "यह एक उदाहरण दिन है। शुरू करने के बाद आपके असली काम यहाँ दिखेंगे।", "ఇది ఒక ఉదాహరణ రోజు. మొదలుపెట్టాక మీ నిజమైన పనులు ఇక్కడ కనిపిస్తాయి.")} />}
        {store.queue.map((j) => (
          <Tap key={j.id} onClick={() => { if (j.status === "now" && store.signedUp) router.push({ n: "goToVehicle" }); }}
            style={{ ...card(16), display: "flex", alignItems: "center", gap: 14, textAlign: "left" }}>
            <T k="title" s={17} mono style={{ width: 46, flexShrink: 0 }}>{j.time}</T>
            <VStack gap={6} align="start" style={{ flex: 1, minWidth: 0 }}>
              <Plate text={j.plate} />
              <TD k="title" s={16}>{j.society}</TD>
              <TD k="caption">{JobFmt.spot(j)}</TD>
              {status(j.status)}
            </VStack>
            <T k="section" w={600} mono>{Fmt.rupees(j.pay)}</T>
          </Tap>
        ))}
      </VStack>
    </div>
  );
}

// MARK: W26 Go to vehicle

export function GoToVehicleScreen() {
  const { store, router } = useCaptain();
  const [showPhotos, setShowPhotos] = useState(false);
  const j = store.current;
  useEffect(() => {
    // Demo: "I don't show up" switch in Screens runs late → slot over → cancelled.
    if (!store.noShowDemo) return;
    store.startNoShowDemo(() => { if (router.is("goToVehicle")) router.replace([{ n: "noShowCancelled" }]); });
  }, [store, router]);
  const place = (icon: IconName, big: string, small: string) => (
    <VStack gap={4} style={{ flex: 1, minWidth: 0, minHeight: 104, padding: 12, borderRadius: 14, background: C.primaryTint }}>
      <Icon name={icon} size={21} color={C.primaryStrong} />
      <T k="section" w={600} lines={2}>{big}</T>
      <T k="caption" c={C.heading}>{small}</T>
    </VStack>
  );
  return (
    <>
      <Screen gutter={S.gutterCaptain}
        header={<AppBar title={store.t("Go to vehicle", "गाड़ी तक जाएं", "వాహనం దగ్గరికి వెళ్ళండి")} subtitle={`${store.t("Reach by", "पहुँचें", "చేరుకోండి")} ${j.reachBy}`}
          onLeading={() => router.home()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 4px 0" }} />}
        footer={
          <VStack>
            <WFooter><Button title={store.t("I’m at the vehicle", "मैं गाड़ी के पास हूँ", "నేను వాహనం దగ్గర ఉన్నాను")} size="captain" onClick={() => {
              store.captainArrived();
              store.resetJob();
              store.ownerNoteHeard = false;
              // The owner's voice note plays first (must listen once).
              router.push({ n: "ownerNote" });
            }} /></WFooter>
            <HStack style={{ padding: `0 ${S.gutterCaptain}px 8px`, justifyContent: "space-between", background: "#fff" }}>
              <Link title={store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను")} onClick={() => router.push({ n: "gateProblem" })} />
              <Link title={store.t("Can’t find vehicle", "गाड़ी नहीं मिल रही", "వాహనం కనబడట్లేదు")} onClick={() => router.push({ n: "cantFind" })} />
            </HStack>
          </VStack>
        }>
        {store.slotEnded ? (
          <Banner tone="error" icon="warning" title={store.t("Slot is over.", "समय खत्म।", "సమయం ముగిసింది.")} style={{ marginTop: 10 }}
            text={store.t("Tap I’m at the vehicle now, or tell us in Help. Otherwise the job is cancelled and a penalty applies.", "अभी ‘मैं गाड़ी के पास हूँ’ दबाएं या मदद में बताएं। नहीं तो काम रद्द होगा और जुर्माना लगेगा।", "ఇప్పుడే ‘నేను వాహనం దగ్గర ఉన్నాను’ నొక్కండి లేదా సహాయంలో చెప్పండి. లేదంటే పని రద్దు, జరిమానా.")}
            actionTitle={store.t("Get help", "मदद लें", "సహాయం పొందండి")} onAction={() => router.push({ n: "helpFlow", topic: "job" })} />
        ) : store.jobLate ? (
          <Banner tone="wait" icon="clock" title={store.t("You’re late.", "आप लेट हैं।", "మీరు ఆలస్యం.")} style={{ marginTop: 10 }}
            text={store.t("Reach now. −₹1 for every late minute.", "अभी पहुँचें। हर लेट मिनट पर −₹1।", "ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1.")} />
        ) : null}
        <VStack gap={14} style={{ ...card(16), marginTop: 10 }}>
          {/* Address + plate on the left, the owner's vehicle photo on the right. */}
          <HStack align="start" gap={12}>
            <VStack gap={12} align="start" style={{ flex: 1, minWidth: 0 }}>
              <HStack align="start" gap={8}>
                <Icon name="location" size={18} color={C.primaryStrong} style={{ marginTop: 2 }} />
                <VStack gap={3}>
                  <TD k="title" s={18}>{j.society}</TD>
                  <TD k="caption" s={13.5}>{JobFmt.fullAddress(j)}</TD>
                </VStack>
              </HStack>
              <Plate text={j.plate} />
            </VStack>
            <Tap onClick={() => setShowPhotos(true)} label={store.t("Vehicle photos", "गाड़ी की फ़ोटो", "వాహనం ఫోటోలు")}
              style={{ position: "relative", width: 112, height: 132, borderRadius: 14, overflow: "hidden", flexShrink: 0 }}>
              <VehiclePhotoView side={0} isBike={j.isBike} compact />
              <span style={{ position: "absolute", bottom: 8, left: "50%", transform: "translateX(-50%)", display: "flex", alignItems: "center", gap: 4, padding: "0 8px", height: 22, borderRadius: 999, background: "rgba(0,0,0,.55)" }}>
                <Icon name="photos" size={11} color="#fff" weight={600} /><T k="small" s={11} c="#fff" w={600}>4</T>
              </span>
              <span style={{ position: "absolute", top: 6, right: 6, width: 24, height: 24, borderRadius: 12, background: "rgba(0,0,0,.45)", display: "grid", placeItems: "center" }}>
                <Icon name="expand" size={11} color="#fff" weight={700} />
              </span>
            </Tap>
          </HStack>
          <BookingChip job={j} />
          <HStack gap={8}>
            {place("building", j.tower, store.t("Building", "बिल्डिंग", "భవనం"))}
            {place("layers", j.floor, store.t("Floor", "फ्लोर", "ఫ్లోర్"))}
            {place("parking", j.slot || "—", store.t("Slot", "स्लॉट", "స్లాట్"))}
          </HStack>
        </VStack>
        <Tap onClick={() => router.push({ n: "gateProblem" })} style={{ marginTop: 14, display: "flex", alignItems: "center", gap: 12, padding: 14, borderRadius: 16, background: "#fff", boxShadow: `inset 0 0 0 1px ${C.border}` }}>
          <Icon name="door" size={23} />
          <T k="title" style={{ flex: 1, textAlign: "left" }}>{store.t("Gate pass", "गेट पास", "గేట్ పాస్")}</T>
          <Badge text={store.t("Ready", "तैयार", "సిద్ధం")} tone="ok" icon="check" />
          <Icon name="chevron" size={13} color={C.secondary} />
        </Tap>
      </Screen>
      {showPhotos && <VehiclePhotosViewer isBike={j.isBike} plate={j.plate} onClose={() => setShowPhotos(false)} />}
    </>
  );
}

// MARK: W27 Can't get in

export function GateProblemScreen() {
  const { store } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను")} />}
      footer={<WFooter><Button title={store.t("Call owner", "मालिक को कॉल करें", "యజమానికి కాల్ చేయండి")} icon="phone" size="captain" onClick={() => Support.call()} /></WFooter>}>
      <VStack gap={12} align="center" style={{ paddingTop: 30 }}>
        <StateCircle icon="door" tone="wait" size={112} />
        <TD k="section" w={600} s={23} center>{store.t("Show this at the gate", "यह गेट पर दिखाएं", "ఇది గేట్ వద్ద చూపించండి")}</TD>
        <WBody center>{store.t("Owner’s MyGate pass for today.", "आज के लिए मालिक का MyGate पास।", "ఈరోజు కోసం యజమాని MyGate పాస్.")}</WBody>
        <VStack gap={10} align="center" style={{ width: "100%", height: 196, marginTop: 14, justifyContent: "center", borderRadius: 12, background: C.photo, boxShadow: `inset 0 0 0 1px ${C.border}` }}>
          <Icon name="image" size={34} color={C.secondary} />
          <T k="caption">{`MyGate pass · ${store.current.owner}, ${store.current.tower}`}</T>
        </VStack>
      </VStack>
    </Screen>
  );
}

// MARK: W28 Can't find vehicle

export function CantFindScreen() {
  const { store, router } = useCaptain();
  const option = (icon: IconName, title: string) => (
    <Tap onClick={() => router.push({ n: "ownerCancelled" })} style={{ display: "flex", alignItems: "center", gap: 16, padding: "0 16px", height: 84, borderRadius: 16, background: "#fff", boxShadow: `inset 0 0 0 1px ${C.border}` }}>
      <IconBox icon={icon} size={52} radius={12} />
      <T k="value" s={18}>{title}</T>
    </Tap>
  );
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Can’t find vehicle", "गाड़ी नहीं मिल रही", "వాహనం కనబడట్లేదు")} />}
      footer={<WFooter><Button title={store.t("Call owner", "मालिक को कॉल करें", "యజమానికి కాల్ చేయండి")} icon="phone" size="captain" onClick={() => Support.call()} /></WFooter>}>
      <WTitle style={{ paddingTop: 10, paddingBottom: 16 }}>{store.t("What do you see?", "आपको क्या दिख रहा है?", "మీకు ఏం కనిపిస్తోంది?")}</WTitle>
      <VStack gap={12}>
        {option("parking", store.t("Slot is empty", "स्लॉट खाली है", "స్లాట్ ఖాళీగా ఉంది"))}
        {option("car", store.t("Different car in slot", "स्लॉट में दूसरी गाड़ी है", "స్లాట్‌లో వేరే కారు ఉంది"))}
        {option("layers", store.t("Can’t find the floor", "फ्लोर नहीं मिल रहा", "ఫ్లోర్ కనబడట్లేదు"))}
      </VStack>
      <TD k="caption" style={{ paddingTop: 16 }}>{store.t("We tell the owner and wait 10 minutes. You still get ₹[WAIT FEE] if the car isn’t there.", "हम मालिक को बताएंगे और 10 मिनट रुकेंगे। गाड़ी न मिले तो भी आपको ₹[WAIT FEE] मिलेंगे।", "మేము యజమానికి చెప్పి 10 నిమిషాలు ఆగుతాము. కారు లేకపోయినా మీకు ₹[WAIT FEE] వస్తుంది.")}</TD>
    </Screen>
  );
}

// MARK: W29 Owner cancelled

export function OwnerCancelledScreen() {
  const { store, router } = useCaptain();
  useEffect(() => { store.notify("ownerCancelled", { job: store.current, deliver: false }); }, [store]);
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}>
      <FullState icon="close" tone="mute" captain title={store.t("Owner cancelled this job", "मालिक ने यह काम रद्द किया", "యజమాని ఈ పని రద్దు చేశారు")}
        message={store.t("You were on the way, so you get ₹[CANCELLATION FEE] for the trip.", "आप रास्ते में थे, इसलिए आपको सफ़र के ₹[CANCELLATION FEE] मिलेंगे।", "మీరు దారిలో ఉన్నారు, కాబట్టి ప్రయాణానికి ₹[CANCELLATION FEE] వస్తుంది.")}
        primary={store.t("Back to jobs", "कामों पर वापस", "పనులకు తిరిగి")} onPrimary={() => { router.home(); router.tab = 1; }} />
    </Screen>
  );
}

