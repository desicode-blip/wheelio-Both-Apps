"use client";

import { useEffect, useRef, useState } from "react";
import { C } from "../../ds/tokens";
import {
  AppBar, Avatar, Badge, Banner, Button, Chip, Flow, FooterBar, FullState, HStack, IconBox, Link, Pager, PageDots, PhotoPlaceholder,
  Screen, Sheet, StackedFooter, StateCircle, StatusSteps, Tap, T, TD, VStack, card, outlined,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt, Support } from "../../lib/fmt";
import { useApp, useOnAppear } from "../ctx";
import { angleLabel, awaitingUPI, BusinessRules, PhotoAngles, Slot, type Order } from "../model";
import { CaptainCard, OrderHeader, PlainHeader } from "./parts";
import { DisputeStatusScreen } from "./problem";

const liveSteps = [{ title: "Booked" }, { title: "Captain on the way" }, { title: "Washing" }, { title: "Check photos" }];

// MARK: Live order (C20, C21, C22, C22b, C23, C24, C25, C28, C29b, C30)

export function LiveOrderScreen() {
  const { store, router } = useApp();
  const [showCancel, setShowCancel] = useState(false);
  const o = store.currentOrder;
  useOnAppear(() => {
    store.viewingOrderId = store.currentOrderId;
    return () => { if (!router.is("live") && !router.is("booked")) store.viewingOrderId = null; };
  });
  const status = o?.status;
  const prevStatus = useRef(status);
  useEffect(() => {
    if (prevStatus.current !== status && status === "approved" && o?.rating == null) router.replace([{ n: "rate" }]);
    prevStatus.current = status;
  }, [status, o, router]);

  let body: React.ReactNode;
  if (!o) {
    body = <Screen header={<PlainHeader />}><FullState icon="calendar" title="No active booking" primary="Go home" onPrimary={() => router.popToRoot()} /></Screen>;
  } else {
    switch (o.status) {
      case "searching": case "paymentPending": case "pendingPayment": body = <Searching o={o} onCancel={() => setShowCancel(true)} />; break;
      case "noCaptain":
        body = <AutoCancelled o={o} icon="search" title="No captain could take your wash" why="We couldn’t find a free captain, so we’ve cancelled the booking." />; break;
      case "captainNoShow":
        body = <AutoCancelled o={o} icon="clock" title={`${o.captain?.name ?? "Your captain"} didn’t turn up`}
          why="The wash wasn’t done in your slot. We’re sorry. You get the full amount back by 11:59 PM tonight, and we’ve taken action with the captain." />; break;
      case "onTheWay": body = o.captainCantFind ? <CantFind o={o} /> : <OnTheWay o={o} onCancel={() => setShowCancel(true)} />; break;
      case "washing": body = <Washing o={o} />; break;
      case "photosReady": body = <CheckWashView order={o} />; break;
      case "cancelled":
        body = (
          <Screen scrolls={false} header={<PlainHeader />}>
            <FullState icon="check" tone="ok" title="Booking cancelled"
              message={`${Fmt.rupees(o.refund?.amount ?? o.price)} is on its way back to your UPI. It usually takes 2 to 3 working days.`}
              primary="Book another time" secondary="Track refund"
              onPrimary={() => { store.startRepeat(o.vehicle); router.replace([{ n: "timeSlot" }]); }}
              onSecondary={() => router.push({ n: "refund" })} />
          </Screen>
        ); break;
      case "autoApproved":
        body = (
          <Screen scrolls={false} header={<PlainHeader />}>
            <FullState icon="clock" title="Approved automatically"
              message={`We didn’t hear from you by midnight, so the wash was approved and ${Fmt.rupees(o.price)} went to ${o.captain?.name ?? "Raju"}. Something wrong? You can still report it until midnight tomorrow.`}
              primary={`Rate ${o.captain?.name ?? "Raju"}`} secondary="Report a problem"
              onPrimary={() => router.push({ n: "rate" })} onSecondary={() => router.push({ n: "reportProblem" })} />
          </Screen>
        ); break;
      case "approved":
        body = (
          <Screen scrolls={false} header={<PlainHeader />}>
            <FullState icon="sparkle" tone="ok" title="Wash approved" message={`${Fmt.rupees(o.price)} released to ${o.captain?.name ?? "Raju"}.`} primary="Go home" onPrimary={() => router.popToRoot()} />
          </Screen>
        ); break;
      default: body = <DisputeStatusScreen />;
    }
  }
  return (
    <>
      {body}
      <Sheet open={showCancel} onClose={() => setShowCancel(false)} height={store.currentOrder?.status === "onTheWay" ? 360 : 420}>
        <CancelSheet onDone={() => setShowCancel(false)} />
      </Sheet>
    </>
  );
}

/** No captain / captain no-show: cancelled automatically, full refund to the customer's UPI. */
function AutoCancelled({ o, icon, title, why }: { o: Order; icon: IconName; title: string; why: string }) {
  const { store, router } = useApp();
  const r = o.refund;
  const waiting = r ? awaitingUPI(r) : true;
  const again = () => { store.startRepeat(o.vehicle); router.replace([{ n: "timeSlot" }]); };
  return (
    <Screen scrolls={false} header={<PlainHeader />}
      footer={
        <StackedFooter>
          {waiting ? (
            <>
              <Button title="Add UPI ID for refund" icon="rupee" onClick={() => router.push({ n: "refundUPI", id: o.id })} />
              <Button title="Book another time" kind="text" onClick={again} />
            </>
          ) : (
            <>
              <Button title="Book another time" onClick={again} />
              <Button title="See refund" kind="text" onClick={() => router.push({ n: "refund" })} />
            </>
          )}
        </StackedFooter>
      }>
      <div style={{ paddingTop: 10 }}><StateCircle icon={icon} tone="wait" size={72} /></div>
      <TD k="screen" style={{ paddingTop: 18 }}>{title}</TD>
      <TD k="body" style={{ paddingTop: 8 }}>{why}</TD>
      <VStack gap={8} style={{ ...card(16), marginTop: 20 }}>
        <HStack>
          <T k="label">Full refund</T>
          <div style={{ flex: 1 }} />
          <T k="valueStrong" mono>{Fmt.rupees(r?.amount ?? o.price)}</T>
        </HStack>
        <TD k="caption">{waiting ? "Tell us your UPI ID and we’ll send it there." : `Going to ${r?.upi ?? "your UPI"}. Usually within 2 to 3 working days.`}</TD>
      </VStack>
    </Screen>
  );
}

/** Pulsing search circle for "Finding a captain…". */
export function SearchPulse({ size = 96 }: { size?: number }) {
  return (
    <div style={{ position: "relative", width: size, height: size, display: "grid", placeItems: "center" }}>
      <span className="wh-pulse" style={{ position: "absolute", inset: 0, borderRadius: "50%", background: C.primaryTint }} />
      <Icon name="search" size={size * 0.36} color={C.primaryStrong} weight={500} style={{ position: "relative" }} />
    </div>
  );
}

// C20 Finding a captain
function Searching({ o, onCancel }: { o: Order; onCancel: () => void }) {
  const { router } = useApp();
  return (
    <Screen canvas header={<OrderHeader order={o} />}
      footer={<StackedFooter><Button title="Keep me posted" onClick={() => router.popToRoot()} /><Button title="Cancel booking" kind="text" onClick={onCancel} /></StackedFooter>}>
      <VStack align="center" style={{ ...card(22), marginTop: 14, marginBottom: 28 }}>
        <div style={{ paddingBottom: 22 }}><SearchPulse /></div>
        <TD k="section" w={600}>Finding a captain…</TD>
        <TD k="body" center style={{ paddingTop: 8, paddingBottom: 14 }}>Usually under 5 minutes. You can leave this screen; we’ll notify you.</TD>
        <Badge text={`${Fmt.rupees(o.price)} held safely`} tone="mute" icon="shield" />
      </VStack>
      <StatusSteps steps={liveSteps} current={0} />
    </Screen>
  );
}

// C22 on the way, C22b pass missing, C24 running late
function OnTheWay({ o, onCancel }: { o: Order; onCancel: () => void }) {
  const { router } = useApp();
  const late = o.runningLateMinutes != null;
  const arrives = o.arrivesBy ?? new Date();
  const name = o.captain?.name ?? "Raju";
  return (
    <Screen canvas header={<OrderHeader order={o} />}
      footer={
        <StackedFooter>
          {late ? <Button title={`Call ${name}`} icon="phone" kind="outline" onClick={() => Support.call()} />
            : o.entryPassReceived ? <Button title="Message on WhatsApp" icon="whatsapp" kind="outline" onClick={() => router.push({ n: "whatsApp" })} />
            : <Button title="Send pass on WhatsApp" icon="whatsapp" onClick={() => router.push({ n: "whatsApp" })} />}
          <Button title="Cancel booking" kind="text" onClick={onCancel} />
        </StackedFooter>
      }>
      {late ? (
        <>
          <CaptainCard order={o} style={{ marginTop: 14 }}
            badge={o.noShowChecking ? <Badge text="Checking" tone="wait" icon="search" /> : <Badge text="Running late" tone="wait" icon="clock" />}
            timeText={`Now arriving ${Fmt.time(new Date(arrives.getTime() + ((o.runningLateMinutes ?? 0) + 30) * 60000))}`} />
          {o.noShowChecking ? (
            <Banner tone="wait" icon="search" title="We’re checking on your wash." style={{ marginTop: 16 }}
              text={`Your slot ended at ${Fmt.time(Slot.end(o.slot))} and ${name} hasn’t updated it. If the wash doesn’t happen, you get a full refund by 11:59 PM tonight.`} />
          ) : (
            <Banner tone="wait" icon="clock" style={{ marginTop: 16 }}
              text={`${name} is running about ${o.runningLateMinutes ?? 15} minutes late. If the wash doesn’t happen in your slot (till ${Fmt.time(Slot.end(o.slot))}), we’ll check with him. No wash means a full refund.`} />
          )}
        </>
      ) : (
        <>
          <CaptainCard order={o} style={{ marginTop: 14 }} badge={<Badge text="Accepted" tone="info" icon="check" />} timeText={`Arrives by ${Fmt.time(arrives)}`} />
          {o.entryPassReceived ? (
            <HStack gap={12} style={{ padding: "0 16px", minHeight: 44, borderRadius: 12, background: C.successTint, marginTop: 16 }}>
              <Icon name="check" size={16} color={C.onSuccess} weight={600} />
              <T k="caption" c={C.onSuccess} s={14}>{`Entry pass received. ${name} can get in.`}</T>
            </HStack>
          ) : (
            <Banner tone="wait" icon="door" title="We still need your gate pass." text={`Without it ${name} may be stopped at the gate.`}
              actionTitle="Send now" onAction={() => router.push({ n: "whatsApp" })} style={{ marginTop: 16 }} />
          )}
        </>
      )}
      <div style={{ paddingTop: 26 }}><StatusSteps steps={liveSteps} current={1} /></div>
    </Screen>
  );
}

// C30 Captain can't find vehicle
function CantFind({ o }: { o: Order }) {
  const { store } = useApp();
  const name = o.captain?.name ?? "Raju";
  const answer = (icon: IconName, title: string, action: () => void) => (
    <Tap onClick={action} style={{ height: 48, borderRadius: 10, background: "#fff", boxShadow: `inset 0 0 0 1px ${C.border}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <Icon name={icon} size={16} />
      <T k="bodyStrong" c={C.heading} w={500}>{title}</T>
    </Tap>
  );
  return (
    <Screen canvas header={<OrderHeader order={o} />}
      footer={<FooterBar showCall={false}><Button title={`Call ${name}`} icon="phone" onClick={() => Support.call()} /></FooterBar>}>
      <VStack gap={12} style={{ ...card(18), marginTop: 14, marginBottom: 18 }}>
        <HStack gap={12}>
          <IconBox icon="warning" size={44} tone="wait" radius={12} />
          <TD k="title">{`${name} can’t find your vehicle`}</TD>
        </HStack>
        <TD k="body">{`He’s at ${o.place.floor ?? "B2"} near slot ${o.place.slot || "41"} and doesn’t see ${o.vehicle.plate}. Is it parked somewhere else today?`}</TD>
      </VStack>
      <VStack gap={10}>
        {answer("layers", "It’s on a different floor", () => store.answerCantFind("other_floor"))}
        {answer("location", "I moved it outside", () => store.answerCantFind("outside"))}
        {answer("close", "It’s not here today", () => store.answerCantFind("not_here"))}
      </VStack>
    </Screen>
  );
}

// C23 Washing
function Washing({ o }: { o: Order }) {
  const { store, router } = useApp();
  return (
    <Screen canvas header={<OrderHeader order={o} />}
      footer={
        // Calling the captain lives in the card above; the footer moves the customer on.
        <StackedFooter>
          <Button title="Book another wash" kind="outline" onClick={() => { store.startNewBooking(); router.replace([{ n: "vehicleType" }]); }} />
          <Button title="Go home" kind="text" onClick={() => { router.tab = 0; router.popToRoot(); }} />
        </StackedFooter>
      }>
      <CaptainCard order={o} style={{ marginTop: 14 }} badge={<Badge text="Cleaning" tone="info" icon="drop" />} timeText={`Started ${Fmt.time(o.startedAt ?? new Date())}`} />
      <VStack gap={12} style={{ ...outlined(16), marginTop: 16 }}>
        <HStack><TD k="title" style={{ flex: 1 }}>Before photos</TD><T k="caption">4 of 4</T></HStack>
        <HStack gap={8}>{[0, 1, 2, 3].map((i) => <PhotoPlaceholder key={i} height={56} />)}</HStack>
      </VStack>
      <div style={{ paddingTop: 24 }}><StatusSteps steps={liveSteps} current={2} /></div>
    </Screen>
  );
}

// MARK: C29 Cancel sheet (C29c after accept)

function CancelSheet({ onDone }: { onDone: () => void }) {
  const { store } = useApp();
  const [reason, setReason] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const o = store.currentOrder;
  const accepted = o?.status === "onTheWay";
  const name = o?.captain?.name ?? "Raju";
  return (
    <VStack gap={14}>
      <TD k="section" w={600}>{accepted ? `${name} is already on the way` : "Cancel this wash?"}</TD>
      {accepted ? (
        <Banner tone="wait" icon="rupee" text={`Cancelling now refunds ₹${BusinessRules.refundAmountText}. ₹${BusinessRules.cancellationFeeText} goes to ${name} for the trip.`} />
      ) : (
        <>
          <Banner tone="info" icon="rupee" text={`No captain has accepted yet, so you get the full ${Fmt.rupees(o?.price ?? 149)} back.`} />
          <TD k="label">Why are you cancelling? (optional)</TD>
          <Flow>
            {["Changed plans", "Booked by mistake", "Taking too long", "Other"].map((r) => <Chip key={r} title={r} selected={reason === r} onClick={() => setReason(r)} />)}
          </Flow>
        </>
      )}
      <Button title={accepted ? "Cancel anyway" : "Yes, cancel and refund"} kind="danger" loading={loading} style={{ marginTop: 4 }} onClick={async () => {
        if (!o) return;
        setLoading(true);
        await store.cancel(o.id).catch(() => {});
        setLoading(false);
        onDone();
      }} />
      <Button title="Keep booking" kind="text" onClick={onDone} />
    </VStack>
  );
}

// MARK: C25 Check the wash

function CheckWashView({ order }: { order: Order }) {
  const { store, router } = useApp();
  const [approving, setApproving] = useState(false);
  const name = order.captain?.name ?? "Raju";
  const pair = (label: string) => (
    <VStack gap={8}>
      <T k="label" c={C.heading} w={500}>{label}</T>
      <Tap onClick={() => router.push({ n: "photoCompare" })} style={{ display: "flex", gap: 10 }}>
        <PhotoPlaceholder height={110} icon="car" tag="Before" />
        <PhotoPlaceholder height={110} icon="sparkle" tag="After" tagTone="ok" />
      </Tap>
    </VStack>
  );
  return (
    <Screen
      header={<AppBar title="Check the wash" subtitle={`${name} finished at ${Fmt.time(order.finishedAt ?? new Date())}`} onLeading={() => router.popToRoot()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 14px 0" }} />}
      footer={
        <StackedFooter>
          <Button title="Approve" icon="check" kind="success" loading={approving} onClick={async () => {
            setApproving(true);
            await store.approve(order.id).catch(() => {});
            setApproving(false);
            router.replace([{ n: "rate" }]);
          }} />
          <T k="small" c={C.muted} style={{ paddingTop: 6 }}>Auto-approves at 12 midnight if you don’t respond</T>
          <Button title="Something’s wrong" kind="text" onClick={() => router.push({ n: "reportProblem" })} />
        </StackedFooter>
      }>
      <HStack gap={12} style={{ paddingTop: 14, paddingBottom: 18 }}>
        <IconBox icon="sparkle" size={48} tone="ok" radius={24} />
        <VStack gap={1}>
          <TD k="section" w={600}>Shine restored</TD>
          <TD k="caption">{`Approve to release ${Fmt.rupees(order.price)} to ${name}`}</TD>
        </VStack>
      </HStack>
      {pair("Front")}
      <div style={{ paddingTop: 14 }}>{pair("Left side")}</div>
      <Link title="See all 4 angles" onClick={() => router.push({ n: "photoCompare" })} style={{ marginTop: 16, alignSelf: "flex-start" }} />
    </Screen>
  );
}

// MARK: C26 Photo compare

export function PhotoCompareScreen() {
  const { store, router } = useApp();
  const [page, setPage] = useState(0);
  const o = store.currentOrder;
  return (
    <div className="wh-fill" style={{ background: C.camera, paddingTop: "var(--sat)", paddingBottom: "var(--sab)" }}>
      <AppBar title={`${angleLabel(PhotoAngles[page]).replace(" side", "")} · ${page + 1} of 4`} leading="close" trailing={null} dark onLeading={() => router.pop()} style={{ padding: "0 14px" }} />
      <Pager count={4} index={page} onIndex={setPage} style={{ flex: 1, minHeight: 0 }} render={() => (
        <div style={{ position: "absolute", inset: "0 16px 36px" }}><CompareSlider /></div>
      )} />
      <div style={{ padding: "10px 0 6px" }}><PageDots count={4} index={page} /></div>
      <HStack gap={6} style={{ alignSelf: "center", padding: 6, borderRadius: 999, background: C.inverse, margin: "10px 0 16px" }}>
        <Tap label="Zoom" style={{ width: 48, height: 48, display: "grid", placeItems: "center" }}><Icon name="zoom" size={20} color="#fff" /></Tap>
        <Tap label="Report a problem" onClick={() => { router.pop(); router.push({ n: "reportProblem" }); }} style={{ width: 48, height: 48, display: "grid", placeItems: "center" }}><Icon name="flag" size={20} color="#fff" /></Tap>
        <Button title="Approve" icon="check" kind="success" fullWidth={false} onClick={async () => {
          if (!o) return;
          await store.approve(o.id).catch(() => {});
          router.replace([{ n: "rate" }]);
        }} />
      </HStack>
    </div>
  );
}

function CompareSlider() {
  const [split, setSplit] = useState(0.5);
  const ref = useRef<HTMLDivElement>(null);
  const [drag, setDrag] = useState(false);
  const move = (x: number) => {
    const r = ref.current?.getBoundingClientRect();
    if (r) setSplit(Math.min(0.9, Math.max(0.1, (x - r.left) / r.width)));
  };
  return (
    <div ref={ref} style={{ position: "absolute", inset: 0, borderRadius: 20, overflow: "hidden", background: "#2A3A50" }}>
      <div style={{ position: "absolute", top: 0, bottom: 0, right: 0, width: `${(1 - split) * 100}%`, background: "#33445C" }} />
      <div style={{ position: "absolute", left: "25%", top: "50%", transform: "translate(-50%,-50%)" }}><Icon name="car" size={46} color="rgba(255,255,255,.55)" /></div>
      <div style={{ position: "absolute", left: "75%", top: "50%", transform: "translate(-50%,-50%)" }}><Icon name="sparkle" size={46} color="rgba(255,255,255,.9)" /></div>
      <div style={{ position: "absolute", top: 0, bottom: 0, left: `${split * 100}%`, width: 2, marginLeft: -1, background: "#fff" }} />
      <div
        onPointerDown={(e) => { e.stopPropagation(); (e.target as HTMLElement).setPointerCapture(e.pointerId); setDrag(true); }}
        onPointerMove={(e) => { if (drag) { e.stopPropagation(); move(e.clientX); } }}
        onPointerUp={() => setDrag(false)}
        style={{ position: "absolute", top: "50%", left: `${split * 100}%`, width: 44, height: 44, marginLeft: -22, marginTop: -22, borderRadius: 22, background: "#fff", display: "grid", placeItems: "center", cursor: "ew-resize", touchAction: "none" }}>
        <Icon name="chevron" size={14} />
      </div>
      <div style={{ position: "absolute", top: 12, left: 12 }}><Badge text="Before · 8:33 AM" tone="mute" solid /></div>
      <div style={{ position: "absolute", top: 12, right: 12 }}><Badge text="After · 8:53 AM" tone="ok" /></div>
    </div>
  );
}

// MARK: C27 Rate

export function RateScreen() {
  const { store, router } = useApp();
  const [stars, setStars] = useState(4);
  const [tags, setTags] = useState<string[]>(["Spotless", "On time"]);
  const o = store.currentOrder;
  const name = o?.captain?.name ?? "Raju";
  return (
    <Screen header={<AppBar leading={null} trailing="close" onTrailing={() => router.popToRoot()} style={{ padding: "4px 14px 0" }} />}
      footer={<FooterBar showCall={false}><Button title="Submit" onClick={() => { if (o) store.rate(o.id, stars).catch(() => {}); router.popToRoot(); }} /></FooterBar>}>
      <VStack align="center">
        <div style={{ paddingTop: 20 }}><Avatar initials={o?.captain?.initials ?? "RY"} size={72} /></div>
        <TD k="screen" style={{ paddingTop: 18 }}>{`How did ${name} do?`}</TD>
        <TD k="body" center style={{ paddingTop: 8 }}>{`${Fmt.rupees(o?.price ?? 149)} released to ${name}. Thanks for approving.`}</TD>
        <HStack gap={14} style={{ paddingTop: 26, paddingBottom: 24 }}>
          {[1, 2, 3, 4, 5].map((i) => (
            <Tap key={i} label={`${i} stars`} onClick={() => setStars(i)}>
              <Icon name={i <= stars ? "starFill" : "star"} size={36} color={i <= stars ? C.star : C.muted} />
            </Tap>
          ))}
        </HStack>
        <Flow style={{ width: 320, justifyContent: "flex-start" }}>
          {["Spotless", "On time", "Polite", "Missed a spot", "Late"].map((t) => (
            <Chip key={t} title={t} selected={tags.includes(t)} onClick={() => setTags(tags.includes(t) ? tags.filter((x) => x !== t) : [...tags, t])} />
          ))}
        </Flow>
      </VStack>
    </Screen>
  );
}
