"use client";

import { useEffect, useState } from "react";
import { C, S, toneBg, toneFg, type Tone } from "../../ds/tokens";
import {
  AppBar, Badge, Button, FullState, HStack, IconBox, Screen, SegmentBar, Segmented, StateCircle, Tap, T, TD, TextField, VStack,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { buzz } from "../../lib/device";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import { KycSteps, type StepState } from "../store";

// MARK: Testing shortcut (remove before launch)

/** Testing only: skip the videos, quiz and the rest of onboarding, straight to "You're in". */
export const ONBOARDING_SKIP = true;

export function TestSkipButton({ style }: { style?: React.CSSProperties }) {
  const { store, router } = useCaptain();
  if (!ONBOARDING_SKIP) return null;
  return (
    <Tap onClick={() => { KycSteps.forEach((s) => store.complete(s)); store.videosWatched = 3; router.replace([{ n: "live" }]); }}
      style={{ alignSelf: "center", display: "flex", alignItems: "center", gap: 6, padding: "0 14px", height: 36, borderRadius: 999, background: "#FFF4E0", border: "1px dashed #B45309", ...style }}>
      <Icon name="skip" size={13} color="#B45309" fill />
      <T k="label" s={13} c="#B45309" w={600}>TEST ONLY · Skip onboarding</T>
    </Tap>
  );
}

// MARK: W04 4 steps (W15 one thing to fix)

type Stage = "aadhaar" | "photo" | "bank" | "onboarding";

export function StepsScreen({ problem = false }: { problem?: boolean }) {
  const { store, router } = useCaptain();
  const info = (s: Stage): [IconName, string, string] => ({
    aadhaar: ["idCard", store.t("Aadhaar", "आधार", "ఆధార్"), store.t("Photo of the front and back", "आगे और पीछे की फ़ोटो", "ముందు, వెనుక ఫోటో")],
    photo: ["face", store.t("Your photo", "आपकी फ़ोटो", "మీ ఫోటో"), store.t("A quick selfie to match your Aadhaar", "आधार से मिलाने के लिए एक सेल्फ़ी", "ఆధార్‌తో సరిపోల్చడానికి ఒక సెల్ఫీ")],
    bank: ["bank", store.t("Bank or UPI", "बैंक या UPI", "బ్యాంక్ లేదా UPI"), store.t("Where your money comes every night", "जहाँ हर रात आपके पैसे आएंगे", "ప్రతి రాత్రి మీ డబ్బు వచ్చే చోటు")],
    onboarding: ["play", store.t("Onboarding", "ऑनबोर्डिंग", "ఆన్‌బోర్డింగ్"), store.t("Short training videos and a quiz", "छोटे ट्रेनिंग वीडियो और एक क्विज़", "చిన్న శిక్షణ వీడియోలు, ఒక క్విజ్")],
  } as Record<Stage, [IconName, string, string]>)[s];
  const state = (s: Stage): StepState => {
    if (problem) return s === "photo" ? "problem" : "done";
    if (s === "onboarding") return store.steps.training === "done" && store.steps.quiz === "done" ? "done" : "todo";
    return store.steps[s] ?? "todo";
  };
  const list: Stage[] = problem ? ["aadhaar", "photo", "bank"] : ["aadhaar", "photo", "bank", "onboarding"];
  const current = list.findIndex((s) => state(s) !== "done");

  const marker = (icon: IconName, st: StepState, isCurrent: boolean) => {
    if (st === "done") return <span style={{ width: 48, height: 48, borderRadius: 24, background: C.success, display: "grid", placeItems: "center" }}><Icon name="check" size={20} color={C.onSuccess} weight={700} /></span>;
    if (st === "problem") return <span style={{ width: 48, height: 48, borderRadius: 24, background: C.errorTint, display: "grid", placeItems: "center" }}><Icon name="warning" size={20} color={C.destructive} /></span>;
    return (
      <span style={{ width: 48, height: 48, borderRadius: 24, background: isCurrent ? C.primary : C.canvas, boxShadow: isCurrent ? undefined : `inset 0 0 0 1.5px ${C.border}`, display: "grid", placeItems: "center" }}>
        <Icon name={icon} size={21} color={isCurrent ? "#fff" : C.secondary} />
      </span>
    );
  };

  const go = () => {
    switch (store.nextStep) {
      case "aadhaar": router.push({ n: "aadhaar", unclear: false }); break;
      case "photo": router.push({ n: "selfie" }); break;
      case "bank": router.push({ n: "bank" }); break;
      case "training": router.push({ n: "training" }); break;
      case "quiz": router.push({ n: "quiz" }); break;
      default: router.push({ n: "rules" });
    }
  };

  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Quick KYC", "छोटा KYC", "చిన్న KYC")} back={!problem} />}
      footer={<WFooter>{problem
        ? <Button title={store.t("Take photo again", "फिर से फ़ोटो लें", "మళ్ళీ ఫోటో తీయండి")} icon="camera" size="captain" onClick={() => router.push({ n: "selfie" })} />
        : <Button title={store.stepsDone === 0 ? store.t("Start", "शुरू करें", "ప్రారంభించండి") : store.t("Continue", "जारी रखें", "కొనసాగించండి")} size="captain" onClick={go} />}</WFooter>}>
      {store.kycFromJob && !problem && (
        <HStack align="start" gap={12} style={{ padding: 16, borderRadius: 14, background: C.waitTint, marginTop: 10 }}>
          <Icon name="lock" size={18} color={C.waitText} />
          <TD k="caption" c={C.waitText} s={14.5}>{store.t("To accept jobs, finish these steps once. Owners only let verified captains in.", "काम लेने के लिए ये कदम एक बार पूरे करें। मालिक सिर्फ़ जाँचे गए कैप्टन को अंदर आने देते हैं।", "పనులు తీసుకోవడానికి ఈ దశలు ఒక్కసారి పూర్తి చేయండి. యజమానులు ధృవీకరించిన కెప్టెన్లనే అనుమతిస్తారు.")}</TD>
        </HStack>
      )}
      {problem ? (
        <>
          <WTitle style={{ paddingTop: 10 }}>{store.t("1 thing to fix", "1 चीज़ ठीक करें", "1 విషయం సరిచేయండి")}</WTitle>
          <WBody style={{ paddingTop: 6, paddingBottom: 26 }}>{store.t("We couldn’t match your selfie with Aadhaar.", "आपकी सेल्फ़ी आधार से मेल नहीं खाई।", "మీ సెల్ఫీ ఆధార్‌తో సరిపోలలేదు.")}</WBody>
        </>
      ) : (
        <>
          <WTitle style={{ paddingTop: 14 }}>{store.t("4 steps to take jobs", "काम लेने के 4 कदम", "పనులు తీసుకోవడానికి 4 దశలు")}</WTitle>
          <WBody style={{ paddingTop: 6, paddingBottom: 26 }}>{store.t("Here’s what comes next. We’ll take you through each one.", "आगे यह होगा। हम हर कदम में आपकी मदद करेंगे।", "తర్వాత ఇవి ఉంటాయి. ప్రతి దశలో మేము మీకు సహాయం చేస్తాము.")}</WBody>
        </>
      )}
      <VStack>
        {list.map((s, i) => {
          const [icon, title, sub] = info(s);
          const st = state(s);
          return (
            <HStack key={s} align="stretch" gap={16}>
              <VStack align="center">
                {marker(icon, st, i === current)}
                {i < list.length - 1 && <div style={{ width: 2, flex: 1, minHeight: 34, background: st === "done" ? C.success : C.border }} />}
              </VStack>
              <VStack gap={4} style={{ paddingTop: 2, paddingBottom: 22, flex: 1 }}>
                <T k="label" c={C.secondary}>{`${store.t("Step", "कदम", "దశ")} ${i + 1}`}</T>
                <TD k="title" s={19} c={i === current || st === "problem" ? C.heading : C.secondary} w={i === current ? 600 : 500}>{title}</TD>
                <TD k="caption" s={14.5}>{sub}</TD>
              </VStack>
            </HStack>
          );
        })}
      </VStack>
      {!problem && <TestSkipButton style={{ marginTop: 4 }} />}
    </Screen>
  );
}

// MARK: W05 Aadhaar (W05b photo not clear)

export function AadhaarScreen({ unclear = false }: { unclear?: boolean }) {
  const { store, router } = useCaptain();
  const done = () => { store.complete("aadhaar"); router.replace([{ n: "steps", problem: false }]); };
  const tip = (icon: IconName, text: string) => (
    <HStack gap={12}><Icon name={icon} size={18} color={C.primaryStrong} /><T k="bodyStrong" c={C.heading} s={16.5}>{text}</T></HStack>
  );
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Aadhaar", "आधार", "ఆధార్")} />}
      footer={<WFooter>{unclear
        ? <Button title={store.t("Take again", "फिर से लें", "మళ్ళీ తీయండి")} icon="camera" size="captain" onClick={done} />
        : <Button title={store.t("Open DigiLocker", "DigiLocker खोलें", "DigiLocker తెరవండి")} size="captain" onClick={done} />}</WFooter>}>
      <div style={{ paddingTop: 6 }}><SegmentBar filled={1} total={5} /></div>
      {unclear ? (
        <>
          <WTitle style={{ paddingTop: 22, paddingBottom: 16 }}>{store.t("Photo is not clear", "फ़ोटो साफ़ नहीं है", "ఫోటో స్పష్టంగా లేదు")}</WTitle>
          <div style={{ position: "relative", height: 178, borderRadius: 12, background: C.photo, boxShadow: `inset 0 0 0 2px ${C.destructive}`, display: "grid", placeItems: "center" }}>
            <Icon name="idCard" size={42} color={C.secondary} />
            <div style={{ position: "absolute", top: 12, left: 12 }}><Badge text={store.t("Blurry", "धुंधली", "అస్పష్టం")} tone="error" icon="close" /></div>
          </div>
          <VStack gap={14} style={{ paddingTop: 22 }}>
            {tip("sun", store.t("Stand in light", "रोशनी में खड़े हों", "వెలుతురులో నిలబడండి"))}
            {tip("idCard", store.t("All 4 corners inside", "चारों कोने अंदर हों", "నాలుగు మూలలు లోపల ఉండాలి"))}
            {tip("close", store.t("No finger on the card", "कार्ड पर उंगली न हो", "కార్డుపై వేలు ఉండకూడదు"))}
          </VStack>
        </>
      ) : (
        <>
          <Icon name="idCard" size={28} color={C.primaryStrong} style={{ marginTop: 22 }} />
          <WTitle style={{ paddingTop: 8 }}>{store.t("Verify Aadhaar", "आधार सत्यापित करें", "ఆధార్ ధృవీకరించండి")}</WTitle>
          <WBody style={{ paddingTop: 4, paddingBottom: 18 }}>{store.t("Fastest with DigiLocker. Takes 1 minute.", "DigiLocker से सबसे जल्दी। 1 मिनट लगेगा।", "DigiLocker తో వేగంగా. 1 నిమిషం పడుతుంది.")}</WBody>
          <HStack gap={12} style={{ padding: 16, borderRadius: 14, background: C.canvas }}>
            <Icon name="shield" size={18} />
            <T k="caption" c={C.heading} s={14.5}>{store.t("We only see your name, photo and age.", "हम सिर्फ़ आपका नाम, फ़ोटो और उम्र देखते हैं।", "మేము మీ పేరు, ఫోటో, వయసు మాత్రమే చూస్తాము.")}</T>
          </HStack>
          <Button title={store.t("Upload Aadhaar photo instead", "आधार की फ़ोटो अपलोड करें", "ఆధార్ ఫోటో అప్‌లోడ్ చేయండి")} kind="text" fullWidth={false} style={{ marginTop: 14, alignSelf: "flex-start" }}
            onClick={() => router.push({ n: "aadhaar", unclear: true })} />
        </>
      )}
    </Screen>
  );
}

// MARK: W06 Your photo (selfie)

export function SelfieScreen() {
  const { store, router } = useCaptain();
  return (
    <div className="wh-fill" style={{ background: C.camera, paddingTop: "var(--sat)", paddingBottom: "var(--sab)", alignItems: "center" }}>
      <AppBar title={store.t("Your photo", "आपकी फ़ोटो", "మీ ఫోటో")} trailing={null} dark onLeading={() => router.pop()} style={{ padding: "0 4px", width: "100%" }} />
      <div style={{ flex: 1 }} />
      <div style={{ position: "relative", width: 226, height: 296, borderRadius: "50%", border: "3px dashed #fff", display: "grid", placeItems: "center" }}>
        <Icon name="face" size={60} color="rgba(255,255,255,.85)" />
      </div>
      <div style={{ flex: 1 }} />
      <TD k="value" c="#fff" s={16.5} center style={{ padding: "0 20px" }}>{store.t("Face inside the oval. No cap, no mask.", "चेहरा ओवल के अंदर। टोपी या मास्क नहीं।", "ముఖం ఓవల్ లోపల. టోపీ, మాస్క్ వద్దు.")}</TD>
      <div style={{ padding: "22px 0" }}>
        <Tap label="Take photo" onClick={() => { store.complete("photo"); router.replace([{ n: "steps", problem: false }]); }}
          style={{ width: 84, height: 84, borderRadius: 42, boxShadow: "inset 0 0 0 5px #fff", display: "grid", placeItems: "center" }}>
          <span style={{ width: 66, height: 66, borderRadius: 33, background: "#fff" }} />
        </Tap>
      </div>
    </div>
  );
}

// MARK: W07 Get paid (bank or UPI)

export function BankScreen() {
  const { store, router } = useCaptain();
  const [mode, setMode] = useState(0);
  const [upi, setUpi] = useState("raju.yadav@ybl");
  const [account, setAccount] = useState("");
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Get paid", "पैसे पाएं", "డబ్బు పొందండి")} />}
      footer={<WFooter><Button title={store.t("Save", "सेव करें", "సేవ్ చేయండి")} size="captain" enabled={mode === 0 ? upi.includes("@") : account.length >= 9}
        onClick={() => { store.upi = upi; store.complete("bank"); router.replace([{ n: "steps", problem: false }]); }} /></WFooter>}>
      <div style={{ paddingTop: 6 }}><SegmentBar filled={3} total={5} /></div>
      <Icon name="rupee" size={26} color={C.primaryStrong} style={{ marginTop: 22 }} />
      <WTitle style={{ paddingTop: 8, paddingBottom: 18 }}>{store.t("Where should we send money?", "पैसे कहाँ भेजें?", "డబ్బు ఎక్కడికి పంపాలి?")}</WTitle>
      <div style={{ paddingBottom: 22 }}><Segmented options={["UPI", store.t("Bank account", "बैंक खाता", "బ్యాంక్ ఖాతా")]} selection={mode} onChange={setMode} height={54} /></div>
      {mode === 0 ? (
        <>
          <TextField label="UPI ID" value={upi} onChange={setUpi} placeholder="name@bank" large />
          {upi.includes("@") && (
            <HStack gap={10} style={{ padding: "0 16px", height: 46, borderRadius: 12, background: C.successTint, marginTop: 20 }}>
              <Icon name="check" size={16} color={C.onSuccess} />
              <T k="caption" c={C.onSuccess} s={14.5}>{store.t("Name matches: ", "नाम मिलता है: ", "పేరు సరిపోయింది: ")}<b>RAJU YADAV</b></T>
            </HStack>
          )}
        </>
      ) : (
        <TextField label={store.t("Account number", "खाता नंबर", "ఖాతా నంబర్")} value={account} onChange={setAccount} placeholder="0000 0000 0000" inputMode="numeric" large />
      )}
    </Screen>
  );
}

// MARK: W08 Training videos

export function TrainingScreen() {
  const { store, router } = useCaptain();
  const videos: [string, string][] = [
    [store.t("Car wash: step by step", "कार धुलाई: एक-एक कदम", "కార్ వాష్: దశలవారీగా"), "4 min"],
    [store.t("Bike wash", "बाइक धुलाई", "బైక్ వాష్"), "3 min"],
    [store.t("Do’s and don’ts", "क्या करें, क्या नहीं", "చేయాల్సినవి, చేయకూడనివి"), "2 min"],
  ];
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Training", "ट्रेनिंग", "శిక్షణ")} subtitle={store.langName} />}
      footer={<WFooter>{store.videosWatched >= 3
        ? <Button title={store.t("Start quiz", "क्विज़ शुरू करें", "క్విజ్ ప్రారంభించండి")} size="captain" onClick={() => { store.complete("training"); router.push({ n: "quiz" }); }} />
        : <Button title={store.t("Watch next", "अगला देखें", "తదుపరి చూడండి")} icon="play" size="captain" onClick={() => router.push({ n: "video", index: store.videosWatched })} />}</WFooter>}>
      <div style={{ paddingTop: 6 }}><SegmentBar filled={4} total={5} /></div>
      <WTitle style={{ paddingTop: 20 }}>{store.t("Watch 3 short videos", "3 छोटे वीडियो देखें", "3 చిన్న వీడియోలు చూడండి")}</WTitle>
      <WBody style={{ paddingTop: 4, paddingBottom: 18 }}>{store.t("Then a 2-minute quiz.", "फिर 2 मिनट का क्विज़।", "తర్వాత 2 నిమిషాల క్విజ్.")}</WBody>
      <VStack gap={12}>
        {videos.map(([title, len], i) => (
          <Tap key={i} onClick={() => { if (i <= store.videosWatched) router.push({ n: "video", index: i }); }}
            style={{ display: "flex", alignItems: "center", gap: 14, padding: 10, borderRadius: 14, background: "#fff", boxShadow: `inset 0 0 0 1px ${C.border}`, textAlign: "left" }}>
            <span style={{ width: 96, height: 64, borderRadius: 8, background: C.inverse, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="play" size={22} color="#fff" fill /></span>
            <VStack gap={2} style={{ flex: 1 }}>
              <TD k="title" s={16.5}>{title}</TD>
              <TD k="caption">{len}</TD>
            </VStack>
            {i < store.videosWatched ? (
              <span style={{ width: 32, height: 32, borderRadius: 16, background: C.success, display: "grid", placeItems: "center" }}><Icon name="check" size={15} color={C.onSuccess} weight={700} /></span>
            ) : i === store.videosWatched ? (
              <Badge text={store.t("Watch", "देखें", "చూడండి")} tone="info" icon="check" />
            ) : (
              <span style={{ width: 32, height: 32, borderRadius: 16, boxShadow: `inset 0 0 0 1px ${C.muted}`, display: "grid", placeItems: "center" }}><Icon name="lock" size={14} color={C.muted} /></span>
            )}
          </Tap>
        ))}
      </VStack>
      <TestSkipButton style={{ marginTop: 20 }} />
    </Screen>
  );
}

// MARK: W09 Video player

export function VideoScreen({ index }: { index: number }) {
  const { store, router } = useCaptain();
  const [progress, setProgress] = useState(0);
  const [playing, setPlaying] = useState(true);
  const titles = [store.t("Car wash", "कार धुलाई", "కార్ వాష్"), store.t("Bike wash", "बाइक धुलाई", "బైక్ వాష్"), store.t("Do’s and don’ts", "क्या करें, क्या नहीं", "చేయాల్సినవి")];
  useEffect(() => {
    // Demo: a 6-second stand-in for the YouTube player (official player only, never downloaded).
    if (!playing) return;
    const t = setInterval(() => setProgress((p) => Math.min(1, p + 1 / 60)), 100);
    return () => clearInterval(t);
  }, [playing]);
  const point = (icon: IconName, text: string) => (
    <HStack gap={14}><IconBox icon={icon} size={40} radius={20} /><T k="bodyStrong" c={C.heading} s={16.5}>{text}</T></HStack>
  );
  return (
    <Screen gutter={0} header={<WHeader title={titles[Math.min(index, 2)]} />}
      footer={<WFooter><Button title={store.t("Next video", "अगला वीडियो", "తదుపరి వీడియో")} size="captain" enabled={progress >= 1}
        onClick={() => { store.videosWatched = Math.max(store.videosWatched, index + 1); router.pop(); }} /></WFooter>}>
      <div style={{ position: "relative", height: 202, background: C.camera, display: "grid", placeItems: "center" }}>
        <Tap onClick={() => setPlaying(!playing)} label={playing ? "Pause" : "Play"} style={{ width: 72, height: 72, borderRadius: 36, background: "rgba(255,255,255,.18)", display: "grid", placeItems: "center" }}>
          <Icon name={playing ? "pause" : "play"} size={28} color="#fff" fill />
        </Tap>
        <div style={{ position: "absolute", left: 12, right: 12, bottom: 14, height: 4, borderRadius: 4, background: "rgba(255,255,255,.3)" }}>
          <div style={{ height: 4, borderRadius: 4, width: `${progress * 100}%`, background: C.primary }} />
        </div>
      </div>
      <VStack gap={14} style={{ padding: 16 }}>
        <TD k="section" w={600}>{store.t("In this video", "इस वीडियो में", "ఈ వీడియోలో")}</TD>
        {point("bucket", store.t("Clean water, clean bucket", "साफ़ पानी, साफ़ बाल्टी", "శుభ్రమైన నీరు, శుభ్రమైన బకెట్"))}
        {point("wipe", store.t("Wet cloth first, then dry", "पहले गीला कपड़ा, फिर सूखा", "ముందు తడి గుడ్డ, తర్వాత పొడి"))}
        {point("close", store.t("Never wipe a dry, dusty bike", "सूखी, धूल भरी बाइक कभी न पोंछें", "పొడి, దుమ్ము బైక్‌ను ఎప్పుడూ తుడవకండి"))}
        <TD k="caption" style={{ paddingTop: 4 }}>{store.t("Must watch till the end. You can’t skip.", "आख़िर तक देखना ज़रूरी है। छोड़ नहीं सकते।", "చివరి వరకు చూడాలి. దాటవేయలేరు.")}</TD>
        <TestSkipButton style={{ marginTop: 8 }} />
      </VStack>
    </Screen>
  );
}

// MARK: W10 Quiz

type Opt = [string, string, string, IconName];
type Q = { text: [string, string, string]; a: Opt; b: Opt; right: number };
const QUESTIONS: Q[] = [
  { text: ["Where do you take before photos?", "पहले की फ़ोटो कहाँ लेते हैं?", "ముందు ఫోటోలు ఎక్కడ తీస్తారు?"], a: ["At the vehicle", "गाड़ी के पास", "వాహనం దగ్గర", "car"], b: ["At home", "घर पर", "ఇంట్లో", "home"], right: 0 },
  { text: ["The bike is dusty. What do you do first?", "बाइक पर धूल है। पहले क्या करेंगे?", "బైక్ దుమ్ముగా ఉంది. ముందు ఏం చేస్తారు?"], a: ["Pour water", "पानी डालें", "నీళ్ళు పోయండి", "drop"], b: ["Wipe with dry cloth", "सूखे कपड़े से पोंछें", "పొడి గుడ్డతో తుడవండి", "wipe"], right: 0 },
  { text: ["Can you use soap?", "क्या साबुन लगा सकते हैं?", "సబ్బు వాడవచ్చా?"], a: ["Yes", "हाँ", "అవును", "check"], b: ["No, water only", "नहीं, सिर्फ़ पानी", "లేదు, నీళ్ళు మాత్రమే", "bucket"], right: 1 },
  { text: ["Owner wants to pay cash. You…", "मालिक नकद देना चाहे तो…", "యజమాని నగదు ఇవ్వాలనుకుంటే…"], a: ["Say no, app only", "मना करें, सिर्फ़ ऐप", "వద్దు అనండి, యాప్ మాత్రమే", "ban"], b: ["Take it", "ले लें", "తీసుకోండి", "rupee"], right: 0 },
  { text: ["You’ll be 10 minutes late. You…", "आप 10 मिनट लेट होंगे तो…", "మీరు 10 నిమిషాలు ఆలస్యం అయితే…"], a: ["Tell the app", "ऐप में बताएं", "యాప్‌లో చెప్పండి", "phone"], b: ["Say nothing", "कुछ न कहें", "ఏమీ చెప్పకండి", "close"], right: 0 },
];

export function QuizScreen() {
  const { store, router } = useCaptain();
  const [q, setQ] = useState(0);
  const [pick, setPick] = useState<number | null>(null);
  const [correct, setCorrect] = useState(0);
  const cur = QUESTIONS[q];
  const tr = (x: [string, string, string] | Opt) => store.t(x[0], x[1], x[2]);

  /** Once answered, the choice locks: the right option turns green, a wrong pick turns red. */
  const option = (i: number, o: Opt) => {
    const answered = pick != null, isRight = i === cur.right, picked = pick === i;
    const tone = !answered ? C.border : isRight ? C.success : picked ? C.destructive : C.border;
    const fill = !answered ? "#fff" : isRight ? C.successTint : picked ? C.errorTint : "#fff";
    return (
      <Tap key={i} disabled={answered && !picked && !isRight} onClick={() => { if (pick != null) return; setPick(i); buzz(isRight ? 20 : [40, 30, 40]); }}
        style={{ position: "relative", flex: 1, height: 142, borderRadius: 16, background: fill, boxShadow: `inset 0 0 0 ${answered && (isRight || picked) ? 3 : 1}px ${tone}`,
          display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12, opacity: answered && !isRight && !picked ? 0.55 : 1, transition: "background .25s, box-shadow .25s" }}>
        <span style={{ width: 60, height: 60, borderRadius: 30, background: answered ? "#fff" : C.primaryTint, display: "grid", placeItems: "center" }}><Icon name={o[3]} size={26} color={C.primaryStrong} /></span>
        <TD k="title" s={16} center>{tr(o)}</TD>
        {answered && (isRight || picked) && (
          <span className="wh-scale-in" style={{ position: "absolute", top: 10, right: 10, width: 28, height: 28, borderRadius: 14, background: isRight ? C.success : C.destructive, display: "grid", placeItems: "center" }}>
            <Icon name={isRight ? "check" : "close"} size={14} color="#fff" weight={700} />
          </span>
        )}
      </Tap>
    );
  };

  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Quiz", "क्विज़", "క్విజ్")} subtitle={store.t(`Question ${q + 1} of 5`, `प्रश्न ${q + 1} / 5`, `ప్రశ్న ${q + 1} / 5`)} />}
      footer={<WFooter><Button title={store.t("Next", "आगे", "తదుపరి")} size="captain" enabled={pick != null} onClick={() => {
        const c = correct + (pick === cur.right ? 1 : 0);
        setCorrect(c);
        if (q < 4) { setQ(q + 1); setPick(null); }
        else { const passed = c >= 4; if (passed) store.complete("quiz"); router.push({ n: "quizResult", passed }); }
      }} /></WFooter>}>
      <div style={{ paddingTop: 6 }}><SegmentBar filled={q + 1} total={5} /></div>
      <HStack align="start" gap={14} style={{ paddingTop: 20, paddingBottom: 18 }}>
        <IconBox icon="refresh" size={52} radius={26} />
        <TD k="section" w={600} s={20} style={{ flex: 1 }}>{tr(cur.text)}</TD>
      </HStack>
      <HStack gap={12}>{option(0, cur.a)}{option(1, cur.b)}</HStack>
      {pick != null && (() => {
        const ok = pick === cur.right;
        const rightText = tr(cur.right === 0 ? cur.a : cur.b);
        return (
          <HStack align="start" gap={12} className="wh-slide-up" style={{ padding: 16, borderRadius: 14, background: ok ? C.successTint : C.errorTint, marginTop: 16 }}>
            <Icon name={ok ? "checkCircle" : "warning"} size={22} color={ok ? C.success : C.destructive} />
            <VStack gap={3}>
              <TD k="title" s={17} c={ok ? C.onSuccess : C.destructive}>{ok ? store.t("Correct!", "सही जवाब!", "సరైన జవాబు!") : store.t("Not quite", "सही नहीं", "సరైనది కాదు")}</TD>
              {!ok && <TD k="body" c={C.heading}>{store.t(`The right answer is: ${rightText}`, `सही जवाब है: ${rightText}`, `సరైన జవాబు: ${rightText}`)}</TD>}
            </VStack>
          </HStack>
        );
      })()}
      {pick == null && (
        <VStack gap={8} align="center" style={{ paddingTop: 16 }}>
          <Tap label="Say your answer" style={{ width: 80, height: 80, borderRadius: 40, background: C.primary, display: "grid", placeItems: "center" }}><Icon name="mic" size={30} color="#fff" /></Tap>
          <T k="caption">{store.t("Or tap and say your answer", "या टैप करके जवाब बोलें", "లేదా నొక్కి జవాబు చెప్పండి")}</T>
        </VStack>
      )}
      <TestSkipButton style={{ marginTop: 20 }} />
    </Screen>
  );
}

// MARK: W11 Passed (W11b failed)

export function QuizResultScreen({ passed }: { passed: boolean }) {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}
      footer={passed ? <WFooter><Button title={store.t("See the rules", "नियम देखें", "నియమాలు చూడండి")} size="captain" onClick={() => router.push({ n: "rules" })} /></WFooter> : undefined}>
      {passed ? (
        <FullState icon="check" tone="ok" title={store.t("Passed! 5 of 5", "पास! 5 में से 5", "పాస్! 5 లో 5")} captain
          message={store.t("Next: the rules. Then we verify you.", "आगे: नियम। फिर हम आपकी जाँच करेंगे।", "తర్వాత: నియమాలు. ఆపై మిమ్మల్ని ధృవీకరిస్తాము.")} />
      ) : (
        <FullState icon="refresh" tone="wait" title={store.t("3 of 5. Almost!", "5 में से 3. लगभग!", "5 లో 3. దాదాపు!")} captain
          message={store.t("Watch the bike video again, then try the quiz once more.", "बाइक वाला वीडियो फिर देखें, फिर दोबारा क्विज़ दें।", "బైక్ వీడియో మళ్ళీ చూసి, మళ్ళీ క్విజ్ ప్రయత్నించండి.")}
          primary={store.t("Watch again", "फिर से देखें", "మళ్ళీ చూడండి")} primaryIcon="play" onPrimary={() => router.replace([{ n: "video", index: 1 }])} />
      )}
    </Screen>
  );
}

// MARK: W12 Rules

export function RulesScreen() {
  const { store, router } = useCaptain();
  const rule = (icon: IconName, big: string, tone: Tone, text: string) => (
    <HStack gap={14} style={{ padding: 14, borderRadius: 14, background: toneBg[tone] }}>
      <Icon name={icon} size={23} color={tone === "ok" ? C.heading : toneFg[tone]} />
      <T k="section" w={700} c={tone === "error" ? C.destructive : tone === "info" ? C.primaryStrong : C.heading} style={{ width: 70, flexShrink: 0 }}>{big}</T>
      <TD k="caption" c={C.heading} s={14.5} style={{ flex: 1 }}>{text}</TD>
    </HStack>
  );
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Rules", "नियम", "నియమాలు")} />}
      footer={<WFooter><Button title={store.t("I agree", "मैं सहमत हूँ", "నేను అంగీకరిస్తున్నాను")} icon="check" size="captain" onClick={() => router.push({ n: "underReview" })} /></WFooter>}>
      <WTitle style={{ paddingTop: 10, paddingBottom: 14 }}>{store.t("How you earn here", "यहाँ कमाई कैसे होती है", "ఇక్కడ ఎలా సంపాదిస్తారు")}</WTitle>
      <VStack gap={10}>
        {rule("rupee", "₹116", "ok", store.t("Your pay for a hatchback. Shown before you accept.", "हैचबैक के लिए आपकी कमाई। स्वीकार करने से पहले दिखेगी।", "హ్యాచ్‌బ్యాక్‌కు మీ సంపాదన. అంగీకరించే ముందు చూపిస్తాము."))}
        {rule("clock", "12 AM", "ok", store.t("Paid to UPI the same night, after the owner approves", "मालिक के मंज़ूर करने के बाद उसी रात UPI में", "యజమాని ఆమోదించాక అదే రాత్రి UPI కి"))}
        {rule("star", "4★+", "info", store.t("Every wash must get 4 stars or more", "हर धुलाई पर 4 या ज़्यादा स्टार चाहिए", "ప్రతి వాష్‌కి 4 లేదా ఎక్కువ స్టార్లు రావాలి"))}
        {rule("stopwatch", "−₹1", "error", store.t("For every minute late. Max 30% of pay.", "हर मिनट देरी पर। ज़्यादा से ज़्यादा 30%।", "ప్రతి నిమిషం ఆలస్యానికి. గరిష్టం 30%."))}
        {rule("ban", store.t("Out", "बाहर", "తొలగింపు"), "error", store.t("Damage on purpose or taking customers outside the app", "जानबूझकर नुकसान या ग्राहक को ऐप से बाहर ले जाना", "కావాలని నష్టం లేదా కస్టమర్‌ను యాప్ బయటకు తీసుకెళ్ళడం"))}
      </VStack>
    </Screen>
  );
}

// MARK: W13 Under review (video call)

export function UnderReviewScreen() {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false} header={<WHeader title={store.t("Get ready", "तैयार हो जाइए", "సిద్ధం అవ్వండి")} back={false} />}
      footer={<WFooter><Button title={store.t("Change time", "समय बदलें", "సమయం మార్చండి")} kind="outline" size="captain" /></WFooter>}>
      <VStack gap={16} align="center" style={{ flex: 1, justifyContent: "center" }}>
        <StateCircle icon="phone" size={112} />
        <TD k="section" w={600} s={23} center>{store.t("We’ll call you today", "हम आज आपको कॉल करेंगे", "మేము ఈరోజు మీకు కాల్ చేస్తాము")}</TD>
        <WBody center>{store.t("A 10-minute video call to check your documents. Keep your Aadhaar ready.", "दस्तावेज़ जाँचने के लिए 10 मिनट की वीडियो कॉल। आधार तैयार रखें।", "మీ పత్రాలు చూడటానికి 10 నిమిషాల వీడియో కాల్. ఆధార్ సిద్ధంగా ఉంచుకోండి.")}</WBody>
        <div style={{ width: "100%", height: 54, borderRadius: 14, background: C.canvas, display: "grid", placeItems: "center" }}>
          <T k="section" w={600}>{store.t("Today, 3 – 5 PM", "आज, 3 – 5 PM", "ఈరోజు, 3 – 5 PM")}</T>
        </div>
        <Tap onClick={() => router.replace([{ n: "live" }])}><T k="caption" c={C.muted}>Demo: call done →</T></Tap>
      </VStack>
    </Screen>
  );
}

// MARK: W14 You're in

export function LiveScreen() {
  const { store, router } = useCaptain();
  const dayTile = (big: string, small: string) => (
    <VStack gap={6} align="center" style={{ flex: 1, height: 104, justifyContent: "center", borderRadius: 14, background: C.primaryTint }}>
      <Icon name="calendar" size={21} color={C.primaryStrong} />
      <T k="section" w={600}>{big}</T>
      <T k="caption">{small}</T>
    </VStack>
  );
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}
      footer={<WFooter><Button title={store.t("Go to home", "होम पर जाएं", "హోమ్‌కి వెళ్ళండి")} size="captain" onClick={() => { store.finishKyc(); router.home(); }} /></WFooter>}>
      <VStack gap={16} align="center" style={{ flex: 1, justifyContent: "center" }}>
        <div className="wh-scale-in"><StateCircle icon="sparkle" tone="ok" size={112} /></div>
        <TD k="section" w={600} s={23} center>{store.t(`You’re in, ${store.firstName}!`, `आप जुड़ गए, ${store.firstName}!`, `మీరు చేరారు, ${store.firstName}!`)}</TD>
        <WBody center>{store.t("First 3 days you get fewer jobs. Good ratings unlock more.", "पहले 3 दिन कम काम मिलेंगे। अच्छी रेटिंग से ज़्यादा।", "మొదటి 3 రోజులు తక్కువ పనులు. మంచి రేటింగ్‌తో ఎక్కువ.")}</WBody>
        <HStack gap={10} style={{ width: "100%", paddingTop: 6 }}>
          {dayTile(store.t("2 jobs", "2 काम", "2 పనులు"), store.t("Day 1", "दिन 1", "రోజు 1"))}
          {dayTile(store.t("4 jobs", "4 काम", "4 పనులు"), store.t("Day 2", "दिन 2", "రోజు 2"))}
          {dayTile("6 – 8", store.t("Day 3 on", "दिन 3 से", "రోజు 3 నుండి"))}
        </HStack>
      </VStack>
    </Screen>
  );
}
