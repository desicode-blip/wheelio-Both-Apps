"use client";

import { useEffect, useState } from "react";
import { C, S } from "../../ds/tokens";
import { Badge, Banner, Button, FullState, HStack, KeyValueCard, Link, PhotoSlot, Screen, SegmentBar, StateCircle, Tap, T, TD, VStack, card } from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt } from "../../lib/fmt";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import { washWater } from "../store";
import { BookingVisual, CarShape, OwnerNoteButton, playNote, sideName, stopNote, useNotePlayer } from "./parts";

/** Before · Wash · After progress for a job. 0 before, 1 wash, 2 after. */
function WashStageBar({ stage }: { stage: number }) {
  const { store } = useCaptain();
  return <SegmentBar filled={stage + 1} total={3} greenUpTo={stage}
    labels={[store.t("Before", "पहले", "ముందు"), store.t("Wash", "धुलाई", "వాష్"), store.t("After", "बाद में", "తర్వాత")]} />;
}

// MARK: W26n Owner's note (must listen once, right after "I'm at the vehicle")

export function OwnerNoteScreen() {
  const { store, router } = useCaptain();
  const p = useNotePlayer();
  useEffect(() => {
    // Auto-play only the first time.
    if (store.ownerNoteHeard) return;
    p.finishedOnce = false;
    p.progress = 0;
    const t = setTimeout(() => { if (router.is("ownerNote") && !store.ownerNoteHeard && !p.playing) playNote(store.lang); }, 400);
    return () => { clearTimeout(t); if (p.playing) stopNote(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const bars = [10, 18, 28, 14, 22, 34, 16, 26, 12, 30, 20, 24];
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false} header={<WHeader title={store.t("Owner’s note", "मालिक का संदेश", "యజమాని నోట్")} />}
      footer={<WFooter><Button title={store.t("Continue", "आगे बढ़ें", "కొనసాగించండి")} size="captain" enabled={p.finishedOnce}
        onClick={() => { stopNote(); store.ownerNoteHeard = true; router.push({ n: "faceCheck" }); }} /></WFooter>}>
      <VStack gap={18} align="center" style={{ flex: 1, justifyContent: "center" }}>
        <TD k="section" w={600} s={22} center>{store.t("Listen before you start", "शुरू करने से पहले सुनें", "మొదలుపెట్టే ముందు వినండి")}</TD>
        <T k="body">{`${store.current.owner} · ${store.current.society}`}</T>
        {/* Big play / pause with a moving sound wave. */}
        <Tap onClick={() => (p.playing ? stopNote() : playNote(store.lang))} label={p.playing ? "Pause" : "Play owner's note"}
          style={{ position: "relative", width: 190, height: 190, display: "grid", placeItems: "center" }}>
          <span className={p.playing ? "wh-pulse" : undefined} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: C.primaryTint, animationDuration: ".5s" }} />
          <span style={{ position: "relative", width: 124, height: 124, borderRadius: 62, background: C.primary, display: "grid", placeItems: "center" }}>
            <Icon name={p.playing ? "pause" : p.finishedOnce ? "replay" : "play"} size={46} color="#fff" weight={600} fill={!p.finishedOnce || p.playing} />
          </span>
        </Tap>
        <HStack gap={4} style={{ height: 36 }}>
          {Array.from({ length: 24 }, (_, i) => (
            <span key={i} className={p.playing ? "wh-wave" : undefined} style={{ width: 5, height: p.playing ? bars[i % 12] : bars[i % 12] * 0.6, borderRadius: 3, background: i / 24 < p.progress ? C.primary : C.border, animationDelay: `${(i % 5) * 0.08}s` }} />
          ))}
        </HStack>
        <TD k="caption" center>{p.finishedOnce
          ? store.t("Done. You can play it again anytime from the side button.", "हो गया। साइड बटन से कभी भी फिर सुन सकते हैं।", "అయింది. పక్క బటన్ నుండి ఎప్పుడైనా మళ్ళీ వినవచ్చు.")
          : store.t("Listen till the end to continue.", "आगे बढ़ने के लिए पूरा सुनें।", "కొనసాగడానికి పూర్తిగా వినండి.")}</TD>
      </VStack>
    </Screen>
  );
}

// MARK: W30 Quick face check

export function FaceCheckScreen() {
  const { store, router } = useCaptain();
  const [checking, setChecking] = useState(false);
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false} header={<WHeader title={store.t("Quick check", "जल्दी जाँच", "త్వరిత తనిఖీ")} />}
      footer={<WFooter><Button title={store.t("Open camera", "कैमरा खोलें", "కెమెరా తెరవండి")} icon="camera" size="captain" loading={checking} onClick={() => {
        setChecking(true);
        setTimeout(() => { setChecking(false); router.replace([{ n: "goToVehicle" }, { n: "beforePhotos" }]); }, 1200);
      }} /></WFooter>}>
      <FullState icon="face" captain spinning={checking} title={store.t("Show your face", "अपना चेहरा दिखाएं", "మీ ముఖం చూపించండి")}
        message={store.t("Only to check it’s you. Takes 2 seconds.", "सिर्फ़ यह जाँचने के लिए कि आप ही हैं। 2 सेकंड लगेंगे।", "అది మీరేనని చూడటానికి మాత్రమే. 2 సెకన్లు.")} />
    </Screen>
  );
}

// MARK: W31 Before photos · W35 After photos

export function JobPhotosScreen({ after }: { after: boolean }) {
  const { store, router } = useCaptain();
  const done = after ? store.afterDone : store.beforeDone;
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.current.plate} />}
      footer={<WFooter>{after
        ? <Button title={store.t("Check photos", "फ़ोटो जाँचें", "ఫోటోలు తనిఖీ చేయండి")} size="captain" enabled={done.length === 4} onClick={() => router.push(store.aiFlag ? { n: "aiCheck" } : { n: "uploading" })} />
        : <Button title={store.t("Next", "आगे", "తదుపరి")} size="captain" enabled={done.length === 4} onClick={() => router.push({ n: "washing" })} />}</WFooter>}>
      <div style={{ paddingTop: 4 }}><WashStageBar stage={after ? 2 : 0} /></div>
      <HStack gap={10} style={{ paddingTop: 18 }}>
        <WTitle style={{ flex: 1 }}>{after ? store.t("After photos", "बाद की फ़ोटो", "తర్వాతి ఫోటోలు") : store.t("Before photos", "पहले की फ़ोटो", "ముందు ఫోటోలు")}</WTitle>
        <OwnerNoteButton />
      </HStack>
      <WBody style={{ paddingTop: 4, paddingBottom: 16 }}>{after ? store.t("Same 4 sides as before.", "पहले जैसी ही 4 तरफ़।", "ముందు లాగే 4 వైపులు.") : store.t("4 sides. Same as the outline.", "4 तरफ़। आउटलाइन जैसा।", "4 వైపులు. అవుట్‌లైన్ లాగే.")}</WBody>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
        {[0, 1, 2, 3].map((i) => done.includes(i) ? (
          <PhotoSlot key={i} label={sideName(store, i)} state="done" height={112} tag={after ? store.t("After", "बाद", "తర్వాత") : store.t("Before", "पहले", "ముందు")} tagTone={after ? "ok" : "mute"} />
        ) : (
          <Tap key={i} onClick={() => router.push({ n: "camera", after, side: i })} style={{ height: 136, borderRadius: 12, border: `1px dashed ${C.dashed}`, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8 }}>
            <Icon name="camera" size={26} color={C.primaryStrong} />
            <T k="title" s={17} c={C.primaryStrong}>{sideName(store, i)}</T>
          </Tap>
        ))}
      </div>
    </Screen>
  );
}

// MARK: W32 Camera (in-app, time and location stamped)

export function JobCameraScreen({ after, side }: { after: boolean; side: number }) {
  const { store, router } = useCaptain();
  const shoot = () => {
    if (store.darkPhoto && side === 2 && !after) { store.darkPhoto = false; router.swapTop({ n: "photoDark" }); return; }
    if (after) { if (!store.afterDone.includes(side)) store.afterDone = [...store.afterDone, side]; }
    else if (!store.beforeDone.includes(side)) store.beforeDone = [...store.beforeDone, side];
    const done = after ? store.afterDone : store.beforeDone;
    const next = [0, 1, 2, 3].find((i) => !done.includes(i));
    if (next != null) router.swapTop({ n: "camera", after, side: next }); else router.pop();
  };
  return (
    <div className="wh-fill" style={{ background: C.camera, paddingTop: "var(--sat)", paddingBottom: "var(--sab)" }}>
      <HStack style={{ padding: "0 8px" }}>
        <Tap onClick={() => router.pop()} label="Close" style={{ width: 48, height: 48, display: "grid", placeItems: "center" }}><Icon name="close" size={20} color="rgba(255,255,255,.5)" /></Tap>
        <T k="section" c="#fff" w={600} style={{ flex: 1, textAlign: "center" }}>{sideName(store, side) + (side >= 2 ? store.t(" side", "", "") : "")}</T>
        <span style={{ padding: "5px 10px", borderRadius: 999, background: C.primaryTint }}><T k="label" c={C.primaryStrong}>{`${side + 1} ${store.t("of", "/", "/")} 4`}</T></span>
      </HStack>
      <div key={side} className="wh-fade-in" style={{ position: "relative", flex: 1, margin: "6px 12px 0", borderRadius: 16, background: C.cameraPanel, display: "grid", placeItems: "center" }}>
        {/* Dotted guide matches the side: front and back views, or the side profile. */}
        {side >= 2 ? <CarShape side={side} width={270} height={100} dash /> : <CarShape side={side} width={240} height={180} dash />}
        <div style={{ position: "absolute", top: 12, left: 12 }}><Badge text={store.t("At the vehicle", "गाड़ी के पास", "వాహనం దగ్గర")} tone="ok" icon="location" /></div>
      </div>
      <HStack style={{ padding: "22px 0", justifyContent: "space-between" }}>
        <div style={{ width: 60, display: "grid", placeItems: "center" }}><Icon name="flash" size={22} color="rgba(255,255,255,.4)" /></div>
        <Tap onClick={shoot} label="Take photo" style={{ width: 84, height: 84, borderRadius: 42, boxShadow: "inset 0 0 0 5px #fff", display: "grid", placeItems: "center" }}>
          <span style={{ width: 66, height: 66, borderRadius: 33, background: "#fff" }} />
        </Tap>
        <div style={{ width: 60 }} />
      </HStack>
    </div>
  );
}

// MARK: W33 Photo too dark

export function PhotoDarkScreen() {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={sideName(store, 2) + store.t(" side", "", "")} />}
      footer={<WFooter><Button title={store.t("Take again", "फिर से लें", "మళ్ళీ తీయండి")} icon="camera" size="captain" onClick={() => router.swapTop({ n: "camera", after: false, side: 2 })} /></WFooter>}>
      <div style={{ position: "relative", height: 216, marginTop: 8, borderRadius: 14, background: "#2A3646", boxShadow: `inset 0 0 0 3px ${C.destructive}`, display: "grid", placeItems: "center" }}>
        <Icon name="car" size={46} color="rgba(255,255,255,.4)" />
        <div style={{ position: "absolute", top: 12, left: 12 }}><Badge text={store.t("Too dark", "बहुत अंधेरा", "చాలా చీకటి")} tone="error" icon="sun" /></div>
      </div>
      <WTitle style={{ paddingTop: 22 }}>{store.t("Photo is too dark", "फ़ोटो बहुत अंधेरी है", "ఫోటో చాలా చీకటిగా ఉంది")}</WTitle>
      <WBody style={{ paddingTop: 6 }}>{store.t("Turn on flash or move your phone light closer.", "फ़्लैश चालू करें या फ़ोन की लाइट पास लाएं।", "ఫ్లాష్ ఆన్ చేయండి లేదా ఫోన్ లైట్ దగ్గరగా తీసుకురండి.")}</WBody>
    </Screen>
  );
}

// MARK: W34 Washing (W34b late)

export function WashingScreen() {
  const { store, router } = useCaptain();
  const [seconds, setSeconds] = useState(14 * 60 + 32);
  const [done, setDone] = useState<number[]>([]);
  const late = store.lateWash;
  useEffect(() => {
    if (late) return;
    const t = setInterval(() => setSeconds((s) => (s > 0 ? s - 1 : 0)), 1000);
    return () => clearInterval(t);
  }, [late]);
  const step = (i: number, icon: IconName, title: string) => {
    const on = done.includes(i);
    return (
      <Tap key={i} onClick={() => setDone(on ? done.filter((x) => x !== i) : [...done, i])}
        style={{ flex: 1, height: 112, borderRadius: 16, background: on ? C.successTint : C.canvas, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10, transition: "background .2s" }}>
        <span style={{ width: 56, height: 56, borderRadius: 28, background: on ? C.success : C.primaryTint, display: "grid", placeItems: "center" }}>
          <Icon name={on ? "check" : icon} size={23} color={on ? C.onSuccess : C.primaryStrong} weight={on ? 700 : 400} />
        </span>
        <T k="title" s={16.5}>{title}</T>
      </Tap>
    );
  };
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.current.plate} />}
      footer={<WFooter><Button title={store.t("Done washing", "धुलाई पूरी", "వాష్ పూర్తైంది")} size="captain" onClick={() => router.push({ n: "afterPhotos" })} /></WFooter>}>
      <div style={{ paddingTop: 4 }}><WashStageBar stage={1} /></div>
      <HStack style={{ paddingTop: 12, justifyContent: "flex-end", minHeight: 32 }}><OwnerNoteButton /></HStack>
      <VStack gap={8} align="center" style={{ paddingTop: 20, paddingBottom: 22 }}>
        <T k="body" s={16}>{late ? store.t("Should have finished 8:55 AM", "8:55 AM तक ख़त्म होना था", "8:55 AM కి పూర్తవ్వాలి") : store.t("Finish by 8:55 AM", "8:55 AM तक ख़त्म करें", "8:55 AM లోపు పూర్తి చేయండి")}</T>
        <span style={{ fontSize: 64, lineHeight: "72px", fontWeight: 700, fontVariantNumeric: "tabular-nums", color: late ? C.destructive : C.heading }}>{late ? "+6:10" : Fmt.clock(seconds)}</span>
        {late ? <Badge text={store.t("−₹6 so far", "अब तक −₹6", "ఇప్పటి వరకు −₹6")} tone="error" icon="clock" /> : <Badge text={store.t("On time", "समय पर", "సమయానికి")} tone="ok" icon="check" />}
      </VStack>
      <div style={{ paddingBottom: 22 }}><BookingVisual job={store.current} /></div>
      {late ? (
        <Banner tone="wait" icon="info" text={store.t("−₹1 for each late minute. Max ₹35 on this job.", "हर लेट मिनट पर −₹1। इस काम पर ज़्यादा से ज़्यादा ₹35।", "ప్రతి ఆలస్య నిమిషానికి −₹1. ఈ పనికి గరిష్టం ₹35.")} />
      ) : (
        <>
          <TD k="label" style={{ paddingBottom: 8 }}>{store.t("Steps", "कदम", "దశలు")}</TD>
          <HStack gap={10} style={{ paddingBottom: 20 }}>
            {washWater(store.current.wash) ? step(0, "bucket", store.t("Water", "पानी", "నీళ్ళు")) : step(0, "wipe", store.t("Dust", "धूल झाड़ें", "దుమ్ము దులపండి"))}
            {step(1, "wipe", store.t("Wipe", "पोंछें", "తుడవండి"))}
            {step(2, "sparkle", store.t("Dry", "सुखाएं", "ఆరబెట్టండి"))}
          </HStack>
        </>
      )}
    </Screen>
  );
}

// MARK: W36 AI photo check

export function AiCheckScreen() {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Photo check", "फ़ोटो जाँच", "ఫోటో తనిఖీ")} />}
      footer={
        <VStack align="center" style={{ background: "#fff" }}>
          <div style={{ width: "100%" }}>
            <WFooter><Button title={store.t("Wipe and retake", "पोंछें और फिर लें", "తుడిచి మళ్ళీ తీయండి")} icon="camera" size="captain" onClick={() => {
              store.aiFlag = false;
              store.afterDone = store.afterDone.filter((x) => x !== 2);
              router.swapTop({ n: "camera", after: true, side: 2 });
            }} /></WFooter>
          </div>
          <Link title={store.t("It’s clean, send anyway", "साफ़ है, फिर भी भेजें", "శుభ్రంగా ఉంది, అయినా పంపండి")} onClick={() => router.swapTop({ n: "uploading" })} style={{ marginBottom: 8 }} />
        </VStack>
      }>
      <div style={{ position: "relative", height: 198, marginTop: 8, borderRadius: 16, background: "#33445C", display: "grid", placeItems: "center" }}>
        <HStack>
          <Icon name="car" size={46} color="rgba(255,255,255,.5)" />
          <span style={{ width: 62, height: 62, marginLeft: -6, borderRadius: 31, boxShadow: `inset 0 0 0 3px ${C.star}` }} />
        </HStack>
        <div style={{ position: "absolute", top: 12, left: 12 }}><Badge text={store.t("Left mirror", "बायाँ शीशा", "ఎడమ అద్దం")} tone="wait" icon="eye" /></div>
      </div>
      <WTitle style={{ paddingTop: 22 }}>{store.t("Left mirror looks dusty", "बायाँ शीशा धूल भरा लग रहा है", "ఎడమ అద్దం దుమ్ముగా ఉంది")}</WTitle>
      <WBody style={{ paddingTop: 6 }}>{store.t("Wipe it once more and take the left photo again.", "एक बार और पोंछें और बाईं फ़ोटो फिर से लें।", "మళ్ళీ ఒకసారి తుడిచి ఎడమ ఫోటో మళ్ళీ తీయండి.")}</WBody>
    </Screen>
  );
}

// MARK: W37 Sending photos

export function UploadingScreen() {
  const { store, router } = useCaptain();
  const [progress, setProgress] = useState([1, 1, 0.5, 0.55]);
  useEffect(() => {
    let n = 0;
    const t = setInterval(() => { n += 1; setProgress((p) => p.map((x) => Math.min(1, x + 0.05))); if (n >= 20) clearInterval(t); }, 250);
    return () => clearInterval(t);
  }, []);
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Sending photos", "फ़ोटो भेज रहे हैं", "ఫోటోలు పంపుతోంది")} back={false} />}
      footer={<WFooter><Button title={store.t("Next job", "अगला काम", "తదుపరి పని")} size="captain" onClick={() => router.replace([{ n: "jobDone", late: store.lateWash }])} /></WFooter>}>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, paddingTop: 8 }}>
        {[0, 1, 2, 3].map((i) => <PhotoSlot key={i} label={sideName(store, i)} state={progress[i] >= 1 ? "done" : "uploading"} tag={store.t("After", "बाद", "తర్వాత")} tagTone="ok" height={112} />)}
      </div>
      {(store.lowSignal || progress.some((p) => p < 1)) && (
        <Banner tone="wait" icon="wifiOff" title={store.t("Weak signal.", "कमज़ोर सिग्नल।", "బలహీన సిగ్నల్.")} style={{ marginTop: 16 }}
          text={store.t("Photos are saved on your phone and will send by themselves. You can start the next job.", "फ़ोटो फ़ोन में सेव हैं और अपने आप चली जाएंगी। आप अगला काम शुरू कर सकते हैं।", "ఫోటోలు ఫోన్‌లో సేవ్ అయ్యాయి, అవే పంపబడతాయి. మీరు తదుపరి పని మొదలుపెట్టవచ్చు.")} />
      )}
    </Screen>
  );
}

// MARK: W38 Shine done (W38b late)

export function JobDoneScreen({ late }: { late: boolean }) {
  const { store, router } = useCaptain();
  const pay = store.current.pay;
  return (
    <Screen gutter={S.gutterCaptain} header={<div style={{ height: 40 }} />}
      footer={<WFooter><Button title={store.t("Next job", "अगला काम", "తదుపరి పని")} size="captain" onClick={() => {
        store.finishJob();
        store.lateWash = false;
        router.home();
        router.tab = 1;
      }} /></WFooter>}>
      <VStack gap={12} align="center">
        <div className="wh-scale-in" style={{ paddingTop: 50 }}><StateCircle icon={late ? "clock" : "sparkle"} tone={late ? "wait" : "ok"} size={112} /></div>
        <TD k="section" w={600} s={24} center>{late ? store.t("Done, 12 min late", "हो गया, 12 मिनट लेट", "పూర్తైంది, 12 నిమిషాలు ఆలస్యం") : store.t("Shine done!", "चमक गई!", "మెరిసింది!")}</TD>
        <WBody center>{late ? store.t("Try to start earlier next time.", "अगली बार जल्दी शुरू करें।", "తదుపరిసారి ముందుగా మొదలుపెట్టండి.")
          : store.t("Owner checks the photos. Money comes tonight before 12.", "मालिक फ़ोटो देखेंगे। पैसे आज रात 12 बजे से पहले आएंगे।", "యజమాని ఫోటోలు చూస్తారు. డబ్బు ఈ రాత్రి 12 లోపు వస్తుంది.")}</WBody>
        <div style={{ width: "100%", paddingTop: 14 }}>
          {late ? (
            <KeyValueCard boldLast rows={[
              [store.t("Pay", "कमाई", "చెల్లింపు"), Fmt.rupees(pay)],
              [store.t("Late 12 min", "12 मिनट लेट", "12 నిమిషాల ఆలస్యం"), "−₹12"],
              [store.t("You get", "आपको मिलेंगे", "మీకు వచ్చేది"), Fmt.rupees(pay - 12)],
            ]} />
          ) : (
            <VStack gap={6} align="center" style={card(20)}>
              <T k="caption">{store.t("This job", "यह काम", "ఈ పని")}</T>
              <T k="bigMoney" mono>{Fmt.rupees(pay)}</T>
              <Badge text={store.t("Waiting for owner", "मालिक का इंतज़ार", "యజమాని కోసం వేచి ఉంది")} tone="wait" icon="clock" />
            </VStack>
          )}
        </div>
      </VStack>
    </Screen>
  );
}
