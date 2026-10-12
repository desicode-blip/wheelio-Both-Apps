"use client";

import { useState } from "react";
import { C, S } from "../../ds/tokens";
import {
  Alert, AppBar, Badge, Banner, Button, Chip, Divider, Flow, FooterBar, FullState, HStack, IconBox, IconButton, KeyValueCard, Link,
  PhotoSlot, Plate, Screen, SectionLabel, Segmented, SelectionTile, Sheet, Tap, T, TD, TextArea, TextField, TextScale, TitleBlock,
  ToggleRow, VStack, card, outlined, type PhotoState,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { addDays, Fmt, startOfDay } from "../../lib/fmt";
import { useApp, useOnAppear } from "../ctx";
import { angleLabel, Note, PhotoAngles, PlaceFmt, Slot, VehicleTypes, VT, Wash, type PhotoAngle, type TimeSlot, type UploadState, type WashKind } from "../model";
import { Draft, homePlace } from "../store";
import { BookingHeader, HeldSafelyBanner } from "./parts";

// MARK: C05 Vehicle type (C52: 200% text)

export function VehicleTypeScreen({ large = false }: { large?: boolean }) {
  const { store, router } = useApp();
  useOnAppear(() => { if (!store.draft.type && !large) store.draft.type = VehicleTypes[1]; });
  const next = <Button title="Next" enabled={store.draft.type != null} onClick={() => router.push({ n: "washType" })} />;
  return (
    <TextScale.Provider value={large ? 1.6 : 1}>
      <Screen
        header={<BookingHeader step={1} label="Vehicle" fraction={0.2} />}
        footer={large ? <div style={{ borderTop: `1px solid ${C.divider}`, padding: `12px ${S.gutter}px` }}>{next}</div> : <FooterBar showCall={false}>{next}</FooterBar>}
      >
        <TitleBlock title="What are we washing?" subtitle={large ? null : "Pick your vehicle. You choose the wash next."} />
        <VStack gap={12}>
          {(large ? VehicleTypes.slice(0, 2) : VehicleTypes).map((t) => {
            const sel = store.draft.type?.kind === t.kind;
            if (large) {
              return (
                <Tap key={t.kind} onClick={() => { store.draft.type = t; }} style={{ ...outlined(16, 16, sel ? C.primaryTint : C.white, sel ? C.primary : C.border, sel ? 2 : 1), display: "flex", flexDirection: "column", gap: 4, textAlign: "left" }}>
                  <TD k="section" w={600}>{t.name}</TD>
                  <TD k="body">{`About ${t.minutes} min`}</TD>
                  <TD k="section" w={700}>{Fmt.rupees(t.price)}</TD>
                </Tap>
              );
            }
            return <SelectionTile key={t.kind} icon={VT.icon(t)} title={t.name} subtitle={`About ${t.minutes} min`} trailing={Fmt.rupees(t.price)} selected={sel} onClick={() => { store.draft.type = t; }} />;
          })}
        </VStack>
      </Screen>
    </TextScale.Provider>
  );
}

// MARK: Wash type (after C05)

export function WashTypeScreen() {
  const { store, router } = useApp();
  const [videoSoon, setVideoSoon] = useState(false);
  const [notAvailable, setNotAvailable] = useState(false);
  const isBike = store.draft.type?.kind === "bike";
  const options = Wash.options(store.draft.type?.kind);
  useOnAppear(() => {
    const w = store.draft.wash;
    if (w && options.includes(w) && Wash.available(w)) return;
    store.draft.wash = "wetOutside";
  });
  const tile = (w: WashKind) => {
    const selected = store.draft.wash === w;
    const avail = Wash.available(w);
    return (
      <div key={w} role="button" tabIndex={0} className="wh-press" onClick={() => { if (avail) store.draft.wash = w; else setNotAvailable(true); }}
        style={{ ...outlined(0, 16, selected ? C.primaryTint : C.white, selected ? C.primary : C.border, selected ? 2 : 1), padding: "14px 16px", display: "flex", alignItems: "center", gap: 14, opacity: avail ? 1 : 0.7, cursor: "pointer" }}>
        <IconBox icon={Wash.icon(w)} size={48} tone={avail ? "info" : "mute"} />
        <VStack gap={2} style={{ flex: 1 }}>
          <TD k="title">{Wash.name(w, isBike)}</TD>
          <TD k="caption">{Wash.detail(w, isBike)}</TD>
          {!avail && <TD k="label" c={C.secondary} style={{ paddingTop: 2 }}>Not in your society yet</TD>}
        </VStack>
        <Tap label={`See what ${Wash.name(w, isBike)} means`} onClick={() => setVideoSoon(true)}
          style={{ width: 44, height: 44, borderRadius: 22, background: selected ? "transparent" : C.primaryTint, display: "grid", placeItems: "center" }}>
          <Icon name="eye" size={19} color={C.primaryStrong} />
        </Tap>
      </div>
    );
  };
  return (
    <Screen header={<BookingHeader step={1} label="Vehicle" fraction={0.2} />}
      footer={<FooterBar showCall={false}><Button title="Next" enabled={store.draft.wash != null} onClick={() => router.push({ n: "vehicleNumber" })} /></FooterBar>}>
      <TitleBlock title="What kind of wash?" subtitle={`Same price for every option${store.draft.type ? `: ${Fmt.rupees(store.draft.type.price)}` : ""}.`} />
      <VStack gap={12}>{options.map(tile)}</VStack>
      <Alert open={videoSoon} onClose={() => setVideoSoon(false)} title="Video coming soon"
        message="We’re making a short video that shows this wash. For now, pick the one you like and carry on." />
      <Alert open={notAvailable} onClose={() => setNotAvailable(false)} title="Not available in your society yet"
        message="Inside cleaning isn’t offered in your society right now. We’ll let you know when it is." />
    </Screen>
  );
}

// MARK: C06 Vehicle number. Any number is accepted as typed, so customers never hit an error here.

export function VehicleNumberScreen() {
  const { store, router } = useApp();
  const [plate, setPlate] = useState(store.draft.plate);
  const trimmed = plate.trim();
  const next = () => {
    if (!trimmed) return;
    store.draft.plate = trimmed.toUpperCase();
    router.push({ n: "photos" });
  };
  const t = store.draft.type;
  return (
    <Screen header={<BookingHeader step={1} label="Vehicle" fraction={0.2} />}
      footer={<FooterBar showCall={false}><Button title="Next" enabled={!!trimmed} onClick={next} /></FooterBar>}>
      <TitleBlock title="What’s the number plate?" subtitle="So the captain finds the right vehicle." />
      <TextField label="Vehicle number" value={plate} onChange={setPlate} placeholder="TS 09 EA 4521" helper="Use the number on your plate" caps="characters" autoFocus onSubmit={next} />
      {t && (
        <Tap onClick={() => router.pop()} style={{ display: "flex", alignItems: "center", gap: 10, paddingTop: 22, alignSelf: "flex-start" }}>
          <IconBox icon={VT.icon(t)} size={38} radius={10} />
          <T k="caption">{`${VT.short(t)} · ${Fmt.rupees(t.price)} · `}<span style={{ textDecoration: "underline", color: C.primaryStrong }}>Change</span></T>
        </Tap>
      )}
    </Screen>
  );
}

// MARK: C07 Photos (C07b partial, C07c done)

const slotState = (s?: UploadState): PhotoState => (s == null ? "empty" : s);

export function PhotosScreen() {
  const { store, router } = useApp();
  const [skip, setSkip] = useState(false);
  const d = store.draft;
  const complete = Draft.photosComplete(d);
  const empty = Object.keys(d.photos).length === 0;
  const goNext = () => router.push(store.draft.place == null ? { n: "location" } : { n: "floorSlot" });
  return (
    <Screen header={<BookingHeader step={2} label="Photos" fraction={0.4} />}
      footer={
        <FooterBar showCall={false}>
          <VStack gap={2} align="center">
            <Button title="Next" enabled={complete} onClick={goNext} />
            {/* Photos are optional for the customer: the captain takes the official before photos. */}
            {!complete && <Link title="Skip for now" color={C.secondary} k="caption" onClick={() => setSkip(true)} />}
          </VStack>
        </FooterBar>
      }>
      {complete ? <TitleBlock title="Looking good" subtitle={`4 photos${d.videoSeconds != null ? " and a video" : ""}. Tap any photo to retake.`} />
        : empty ? <TitleBlock title="Take 4 quick photos" subtitle="They help the captain find your vehicle. The captain takes the official before photos." />
        : <TitleBlock title="Take 4 quick photos" subtitle={`${Draft.photosDone(d)} of 4 done`} />}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
        {PhotoAngles.map((a) => (
          <PhotoSlot key={a} label={angleLabel(a)} state={slotState(d.photos[a])} height={empty ? 126 : 98}
            onClick={() => { if (d.photos[a] === "failed") store.uploadPhoto(a); else router.push({ n: "camera", angle: a }); }} />
        ))}
      </div>
      {Draft.hasFailedPhoto(d) && (
        <Banner tone="error" icon="wifiOff" text="Back photo didn’t upload. It’s saved on your phone." actionTitle="Retry" style={{ marginTop: 20 }}
          onAction={() => { const a = PhotoAngles.find((x) => d.photos[x] === "failed"); if (a) store.uploadPhoto(a); }} />
      )}
      {d.videoSeconds != null && complete ? (
        <HStack gap={12} style={{ padding: "0 16px", height: 46, borderRadius: 999, background: C.canvas, marginTop: 20 }}>
          <Icon name="video" size={18} color={C.primaryStrong} />
          <T k="bodyStrong" c={C.heading} style={{ flex: 1 }}>{`Walk-around video · ${Fmt.clock(d.videoSeconds)}`}</T>
          <Icon name="check" size={16} />
        </HStack>
      ) : !Draft.hasFailedPhoto(d) ? (
        <Tap onClick={() => { store.draft.videoSeconds = 14; }} style={{ marginTop: 20, height: 62, borderRadius: 12, border: `1px dashed ${C.dashed}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
          <Icon name="video" size={18} color={C.primaryStrong} />
          <T k="bodyStrong" c={C.primaryStrong} w={500}>Walk-around video · optional, 15 sec</T>
        </Tap>
      ) : null}
      <Alert open={skip} onClose={() => setSkip(false)} title="Skip the photos?"
        message="Without your photos from before the wash, we won’t be able to take up any claim if something goes wrong later."
        buttons={[{ title: "Take photos", role: "cancel" }, { title: "Skip anyway", action: goNext }]} />
    </Screen>
  );
}

// MARK: C08 Camera (C08b access needed)

export function CameraScreen({ angle, forceDenied = false }: { angle: PhotoAngle; forceDenied?: boolean }) {
  const { store, router } = useApp();
  const [denied, setDenied] = useState(false);
  const [current, setCurrent] = useState<PhotoAngle>(angle);
  const index = PhotoAngles.indexOf(current);
  if (denied || forceDenied) {
    return (
      <Screen header={<AppBar onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "0 14px" }} />} scrolls={false}>
        <FullState icon="camera" tone="wait" title="Camera access needed" message="Photos help the captain find your vehicle. Allow camera to continue."
          primary="Allow camera" secondary="Skip photos for now" onPrimary={() => setDenied(false)}
          onSecondary={() => { for (const a of PhotoAngles) store.draft.photos[a] = "done"; router.pop(); }} />
      </Screen>
    );
  }
  const shoot = () => {
    const a = current;
    store.uploadPhoto(a);
    const next = PhotoAngles.find((x) => store.draft.photos[x] == null && x !== a);
    if (next) setCurrent(next); else router.pop();
  };
  return (
    <div className="wh-fill" style={{ background: C.camera, paddingTop: "var(--sat)", paddingBottom: "var(--sab)" }}>
      <AppBar title={`${angleLabel(current)} · ${index + 1} of 4`} leading="close" trailing={null} dark onLeading={() => router.pop()} style={{ padding: "0 14px" }} />
      <div style={{ flex: 1, margin: "8px 16px 0", borderRadius: 20, background: C.cameraPanel, position: "relative", display: "grid", placeItems: "center" }}>
        <CarOutline width={250} height={160} />
        <TD k="body" c="rgba(255,255,255,.9)" center style={{ position: "absolute", bottom: 22, left: 16, right: 16 }}>{`Fit the ${angleLabel(current).toLowerCase()} of the vehicle in the outline`}</TD>
      </div>
      <HStack style={{ padding: "24px 0", justifyContent: "space-between" }}>
        <div style={{ width: 60 }} />
        <ShutterButton onClick={shoot} />
        <div style={{ width: 60, display: "grid", placeItems: "center" }}><Icon name="flash" size={22} color="rgba(255,255,255,.5)" /></div>
      </HStack>
    </div>
  );
}

export function ShutterButton({ onClick, size = 78 }: { onClick: () => void; size?: number }) {
  return (
    <Tap onClick={onClick} label="Take photo" style={{ width: size, height: size, borderRadius: "50%", boxShadow: "inset 0 0 0 5px #fff", display: "grid", placeItems: "center" }}>
      <span style={{ width: size * 0.8, height: size * 0.8, borderRadius: "50%", background: "#fff" }} />
    </Tap>
  );
}

/** Dashed car outline for the guided camera. */
export function CarOutline({ width, height }: { width: number; height: number }) {
  const w = width, h = height;
  return (
    <svg width={w} height={h} viewBox={`-3 -3 ${w + 6} ${h + 6}`} fill="none" stroke="rgba(255,255,255,.85)" strokeWidth={2.5} strokeDasharray="9 7">
      <rect x={0} y={h * 0.28} width={w} height={h * 0.52} rx={22} />
      <rect x={w * 0.2} y={0} width={w * 0.56} height={h * 0.3} rx={10} />
      <ellipse cx={w * 0.12 + h * 0.15} cy={h * 0.66 + h * 0.15} rx={h * 0.15} ry={h * 0.15} />
      <ellipse cx={w - w * 0.12 - h * 0.15} cy={h * 0.66 + h * 0.15} rx={h * 0.15} ry={h * 0.15} />
    </svg>
  );
}

// MARK: C09 Location (C09b off)

export function LocationScreen({ forceOff = false }: { forceOff?: boolean }) {
  const { store, router } = useApp();
  const [off, setOff] = useState(false);
  const place = homePlace();
  if (off || forceOff) {
    return (
      <Screen scrolls={false} header={<BookingHeader step={3} label="Place" fraction={0.6} />}>
        <FullState icon="location" tone="wait" title="Location is off" message="We use it only to find captains in your society. You can also type your address."
          primary="Turn on location" secondary="Type address" onPrimary={() => setOff(false)} onSecondary={() => router.push({ n: "addressSearch" })} />
      </Screen>
    );
  }
  return (
    <Screen gutter={0} header={<BookingHeader step={3} label="Place" fraction={0.6} />}
      footer={<FooterBar showCall={false}><Button title="Yes, it’s here" onClick={() => {
        store.draft.place = { society: place.society, tower: place.tower, floor: null, slot: "" };
        router.push({ n: "floorSlot" });
      }} /></FooterBar>}>
      <div style={{ padding: `0 ${S.gutter}px` }}><TitleBlock title="Is your vehicle here?" subtitle="Drag the map to move the pin." /></div>
      <MapPlaceholder height={330} />
      <div style={{ padding: `18px ${S.gutter}px 0` }}>
        <HStack gap={14} style={outlined(16)}>
          <IconBox icon="home" size={44} radius={10} />
          <VStack gap={1} style={{ flex: 1, minWidth: 0 }}>
            <TD k="title">{`${place.society.name}, ${place.tower}`}</TD>
            <TD k="caption">{PlaceFmt.addressLine(place)}</TD>
          </VStack>
          <Link title="Change" onClick={() => router.push({ n: "addressSearch" })} />
        </HStack>
      </div>
    </Screen>
  );
}

/** Simple drawn map (blocks, roads and a pin) until Google Maps is connected. The map can be dragged. */
export function MapPlaceholder({ height }: { height: number }) {
  const [off, setOff] = useState({ x: 0, y: 0 });
  const [drag, setDrag] = useState<{ x: number; y: number; ox: number; oy: number } | null>(null);
  return (
    <div style={{ position: "relative", height, background: C.map, overflow: "hidden", touchAction: "none", cursor: drag ? "grabbing" : "grab" }}
      onPointerDown={(e) => { (e.target as HTMLElement).setPointerCapture?.(e.pointerId); setDrag({ x: e.clientX, y: e.clientY, ox: off.x, oy: off.y }); }}
      onPointerMove={(e) => { if (drag) setOff({ x: drag.ox + e.clientX - drag.x, y: drag.oy + e.clientY - drag.y }); }}
      onPointerUp={() => setDrag(null)} onPointerCancel={() => setDrag(null)}>
      <div style={{ position: "absolute", inset: "-40%", transform: `translate(${off.x}px, ${off.y}px)` }}>
        {Array.from({ length: 25 }, (_, i) => {
          const col = i % 5, row = Math.floor(i / 5);
          return <div key={i} style={{ position: "absolute", left: `${2 + col * 20}%`, top: `${2 + row * 20}%`, width: "15.5%", height: "15%", borderRadius: 6, background: i % 7 === 1 || i % 7 === 5 ? C.mapGreen : C.mapBlock }} />;
        })}
      </div>
      <VStack gap={2} align="center" style={{ position: "absolute", left: "51%", top: "43%", transform: "translate(-50%, -50%)", pointerEvents: "none" }}>
        <span style={{ width: 30, height: 30, borderRadius: 15, background: C.primary, display: "grid", placeItems: "center", transform: drag ? "translateY(-8px)" : "none", transition: "transform .15s" }}>
          <span style={{ width: 11, height: 11, borderRadius: 6, background: "#fff" }} />
        </span>
        <span style={{ width: 16, height: 6, borderRadius: "50%", background: "rgba(0,0,0,.18)" }} />
      </VStack>
      <div style={{ position: "absolute", right: 26, bottom: 16 }} onPointerDown={(e) => e.stopPropagation()}>
        <IconButton icon="locate" label="My location" onClick={() => setOff({ x: 0, y: 0 })} />
      </div>
    </div>
  );
}

// MARK: C09c Address search

export function AddressSearchScreen() {
  const { store, router } = useApp();
  const [query, setQuery] = useState("my home av");
  const [picked, setPicked] = useState(false);
  const highlighted = (name: string) => {
    const q = query.trim();
    const i = q ? name.toLowerCase().indexOf(q.toLowerCase()) : -1;
    if (i < 0) return name;
    const end = i + q.length;
    return <>{name.slice(0, end)}<b style={{ fontWeight: 700 }}>{name.slice(end)}</b></>;
  };
  return (
    <Screen header={<BookingHeader step={3} label="Place" fraction={0.6} />}
      footer={<FooterBar showCall={false}><Button title="Next" enabled={picked} onClick={() => router.push({ n: "floorSlot" })} /></FooterBar>}>
      <TD k="screen" style={{ paddingTop: 20, paddingBottom: 18 }}>Where is your vehicle?</TD>
      <TextField label="Society or building" value={query} onChange={setQuery} leadingIcon="search" autoFocus />
      <VStack style={{ paddingTop: 14 }}>
        {store.searchSocieties(query).map((s) => (
          <div key={s.id}>
            <Tap onClick={() => { setPicked(true); store.draft.place = { society: s, tower: "Tower 3", floor: null, slot: "" }; router.push({ n: "floorSlot" }); }}
              className="wh-nopress wh-row" style={{ display: "flex", alignItems: "center", gap: 14, padding: "8px 0", width: "100%", textAlign: "left" }}>
              <IconBox icon="location" size={40} radius={10} />
              <VStack gap={1}>
                <TD k="rowTitle">{highlighted(s.name)}</TD>
                <TD k="caption">{`${s.area}, ${s.city}`}</TD>
              </VStack>
            </Tap>
            <Divider />
          </div>
        ))}
      </VStack>
      <HStack gap={4} style={{ paddingTop: 14 }}>
        <T k="caption">Can’t find it?</T>
        <Link title="Enter address by hand" k="caption" />
      </HStack>
    </Screen>
  );
}

// MARK: C10 Floor and slot

const FLOORS = ["B3", "B2", "B1", "Ground", "Open"];

export function FloorSlotScreen() {
  const { store, router } = useApp();
  const [floor, setFloor] = useState<string | null>(store.draft.place?.floor ?? "B2");
  const [slot, setSlot] = useState(store.draft.place?.slot ? store.draft.place.slot : "41");
  return (
    <Screen header={<BookingHeader step={3} label="Place" fraction={0.6} />}
      footer={<FooterBar showCall={false}><Button title="Next" enabled={floor != null} onClick={() => {
        if (store.draft.place) { store.draft.place.floor = floor; store.draft.place.slot = slot.trim(); }
        router.push({ n: "entryNotes" });
      }} /></FooterBar>}>
      <TitleBlock title="Where is it parked?" subtitle={store.draft.place ? PlaceFmt.title(store.draft.place) : ""} />
      <SectionLabel text="Parking floor" />
      <Flow style={{ paddingBottom: 26 }}>
        {FLOORS.map((f) => <Chip key={f} title={f} selected={floor === f} onClick={() => setFloor(f)} />)}
      </Flow>
      <TextField label="Slot number" value={slot} onChange={setSlot} placeholder="Slot number" helper="Optional, but it saves the captain time" leadingIcon="parking" caps="characters" />
    </Screen>
  );
}

// MARK: C11 Notes for the captain

export function EntryNotesScreen() {
  const { store, router } = useApp();
  const [text, setText] = useState(store.draft.note.text);
  const [voice, setVoice] = useState<number | null>(store.draft.note.voiceSeconds ?? 12);
  const [playing, setPlaying] = useState(false);
  const recordButton = (icon: IconName, title: string, action: () => void) => (
    <Tap onClick={action} style={{ flex: 1, height: 48, borderRadius: 10, boxShadow: `inset 0 0 0 1px ${C.border}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
      <Icon name={icon} size={17} />
      <T k="bodyStrong" c={C.heading} w={500}>{title}</T>
    </Tap>
  );
  return (
    <Screen header={<BookingHeader step={3} label="Place" fraction={0.8} />}
      footer={<FooterBar showCall={false}><Button title="Next" onClick={() => {
        store.draft.note.text = text;
        store.draft.note.voiceSeconds = voice;
        router.push({ n: "timeSlot" });
      }} /></FooterBar>}>
      <TitleBlock title="Anything the captain should know?" subtitle="Optional. Gate, lift, landmarks." />
      <TextArea value={text} onChange={setText} placeholder="Example: use the B2 ramp near the gym, white car next to the pillar" />
      <TD k="label" style={{ paddingTop: 22, paddingBottom: 8 }}>Or record it</TD>
      <HStack gap={12}>
        {recordButton("mic", "Voice note", () => setVoice(12))}
        {recordButton("video", "Video", () => { store.draft.note.videoSeconds = 10; })}
      </HStack>
      {voice != null && (
        <HStack gap={12} style={{ padding: "0 14px", height: 62, borderRadius: 16, background: C.canvas, marginTop: 20 }}>
          <Tap onClick={() => setPlaying(!playing)} label={playing ? "Pause" : "Play"} style={{ width: 40, height: 40, borderRadius: 20, background: C.primaryTint, display: "grid", placeItems: "center" }}>
            <Icon name={playing ? "pause" : "play"} size={16} color={C.primaryStrong} fill />
          </Tap>
          <div style={{ flex: 1, height: 3, borderRadius: 3, background: C.border, overflow: "hidden" }}>
            {playing && <div className="wh-upload" style={{ height: 3, background: C.primary }} />}
          </div>
          <T k="caption" mono>{Fmt.clock(voice)}</T>
          <Tap onClick={() => setVoice(null)} label="Delete voice note" style={{ padding: 4 }}><Icon name="trash" size={18} color={C.destructive} /></Tap>
        </HStack>
      )}
    </Screen>
  );
}

// MARK: C12 Time slot (C12b no captains today)

export function TimeSlotScreen() {
  const { store, router } = useApp();
  const today = startOfDay(new Date());
  const days = [0, 1, 2].map((i) => addDays(today, i));
  const [dayIndex, setDayIndex] = useState(0);
  const slots = store.timeSlots(days[dayIndex]);
  const [picked, setPicked] = useState<TimeSlot | null>(() => {
    const s = store.draft.slot;
    if (s && s.available) return s;
    return slots.find((x) => x.available) ?? null;
  });
  const noneFree = !slots.some((s) => s.available);
  const changeDay = (i: number) => { setDayIndex(i); setPicked(store.timeSlots(days[i]).find((x) => x.available) ?? null); };
  return (
    <Screen header={<BookingHeader step={4} label="Time" fraction={0.8} />}
      footer={<FooterBar showCall={false}><Button title="Next" enabled={picked != null && !noneFree} onClick={() => { store.draft.slot = picked; router.push({ n: "review" }); }} /></FooterBar>}>
      <TitleBlock title="When should we come?" subtitle={noneFree ? null : "The captain arrives any time in this window."} />
      <div style={{ paddingBottom: 20 }}><Segmented options={days.map((d) => Fmt.day(d))} selection={dayIndex} onChange={changeDay} /></div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        {slots.map((s) => (
          <Chip key={s.startHour} title={Slot.label(s)} selected={Slot.same(picked, s)} enabled={s.available} strike={!s.available} height={54} fill onClick={() => setPicked(s)} />
        ))}
      </div>
      {noneFree ? (
        <Banner tone="wait" icon="search" text="No captains free today in your society. Tomorrow has slots from 6 AM." actionTitle="See tomorrow" onAction={() => changeDay(1)} style={{ marginTop: 20 }} />
      ) : (
        <TD k="caption" style={{ paddingTop: 18 }}>No need to be home. A captain comes in your slot and cleans your vehicle just the way you asked.</TD>
      )}
    </Screen>
  );
}

// MARK: C13 Check and pay (+ C17 pay sheet)

export function ReviewScreen() {
  const { store, router } = useApp();
  const d = store.draft;
  const price = Draft.price(d);
  const free = store.customer?.freeWashes ?? 0;
  return (
    <Screen header={<BookingHeader step={5} label="Pay" fraction={1} />}
      footer={<FooterBar showCall={false}><Button title="Continue to pay" onClick={() => {
        if (store.isLoggedIn) router.showPaySheet = true; else router.push({ n: "login" });
      }} /></FooterBar>}>
      <TitleBlock title="Check and pay" />
      <Tap onClick={() => router.pop()} style={{ ...card(16, 16), display: "flex", alignItems: "center", gap: 14, textAlign: "left", marginBottom: 18 }}>
        <IconBox icon={d.type ? VT.icon(d.type) : "car"} size={48} radius={12} />
        <VStack gap={6} align="start" style={{ flex: 1 }}>
          <Plate text={d.plate || "TS 09 EA 4521"} />
          <TD k="caption">{`${d.type ? VT.short(d.type) : ""}${d.wash ? ` · ${Wash.short(d.wash)}` : ""} · ${d.place?.tower ?? ""} · ${d.place ? PlaceFmt.parkingShort(d.place) : ""}`}</TD>
        </VStack>
        <Icon name="chevron" size={15} color={C.secondary} />
      </Tap>
      <KeyValueCard boldLast rows={[
        ["When", d.slot ? Slot.full(d.slot) : ""],
        ["Wash", "Exterior · water and cloth"],
        ["Notes", Note.summary(d.note)],
        ["Total", Fmt.rupees(price)],
      ]} />
      {free > 0 && (
        <ToggleRow on={d.useFreeWash} onChange={(v) => { store.draft.useFreeWash = v; }} tint={C.success} style={{ paddingTop: 14 }}>
          <T k="bodyStrong">{`Use a free wash (${free} left)`}</T>
        </ToggleRow>
      )}
      <HeldSafelyBanner amount={price} style={{ marginTop: 18 }} />
      <Sheet open={router.showPaySheet} onClose={() => { router.showPaySheet = false; }} height={520}>
        <PayMethodSheet />
      </Sheet>
    </Screen>
  );
}

// MARK: C17 Payment method sheet

export function PayMethodSheet() {
  const { store, router } = useApp();
  const price = Draft.price(store.draft);
  return (
    <VStack gap={10}>
      <HStack style={{ paddingBottom: 4 }}>
        <T k="section" w={600} mono>{`Pay ${Fmt.rupees(price)}`}</T>
        <div style={{ flex: 1 }} />
        <Badge text="Held until you approve" tone="mute" icon="shield" />
      </HStack>
      {store.paymentMethods.map((m) => (
        <SelectionTile key={m.id} icon="receipt" title={m.title} subtitle={m.detail} selected={store.payMethodId === m.id} radio iconTone="mute" onClick={() => { store.payMethodId = m.id; }} />
      ))}
      <Button title={`Pay ${Fmt.rupees(price)}`} kind="success" style={{ marginTop: 6 }} onClick={() => { router.showPaySheet = false; router.push({ n: "paying", view: "processing" }); }} />
      <TD k="caption" center>Secured by Razorpay. Full refund if no captain comes.</TD>
    </VStack>
  );
}
