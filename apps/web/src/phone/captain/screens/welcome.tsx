"use client";

import { useEffect, useState } from "react";
import { Brand, C, S } from "../../ds/tokens";
import { Button, HStack, Link, OtpField, PhoneField, Radio, Screen, StateCircle, Tap, T, TD, TextField, VStack } from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt, Validators } from "../../lib/fmt";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import type { Lang } from "../store";

// MARK: W01 Choose your language

export function LangTile({ lang, glyph, title, height = 78, onPick }: { lang: Lang; glyph: string; title: string; height?: number; onPick?: () => void }) {
  const { store } = useCaptain();
  const on = store.lang === lang;
  return (
    <Tap onClick={() => { store.lang = lang; onPick?.(); }} style={{
      display: "flex", alignItems: "center", gap: 18, padding: "0 18px", height, width: "100%", borderRadius: 16,
      background: on ? C.primaryTint : "#fff", boxShadow: `inset 0 0 0 ${on ? 2 : 1}px ${on ? C.primary : C.border}`,
    }}>
      <T k="screen" s={24} style={{ width: 40, textAlign: "center" }}>{glyph}</T>
      <T k="value" s={18} style={{ flex: 1, textAlign: "left" }}>{title}</T>
      <Radio on={on} />
    </Tap>
  );
}

export function LanguageScreen() {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} footer={<WFooter><Button title={store.t("Next", "आगे", "తదుపరి")} size="captain" onClick={() => router.push({ n: "welcome" })} /></WFooter>}>
      <HStack gap={10} style={{ paddingTop: 24 }}>
        <span style={{ width: 32, height: 32, borderRadius: 8, background: C.primary, display: "grid", placeItems: "center" }}>
          <span style={{ width: 18, height: 18, borderRadius: 9, boxShadow: "inset 0 0 0 3px #fff", display: "grid", placeItems: "center" }}><span style={{ width: 6, height: 6, borderRadius: 3, background: "#fff" }} /></span>
        </span>
        <T k="screen" s={25}>{Brand.name}</T>
      </HStack>
      <Icon name="translate" size={26} color={C.primaryStrong} style={{ marginTop: 26 }} />
      <WTitle style={{ paddingTop: 8 }}>Choose your language</WTitle>
      <TD k="caption" style={{ paddingTop: 2, paddingBottom: 20 }}>भाषा चुनें · భాష ఎంచుకోండి</TD>
      <VStack gap={12}>
        <LangTile lang="en" glyph="A" title="English" />
        <LangTile lang="hi" glyph="अ" title="हिन्दी · Hindi" />
        <LangTile lang="te" glyph="అ" title="తెలుగు · Telugu" />
      </VStack>
    </Screen>
  );
}

// MARK: W00 Welcome: three slides, one idea each

const SLIDE_SECONDS = 3.5;
type ArtKind = "freedom" | "nearHome" | "evening";

/** Big picture, two short lines, a quiet "Next". The dots double as the timer. */
export function WelcomeScreen() {
  const { store, router } = useCaptain();
  const [index, setIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const slides: { art: ArtKind; title: string; line: string }[] = [
    { art: "freedom", title: store.t("Work when you want", "जब चाहें, काम करें", "మీకు నచ్చినప్పుడు పని"), line: store.t("Morning, evening or both. You decide.", "सुबह, शाम या दोनों। आप तय करें।", "ఉదయం, సాయంత్రం లేదా రెండూ. మీ ఇష్టం.") },
    { art: "nearHome", title: store.t("Jobs near your home", "घर के पास काम", "ఇంటి దగ్గరే పని"), line: store.t("Cars parked in buildings close to you.", "आपके पास की बिल्डिंग में खड़ी गाड़ियाँ।", "మీ దగ్గరి భవనాల్లో పార్క్ చేసిన కార్లు.") },
    { art: "evening", title: store.t("Paid every night", "हर रात पैसे", "ప్రతి రాత్రి డబ్బు"), line: store.t("Straight to your UPI. No waiting.", "सीधे आपके UPI में। कोई इंतज़ार नहीं।", "నేరుగా మీ UPI కి. ఎదురుచూపు లేదు.") },
  ];
  const slide = slides[index];

  useEffect(() => {
    // Fill the current dot, then move on (the last slide waits for Next).
    setProgress(0);
    const started = Date.now();
    const t = setInterval(() => {
      const p = Math.min(1, (Date.now() - started) / (SLIDE_SECONDS * 1000));
      setProgress(p);
      if (p >= 1) {
        clearInterval(t);
        setIndex((i) => (i < 2 ? i + 1 : i));
      }
    }, 60);
    return () => clearInterval(t);
  }, [index]);

  const enterApp = () => { store.exploring = true; router.home(); };
  const next = () => (index < 2 ? setIndex(index + 1) : enterApp());

  return (
    <div className="wh-fill" style={{ background: "#fff", paddingTop: "var(--sat)", paddingBottom: "calc(12px + var(--sab))" }}>
      <HStack style={{ height: 44, padding: `0 ${S.gutterCaptain}px` }}>
        {index > 0 && (
          <Tap onClick={() => setIndex(index - 1)} className="wh-fade-in" style={{ display: "flex", alignItems: "center", gap: 4, height: 44 }}>
            <Icon name="left" size={18} weight={600} />
            <T k="body" c={C.heading}>{store.t("Back", "पीछे", "వెనక్కి")}</T>
          </Tap>
        )}
      </HStack>
      <div key={index} className="wh-push-in" style={{ flex: 1, minHeight: 0, margin: `8px ${S.gutterCaptain}px 0`, animationDuration: ".45s" }}>
        <WelcomeArt kind={slide.art} />
      </div>
      <VStack key={`t${index}`} gap={10} align="center" className="wh-fade-in" style={{ padding: `28px ${S.gutterCaptain}px 0` }}>
        <TD k="screen" s={26} center>{slide.title}</TD>
        <TD k="body" s={17} center c={C.secondary}>{slide.line}</TD>
      </VStack>
      <div style={{ paddingTop: 26 }}><TimerDots count={3} index={index} progress={progress} /></div>
      <HStack style={{ padding: `26px ${S.gutterCaptain}px 0`, justifyContent: "space-between" }}>
        <Tap onClick={enterApp} style={{ height: 48, padding: "0 4px" }}><T k="body" c={C.secondary}>{store.t("Skip", "छोड़ें", "దాటవేయి")}</T></Tap>
        <Tap onClick={next} style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 26px", height: 52, borderRadius: 999, background: C.primaryTint }}>
          <T k="title" c={C.primaryStrong} s={17}>{store.t("Next", "आगे", "తదుపరి")}</T>
          <Icon name="arrowRight" size={17} color={C.primaryStrong} weight={600} />
        </Tap>
      </HStack>
    </div>
  );
}

/** Three dots; the current one stretches and fills from the left like a timer. */
export function TimerDots({ count, index, progress }: { count: number; index: number; progress: number }) {
  return (
    <HStack gap={8} style={{ justifyContent: "center" }} aria-label={`Slide ${index + 1} of ${count}`}>
      {Array.from({ length: count }, (_, i) => {
        const w = i === index ? 30 : 8;
        return (
          <span key={i} style={{ position: "relative", width: w, height: 8, borderRadius: 4, background: i < index ? C.primary : C.border, overflow: "hidden", transition: "width .3s" }}>
            {i === index && <span style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: Math.max(8, w * progress), borderRadius: 4, background: C.primary }} />}
          </span>
        );
      })}
    </HStack>
  );
}

const At = ({ x, y, children, className, style }: { x: number; y: number; children: React.ReactNode; className?: string; style?: React.CSSProperties }) => (
  <div className={className} style={{ position: "absolute", left: `${x * 100}%`, top: `${y * 100}%`, transform: "translate(-50%,-50%)", ...style }}>{children}</div>
);

const Pic = ({ name, size, color, fill }: { name: IconName; size: number; color: string; fill?: boolean }) => <Icon name={name} size={size} color={color} fill={fill} weight={500} />;

/** Slide pictures (drawn, gently animated; no money shown). */
export function WelcomeArt({ kind }: { kind: ArtKind }) {
  const bg = kind === "freedom" ? "linear-gradient(#DCEBFF, #FFF3D6)" : kind === "nearHome" ? "linear-gradient(#E3F6EE, #F4FBF7)" : "linear-gradient(#2B2F6B, #5A4E9A)";
  return (
    <div aria-hidden style={{ position: "relative", width: "100%", height: "100%", borderRadius: 32, overflow: "hidden", background: bg }}>
      {kind === "freedom" && (
        <>
          <At x={0.72} y={0.28}><div className="wh-pulse" style={{ width: 180, height: 180, borderRadius: "50%", background: "rgba(255,210,122,.35)", animationDuration: "2.4s" }} /></At>
          <At x={0.72} y={0.28}><div className="wh-pulse" style={{ width: 120, height: 120, borderRadius: "50%", background: "#FFD27A", animationDuration: "2.4s" }} /></At>
          <At x={0.27} y={0.2} className="wh-bob"><Pic name="bird" size={24} color="#5E7087" fill /></At>
          <At x={0.41} y={0.13} className="wh-bob" style={{ animationDelay: ".6s" }}><Pic name="bird" size={16} color="rgba(94,112,135,.7)" fill /></At>
          <div style={{ position: "absolute", left: "-25%", right: "-25%", bottom: "-27%", height: "50%", borderRadius: "50%", background: "#8FD3A7" }} />
          <div style={{ position: "absolute", left: "-40%", width: "110%", bottom: "-22%", height: "36%", borderRadius: "50%", background: "#6CC28F" }} />
          <At x={0.48} y={0.6} className="wh-bob"><Pic name="figure" size={150} color={C.primaryStrong} /></At>
        </>
      )}
      {kind === "nearHome" && (
        <>
          <At x={0.76} y={0.5}><Pic name="building" size={130} color="#9CC9B5" /></At>
          <At x={0.2} y={0.58}><Pic name="home" size={80} color="#6FB596" /></At>
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: "25%", background: "#CBE9DA" }} />
          <svg style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} viewBox="0 0 100 100" preserveAspectRatio="none">
            <path d="M24 76 Q50 84 76 76" stroke="#6FB596" strokeWidth="1.2" strokeDasharray="0.6 3.5" strokeLinecap="round" fill="none" />
          </svg>
          <At x={0.76} y={0.2} className="wh-bob"><Pic name="location" size={32} color={C.primary} /></At>
          <At x={0.49} y={0.64}><div className="wh-walk"><Pic name="walk" size={70} color={C.primaryStrong} /></div></At>
        </>
      )}
      {kind === "evening" && (
        <>
          <At x={0.78} y={0.18} style={{ transform: "translate(-50%,-50%) rotate(-20deg)" }}><Pic name="moon" size={52} color="#FFE6A8" fill /></At>
          {[[0.14, 0.14], [0.32, 0.26], [0.52, 0.1], [0.62, 0.3], [0.22, 0.38], [0.9, 0.4]].map(([x, y], i) => (
            <At key={i} x={x} y={y} className="wh-breathe" style={{ animationDelay: `${(i % 2) * 0.7}s` }}><Pic name="sparkle" size={i % 2 === 0 ? 14 : 10} color="#fff" fill /></At>
          ))}
          <div style={{ position: "absolute", left: "-20%", right: "-20%", bottom: "-21%", height: "42%", borderRadius: "50%", background: "#3D3A7E" }} />
          <At x={0.46} y={0.64} className="wh-bob"><Pic name="family" size={130} color="#fff" /></At>
          <At x={0.24} y={0.24}>
            <div className="wh-pulse" style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 12px", height: 34, borderRadius: 999, background: "#fff", boxShadow: "0 4px 10px rgba(0,0,0,.18)", animationDuration: "2.4s" }}>
              <Icon name="checkCircle" size={18} color={C.success} />
              <T k="label" s={13} c={C.heading}>UPI</T>
            </div>
          </At>
        </>
      )}
    </div>
  );
}

// MARK: Light sign-up: name, number (W02) → code (W03)

export function SignUpScreen({ login = false }: { login?: boolean }) {
  const { store, router } = useCaptain();
  const [name, setName] = useState("");
  const [number, setNumber] = useState("");
  const [focusNumber, setFocusNumber] = useState(0);
  const valid = Validators.isValidMobile(number) && (login || Validators.isValidName(name));
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={login ? store.t("Log in", "लॉग इन", "లాగిన్") : store.t("Sign up", "साइन अप", "సైన్ అప్")} />}
      footer={<WFooter><Button title={store.t("Get code", "कोड भेजें", "కోడ్ పొందండి")} size="captain" enabled={valid} onClick={() => {
        if (!login) store.name = name.trim();
        store.phone = Validators.digitsOnly(number).slice(0, 10);
        router.push({ n: "otp", login });
      }} /></WFooter>}>
      <WTitle style={{ paddingTop: 10 }}>{login ? store.t("Welcome back", "फिर से स्वागत है", "మళ్ళీ స్వాగతం") : store.t("Save your spot", "अपनी जगह पक्की करें", "మీ స్థానం ఖాయం చేసుకోండి")}</WTitle>
      <WBody style={{ paddingTop: 6, paddingBottom: 22 }}>{login ? store.t("Enter your number. We send a code by SMS.", "अपना नंबर डालें। हम SMS से कोड भेजेंगे।", "మీ నంబర్ ఇవ్వండి. SMS ద్వారా కోడ్ పంపుతాము.")
        : store.t("Just your name and number for now. Documents come later, only when you take your first job.", "अभी सिर्फ़ नाम और नंबर। कागज़ बाद में, जब आप पहला काम लेंगे।", "ఇప్పుడు పేరు, నంబర్ మాత్రమే. పత్రాలు తర్వాత, మొదటి పని తీసుకున్నప్పుడు.")}</WBody>
      {!login && (
        <div style={{ paddingBottom: 16 }}>
          {/* Name first (keyboard opens here), then Next moves to the number. */}
          <TextField label={store.t("Your name", "आपका नाम", "మీ పేరు")} value={name} onChange={setName} placeholder="Raju Yadav" caps="words" large autoFocus enterKey="next"
            onSubmit={() => setFocusNumber((n) => n + 1)} />
        </div>
      )}
      <PhoneField number={number} onChange={setNumber} large autoFocus={login} focusTrigger={focusNumber} />
      <TD k="caption" style={{ paddingTop: 12 }}>{store.t("We send a code by SMS.", "हम SMS से कोड भेजेंगे।", "మేము SMS ద్వారా కోడ్ పంపుతాము.")}</TD>
    </Screen>
  );
}

// MARK: W03 Enter the code

export function WOtpScreen({ login = false }: { login?: boolean }) {
  const { store, router } = useCaptain();
  const [code, setCode] = useState("");
  const [reading, setReading] = useState(true);
  useEffect(() => {
    // Demo: auto-read the SMS code like Android's SMS Retriever.
    let i = 0;
    const t = setInterval(() => {
      i += 1;
      setCode("381624".slice(0, i));
      if (i >= 6) { clearInterval(t); setReading(false); }
    }, 450);
    return () => clearInterval(t);
  }, []);
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={login ? store.t("Log in", "लॉग इन", "లాగిన్") : store.t("Sign up", "साइन अप", "సైన్ అప్")} />}
      footer={<WFooter><Button title={store.t("Next", "आगे", "తదుపరి")} size="captain" enabled={code.length === 6} onClick={() => {
        // Demo: a returning captain has already done KYC.
        if (login) store.signedUp = true;
        store.finishRegistration();
        router.home();
      }} /></WFooter>}>
      <Icon name="chat" size={26} color={C.primaryStrong} style={{ marginTop: 14 }} />
      <WTitle style={{ paddingTop: 8 }}>{store.t("Enter the code", "कोड डालें", "కోడ్ నమోదు చేయండి")}</WTitle>
      <WBody style={{ paddingTop: 4, paddingBottom: 20 }}>{`${store.t("Sent to", "भेजा गया", "పంపబడింది")} ${Fmt.phoneShort(store.phone)}`}</WBody>
      <OtpField code={code} onChange={setCode} boxSize={46} autoFocus={false} />
      {reading && (
        <HStack gap={10} style={{ padding: "0 16px", height: 44, borderRadius: 12, background: C.primaryTint, marginTop: 20 }}>
          <Icon name="check" size={16} />
          <T k="caption" c={C.heading}>{store.t("Reading the code from SMS…", "SMS से कोड पढ़ रहे हैं…", "SMS నుండి కోడ్ చదువుతోంది…")}</T>
        </HStack>
      )}
    </Screen>
  );
}

// MARK: Nudge after looking around for a while

export function SignUpNudge({ onClose }: { onClose: () => void }) {
  const { store, router } = useCaptain();
  return (
    <VStack gap={14} align="center" style={{ flex: 1 }}>
      <div style={{ paddingTop: 12 }}><StateCircle icon="sparkle" tone="ok" size={84} /></div>
      <TD k="section" w={600} s={22}>{store.t("Like what you see?", "पसंद आया?", "నచ్చిందా?")}</TD>
      <WBody center>{store.t("Add your name and number to save your spot. It takes 30 seconds.", "अपनी जगह पक्की करने के लिए नाम और नंबर डालें। 30 सेकंड लगेंगे।", "మీ స్థానం ఖాయం చేసుకోవడానికి పేరు, నంబర్ ఇవ్వండి. 30 సెకన్లు చాలు.")}</WBody>
      <div style={{ flex: 1 }} />
      <Button title={store.t("Sign up", "साइन अप करें", "సైన్ అప్")} size="captain" onClick={() => { onClose(); router.push({ n: "signUp", login: false }); }} />
      <Button title={store.t("Later", "बाद में", "తర్వాత")} kind="text" onClick={onClose} />
    </VStack>
  );
}

// MARK: Guest notice used on Jobs and Money

export function GuestNotice({ text }: { text: string }) {
  const { store, router } = useCaptain();
  return (
    <HStack align="start" gap={12} style={{ padding: 16, borderRadius: 14, background: C.primaryTint }}>
      <Icon name="eye" size={18} color={C.primaryStrong} />
      <VStack gap={8} align="start" style={{ flex: 1 }}>
        <TD k="caption" c={C.inverse} s={14.5}>{text}</TD>
        {!store.registered && <Link title={store.t("Sign up to start", "शुरू करने के लिए साइन अप करें", "మొదలుపెట్టడానికి సైన్ అప్")} k="caption" style={{ minHeight: 24 }} onClick={() => router.push({ n: "signUp", login: false })} />}
      </VStack>
    </HStack>
  );
}
