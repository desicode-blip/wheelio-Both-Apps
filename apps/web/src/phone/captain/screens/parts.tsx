"use client";

// Captain pieces used on several screens: booking visuals, vehicle photos, the owner's note
// player, profile photo, bell, work-area chip and the help ladder.

import { useState } from "react";
import { C } from "../../ds/tokens";
import { ActionSheet, Avatar, HStack, Pager, PageDots, Tap, T, TD, VStack } from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { pickImage } from "../../lib/device";
import { Hub, reactive, useHub } from "../../lib/reactive";
import { useCaptain } from "../ctx";
import { washInside, washWater, type CaptainStore, type Job, type Lang, type WashType } from "../store";

export const sideName = (s: CaptainStore, i: number) =>
  [s.t("Front", "आगे", "ముందు భాగం"), s.t("Back", "पीछे", "వెనుక భాగం"), s.t("Left", "बायाँ", "ఎడమ"), s.t("Right", "दायाँ", "కుడి")][i] ?? "";

export const washName = (w: WashType, s: CaptainStore) =>
  w === "dryDusting" ? s.t("Dry dusting", "सूखी सफ़ाई", "పొడి దుమ్ము తుడుపు") : w === "wetOutside" ? s.t("Water wash", "पानी से धुलाई", "నీటి వాష్") : s.t("Water wash + inside", "पानी से धुलाई + अंदर", "నీటి వాష్ + లోపల");
const washIcon = (w: WashType): IconName => (washWater(w) ? "drop" : "wind");

/** Big picture card: the vehicle, then Outside / Water / Inside with ✓ or ✗. */
export function BookingVisual({ job }: { job: Job }) {
  const { store } = useCaptain();
  const tile = (icon: IconName, label: string, yes: boolean) => (
    <VStack gap={10} align="center" style={{ position: "relative", flex: 1, padding: "14px 0", borderRadius: 16, background: yes ? "rgba(230,248,239,.5)" : C.canvas }}>
      <span style={{ position: "relative", width: 58, height: 58, borderRadius: 29, background: yes ? C.primaryTint : C.canvas, display: "grid", placeItems: "center", overflow: "hidden" }}>
        <Icon name={icon} size={27} color={yes ? C.primaryStrong : C.muted} fill={icon === "drop" && yes} />
        {!yes && <span style={{ position: "absolute", width: 64, height: 3, background: "rgba(179,38,30,.7)", transform: "rotate(-40deg)" }} />}
      </span>
      <T k="title" s={15.5} c={yes ? C.heading : C.secondary}>{label}</T>
      <span style={{ position: "absolute", top: 8, right: 8, width: 22, height: 22, borderRadius: 11, background: yes ? C.success : C.destructive, display: "grid", placeItems: "center" }}>
        <Icon name={yes ? "check" : "close"} size={12} color="#fff" weight={700} />
      </span>
    </VStack>
  );
  return (
    <VStack gap={16} style={{ padding: 16, borderRadius: 20, background: "#fff", boxShadow: `inset 0 0 0 1px ${C.border}` }}>
      <HStack gap={14}>
        <div style={{ position: "relative", width: 84, height: 68, borderRadius: 16, background: C.primaryTint, display: "grid", placeItems: "center", flexShrink: 0 }}>
          <Icon name={job.isBike ? "bike" : "car"} size={40} color={C.primaryStrong} />
          <span style={{ position: "absolute", right: -8, bottom: -8, width: 30, height: 30, borderRadius: 15, background: washWater(job.wash) ? C.primary : C.secondary, boxShadow: "0 0 0 2px #fff", display: "grid", placeItems: "center" }}>
            <Icon name={washIcon(job.wash)} size={15} color="#fff" weight={700} fill={washWater(job.wash)} />
          </span>
        </div>
        <VStack gap={4}>
          <T k="small" c={C.secondary}>{store.t("Owner booked", "मालिक ने बुक किया", "యజమాని బుక్ చేశారు")}</T>
          <TD k="section" w={600}>{washName(job.wash, store)}</TD>
        </VStack>
      </HStack>
      <HStack gap={10}>
        {tile(job.isBike ? "bike" : "car", store.t("Outside", "बाहर", "బయట"), true)}
        {tile("drop", store.t("Water", "पानी", "నీళ్ళు"), washWater(job.wash))}
        {!job.isBike && tile("seat", store.t("Inside", "अंदर", "లోపల"), washInside(job.wash))}
      </HStack>
    </VStack>
  );
}

/** One-line version: vehicle + wash picture + name (job alert and Go to vehicle). */
export function BookingChip({ job }: { job: Job }) {
  const { store } = useCaptain();
  return (
    <HStack gap={10} style={{ padding: "8px 12px", borderRadius: 999, background: C.primaryTint }}>
      <span style={{ width: 32, height: 32, borderRadius: 16, background: washWater(job.wash) ? C.primary : C.secondary, display: "grid", placeItems: "center" }}>
        <Icon name={washIcon(job.wash)} size={16} color="#fff" weight={600} fill={washWater(job.wash)} />
      </span>
      <T k="title" s={16}>{washName(job.wash, store)}</T>
      {washInside(job.wash) && <Icon name="seat" size={16} color={C.primaryStrong} />}
    </HStack>
  );
}

// MARK: Vehicle photos (from the owner's booking)

/** Dashed or filled outlines of a car, seen from the front, back or side (0 front, 1 back, 2 left, 3 right). */
export function CarShape({ side, width, height, fill, stroke, dash }: { side: number; width: number; height: number; fill?: string; stroke?: string; dash?: boolean }) {
  const props = fill ? { fill, stroke: "none" } : { fill: "none", stroke: stroke ?? "rgba(255,255,255,.85)", strokeWidth: 2.5 * (100 / width), strokeDasharray: dash ? `${8 * (100 / width)} ${6 * (100 / width)}` : undefined };
  const flip = side === 3 ? "scale(-1,1) translate(-100,0)" : undefined;
  return (
    <svg width={width} height={height} viewBox={side >= 2 ? "0 -2 100 38" : "0 0 100 75"} preserveAspectRatio="none" style={{ overflow: "visible" }}>
      <g transform={flip} {...props} fillRule="evenodd">
        {side >= 2 ? (
          <>
            <path d="M0 27 L4 16 L28 13.6 Q45 -3.6 68 12.6 L98 19.8 L100 27 Z" />
            <ellipse cx={15 + 7.6} cy={21 + 7.6} rx={7.6} ry={7.6} />
            <ellipse cx={85 - 7.6} cy={21 + 7.6} rx={7.6} ry={7.6} />
          </>
        ) : side === 0 ? (
          <>
            <path d="M24 4.5 L76 4.5 L88 31.5 L12 31.5 Z M28 9.75 L72 9.75 L80 27.75 L20 27.75 Z" />
            <rect x={4} y={31.5} width={92} height={30} rx={6} />
            <rect x={0} y={24.75} width={9} height={6.75} rx={2} />
            <rect x={91} y={24.75} width={9} height={6.75} rx={2} />
            {!fill && <><ellipse cx={19.5} cy={42} rx={10.5} ry={4.5} /><ellipse cx={80.5} cy={42} rx={10.5} ry={4.5} /><rect x={36} y={39} width={28} height={9} rx={2} /><path d="M4 54 L96 54" /></>}
            <rect x={10} y={61.5} width={15} height={11.25} rx={2} />
            <rect x={75} y={61.5} width={15} height={11.25} rx={2} />
          </>
        ) : (
          <>
            <path d="M24 6 L76 6 L88 31.5 L12 31.5 Z M29 11.25 L71 11.25 L78 27 L22 27 Z" />
            <rect x={4} y={31.5} width={92} height={30} rx={5} />
            {!fill && <><rect x={6} y={36} width={18} height={9} rx={2} /><rect x={76} y={36} width={18} height={9} rx={2} /><rect x={35} y={43.5} width={30} height={8.25} /><path d="M4 55.5 L96 55.5" /></>}
            <rect x={10} y={61.5} width={15} height={11.25} rx={2} />
            <rect x={75} y={61.5} width={15} height={11.25} rx={2} />
          </>
        )}
      </g>
    </svg>
  );
}

/** Placeholder for the owner's photo of one side. BACKEND: show the owner's real photo for that side. */
export function VehiclePhotoView({ side, isBike = false, compact = false }: { side: number; isBike?: boolean; compact?: boolean }) {
  const w = side >= 2 ? (compact ? 96 : 300) : compact ? 82 : 250;
  const h = side >= 2 ? (compact ? 36 : 112) : compact ? 62 : 186;
  return (
    <div style={{ position: "relative", width: "100%", height: "100%", background: "linear-gradient(#DDE6F3, #B9C6D8)", overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: compact ? 26 : 120, background: "rgba(141,154,173,.35)" }} />
      <div style={{ position: "absolute", left: "50%", top: "50%", transform: `translate(-50%, calc(-50% + ${compact ? 4 : 30}px))` }}>
        {isBike ? <Icon name="bike" size={compact ? 54 : 160} color="#3B4A5E" /> : <CarShape side={side} width={w} height={h} fill="rgba(59,74,94,.85)" />}
      </div>
    </div>
  );
}

/** Full-screen viewer: swipe between Front, Back, Left, Right. Front opens first. */
export function VehiclePhotosViewer({ isBike, plate, onClose }: { isBike: boolean; plate: string; onClose: () => void }) {
  const { store } = useCaptain();
  const [index, setIndex] = useState(0);
  return (
    <div className="wh-overlay wh-fade-in" style={{ background: "#000", justifyContent: "flex-start", paddingTop: "var(--sat)", paddingBottom: "var(--sab)", zIndex: 45 }}>
      <HStack style={{ padding: "8px 16px 0" }}>
        <VStack gap={2} style={{ flex: 1 }}>
          <TD k="title" c="#fff" s={17}>{store.t("Vehicle photos", "गाड़ी की फ़ोटो", "వాహనం ఫోటోలు")}</TD>
          <TD k="caption" c="rgba(255,255,255,.75)">{`${sideName(store, index)} · ${index + 1}/4 · ${plate}`}</TD>
        </VStack>
        <Tap onClick={onClose} label="Close" style={{ width: 44, height: 44, borderRadius: 22, background: "rgba(255,255,255,.15)", display: "grid", placeItems: "center" }}>
          <Icon name="close" size={18} color="#fff" weight={700} />
        </Tap>
      </HStack>
      <Pager count={4} index={index} onIndex={setIndex} style={{ flex: 1, minHeight: 0 }} render={(i) => (
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", padding: "0 16px" }}>
          <div style={{ width: "100%", aspectRatio: "3 / 4", borderRadius: 18, overflow: "hidden" }}><VehiclePhotoView side={i} isBike={isBike} /></div>
        </div>
      )} />
      <div style={{ padding: "8px 0 16px" }}><PageDots count={4} index={index} /></div>
    </div>
  );
}

// MARK: Owner's voice note player

const noteHub = new Hub();
/** Plays the owner's note. Demo: read out by the browser's voice in the captain's language. BACKEND: the owner's recorded audio. */
export const notePlayer = reactive({ playing: false, progress: 0, finishedOnce: false }, noteHub);
let stopCurrent: (() => void) | null = null;
const NOTE_SECONDS = 12;

const noteText = (lang: Lang) => ({
  en: "Hello. My car is in slot 41, basement B2. Please clean the wheels well, and don't move the wipers. Thank you.",
  hi: "नमस्ते। मेरी गाड़ी B2 में, स्लॉट 41 पर है। पहिये अच्छे से साफ़ करना, और वाइपर मत हिलाना। धन्यवाद।",
  te: "నమస్తే. నా కారు B2 లో, స్లాట్ 41 లో ఉంది. చక్రాలు బాగా శుభ్రం చేయండి, వైపర్లు కదపకండి. ధన్యవాదాలు.",
})[lang];

export function useNotePlayer() { useHub(noteHub); return notePlayer; }

export function stopNote() {
  stopCurrent?.();
  stopCurrent = null;
  notePlayer.playing = false;
}

export function playNote(lang: Lang) {
  stopNote();
  notePlayer.playing = true;
  notePlayer.progress = 0;
  const started = Date.now();
  let ended = false;
  const finish = () => {
    if (ended) return;
    ended = true;
    clearInterval(tick);
    notePlayer.playing = false;
    notePlayer.progress = 1;
    notePlayer.finishedOnce = true;
    stopCurrent = null;
  };
  const tick = setInterval(() => { notePlayer.progress = Math.min(0.97, (Date.now() - started) / (NOTE_SECONDS * 1000)); }, 100);
  // Without a voice (or if speech is blocked), the note "plays" for its length on a timer.
  let fallback: ReturnType<typeof setTimeout> | null = null;
  const useTimer = () => { fallback = setTimeout(finish, Math.max(0, NOTE_SECONDS * 1000 - (Date.now() - started))); };
  if (typeof speechSynthesis !== "undefined") {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(noteText(lang));
    u.lang = lang === "en" ? "en-IN" : lang === "hi" ? "hi-IN" : "te-IN";
    u.rate = 0.9;
    u.onend = () => { if (Date.now() - started < 1500) useTimer(); else finish(); };
    u.onerror = () => useTimer();
    speechSynthesis.speak(u);
  } else useTimer();
  stopCurrent = () => {
    ended = true;
    clearInterval(tick);
    if (fallback) clearTimeout(fallback);
    if (typeof speechSynthesis !== "undefined") speechSynthesis.cancel();
  };
}

/** Replay button beside the screen title after the note was heard. Never auto-plays. */
export function OwnerNoteButton() {
  const { store } = useCaptain();
  const p = useNotePlayer();
  if (!store.ownerNoteHeard) return null;
  return (
    <Tap label="Play owner's note again" onClick={() => (p.playing ? stopNote() : playNote(store.lang))}
      style={{ display: "flex", alignItems: "center", gap: 6, padding: "0 12px", height: 32, borderRadius: 999, background: C.canvas, boxShadow: `inset 0 0 0 1px ${C.border}`, flexShrink: 0 }}>
      <Icon name={p.playing ? "stop" : "speaker"} size={13} color={C.secondary} weight={600} />
      <T k="small" s={12.5} w={500} c={C.secondary}>{p.playing ? store.t("Playing", "चल रहा", "ప్లే అవుతోంది") : store.t("Owner’s note", "मालिक का संदेश", "యజమాని నోట్")}</T>
    </Tap>
  );
}

// MARK: Profile photo, bell

/** Tap to pick a photo, long-press to remove. Separate from the KYC selfie. */
export function WProfilePhoto({ size = 60, badge = true }: { size?: number; badge?: boolean }) {
  const { store } = useCaptain();
  const [menu, setMenu] = useState(false);
  const initials = store.name.split(" ").filter(Boolean).slice(0, 2).map((p) => p[0]).join("").toUpperCase();
  return (
    <>
      <Tap label={store.t("Profile photo", "प्रोफ़ाइल फ़ोटो", "ప్రొఫైల్ ఫోటో")} onClick={async () => { const d = await pickImage(); if (d) store.profilePhoto = d; }}
        onContext={() => { if (store.profilePhoto) setMenu(true); }} style={{ position: "relative", width: size, height: size, flexShrink: 0 }}>
        <Avatar initials={initials} size={size} photo={store.profilePhoto} />
        {badge && (
          <span style={{ position: "absolute", right: -2, bottom: -2, width: 24, height: 24, borderRadius: 12, background: C.primary, boxShadow: "0 0 0 2px #fff", display: "grid", placeItems: "center" }}>
            <Icon name="camera" size={12} color="#fff" />
          </span>
        )}
      </Tap>
      <ActionSheet open={menu} onClose={() => setMenu(false)} actions={[{ title: store.t("Remove photo", "फ़ोटो हटाएं", "ఫోటో తీసివేయండి"), role: "destructive", action: () => { store.profilePhoto = null; } }]} />
    </>
  );
}

export function WNotificationBell() {
  const { store, router } = useCaptain();
  const n = store.unreadCount;
  return (
    <Tap onClick={() => router.push({ n: "notifications" })} label={store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు")} style={{ position: "relative", width: 48, height: 48, display: "grid", placeItems: "center", flexShrink: 0 }}>
      <Icon name={store.notificationsOn ? "bell" : "bellSlash"} size={24} />
      {n > 0 && (
        <span style={{ position: "absolute", top: 6, right: 4, minWidth: 19, height: 19, padding: "0 5px", borderRadius: 10, background: C.destructive, color: "#fff", fontSize: 11, fontWeight: 700, display: "grid", placeItems: "center", boxSizing: "border-box" }}>
          {n > 9 ? "9+" : n}
        </span>
      )}
    </Tap>
  );
}

/** "📍 Jobs from: … · Change" — shown on Home and under the job alert. */
export function WorkAreaChip({ onDark = false }: { onDark?: boolean }) {
  const { store, router } = useCaptain();
  const fg = onDark ? "#fff" : C.primaryStrong;
  return (
    <Tap onClick={() => router.push({ n: "workArea" })} style={{
      display: "flex", alignItems: "center", gap: 8, padding: "0 14px", height: 44, width: "100%", borderRadius: 999,
      background: onDark ? "rgba(255,255,255,.16)" : "#fff", boxShadow: onDark ? undefined : `inset 0 0 0 1px ${C.border}`,
    }}>
      <Icon name="location" size={15} color={fg} />
      <T k="caption" s={14.5} c={onDark ? "#fff" : C.heading} lines={1} style={{ flex: 1, textAlign: "left" }}>
        {store.t("Jobs from: ", "काम: ", "పనులు: ")}<b>{store.workSummary}</b>
      </T>
      <T k="label" c={fg}>{store.t("Change", "बदलें", "మార్చండి")}</T>
      <Icon name="chevron" size={12} color={fg} />
    </Tap>
  );
}

/** Three small steps, shown on Help and inside each problem. 0 = just showing the steps; 1...3 = current step. */
export function HelpLadder({ current, skipOwner = false }: { current: number; skipOwner?: boolean }) {
  const { store } = useCaptain();
  const step = (n: number, icon: IconName, label: string, skipped = false) => {
    const done = current > n, now = current === n;
    return (
      <VStack gap={6} align="center" style={{ flex: 1, minWidth: 0 }}>
        <span style={{ width: 34, height: 34, borderRadius: 17, background: done ? C.success : now ? C.primary : C.primaryTint, opacity: skipped ? 0.4 : 1, display: "grid", placeItems: "center" }}>
          <Icon name={done ? "check" : icon} size={16} color={done ? C.onSuccess : now ? "#fff" : C.primaryStrong} />
        </span>
        <T k="small" c={now ? C.heading : C.secondary} w={now ? 600 : 400} lines={1}>{label}</T>
      </VStack>
    );
  };
  const line = (after: number) => <div style={{ width: 30, height: 2, marginBottom: 18, background: current > after ? C.success : C.border, flexShrink: 0 }} />;
  return (
    <HStack gap={6} style={{ padding: 12, borderRadius: 14, background: C.canvas }}>
      {step(1, "sparkle", store.t("Quick check", "जल्दी जाँच", "త్వరిత తనిఖీ"))}
      {line(1)}
      {step(2, "user", store.t("Owner", "मालिक", "యజమాని"), skipOwner)}
      {line(2)}
      {step(3, "chat", store.t("Our team", "हमारी टीम", "మా బృందం"))}
    </HStack>
  );
}

