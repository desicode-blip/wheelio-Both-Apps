"use client";

import { useState } from "react";
import { C } from "../../ds/tokens";
import {
  AppBar, Avatar, Banner, Button, Divider, FooterBar, FullState, HStack, OtpField, PhoneField, Screen, SelectionTile, StackedFooter,
  StateCircle, Tap, T, TD, TextField, TitleBlock, VStack, card,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt, sleep, Support, Validators } from "../../lib/fmt";
import { useApp } from "../ctx";
import type { HelpTopic } from "../store";

// MARK: Change phone number

export function ChangePhoneScreen() {
  const { store, router } = useApp();
  const [stage, setStage] = useState<"number" | "code" | "done">("number");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [wrong, setWrong] = useState(false);
  const [loading, setLoading] = useState(false);
  const current = store.customer?.phone ?? "";
  const digits = Validators.digitsOnly(phone).slice(0, 10);
  const canSend = Validators.isValidMobile(phone) && digits !== current;

  const send = async () => {
    if (!canSend) return;
    setLoading(true);
    await store.requestPhoneChange(digits).catch(() => {});
    setLoading(false); setCode(""); setWrong(false); setStage("code");
  };
  const verify = async (c = code) => {
    if (loading || c.length !== 6) return;
    setLoading(true);
    const ok = await store.confirmPhoneChange(c).catch(() => false);
    setLoading(false);
    if (ok) setStage("done"); else setWrong(true);
  };

  return (
    <Screen header={<AppBar title="Phone number" trailing={null} onLeading={() => router.pop()} style={{ padding: "4px 14px 0" }} />}
      footer={stage !== "done" ? (
        <FooterBar showCall={false}>
          {stage === "number" ? <Button title="Send code" enabled={canSend} loading={loading} onClick={send} />
            : <Button title="Verify and change" enabled={code.length === 6} loading={loading} onClick={() => verify()} />}
        </FooterBar>
      ) : undefined}>
      {stage === "number" && (
        <>
          <TitleBlock top={14} title="Change your number" subtitle={`Now: ${Fmt.phone(current)}. We’ll send a code to the new number to check it’s yours.`} />
          <PhoneField number={phone} onChange={setPhone} />
          {digits === current && current && <TD k="caption" style={{ paddingTop: 8 }}>That’s your current number.</TD>}
        </>
      )}
      {stage === "code" && (
        <>
          <TD k="screen" style={{ paddingTop: 14 }}>Enter the code</TD>
          <TD k="body" style={{ paddingTop: 6, paddingBottom: 22 }}>{`Sent to ${Fmt.phone(digits)}. Your number changes only after this.`}</TD>
          <OtpField code={code} error={wrong} boxSize={46} onChange={(v) => { setCode(v); if (wrong && v.length < 6) setWrong(false); if (v.length === 6) verify(v); }} />
          {wrong && <TD k="caption" c={C.destructive} style={{ paddingTop: 14 }}>That code doesn’t match. Try again.</TD>}
          <TD k="caption" c={C.muted} style={{ paddingTop: 30 }}>Demo code: 123456</TD>
        </>
      )}
      {stage === "done" && (
        <div style={{ paddingTop: 40 }}>
          <FullState icon="check" tone="ok" title="Number updated" message={`We’ll use ${Fmt.phone(store.customer?.phone ?? digits)} from now on.`} primary="Done" onPrimary={() => router.pop()} />
        </div>
      )}
    </Screen>
  );
}

// MARK: Help and support

export const HelpTopics: HelpTopic[] = ["notClean", "late", "booking", "payment", "other"];
const topicTitle = (t: HelpTopic) => ({ notClean: "Wash wasn’t done well", late: "Captain is late or didn’t come", booking: "Change or cancel a booking", payment: "Payment or refund", other: "Something else" })[t];
const topicIcon = (t: HelpTopic): IconName => ({ notClean: "sparkle", late: "clock", booking: "calendar", payment: "rupee", other: "chat" } as const)[t];

const faqs: [string, string][] = [
  ["When is my money taken?", "Your bank holds the amount when you book. It goes to the captain only after you approve the after-photos, or automatically at midnight if you don’t respond."],
  ["What if the captain doesn’t come?", "If no captain accepts, or the wash doesn’t start in your window, you get a full refund to your UPI in 2 to 3 working days."],
  ["Can I cancel?", "Yes. Before a captain accepts, you get the full amount back. After that a small trip fee goes to the captain."],
];

/** C48 Help: pick what's going on. Everything goes to the captain first; only emergencies reach the team. */
export function HelpScreen() {
  const { router } = useApp();
  const [open, setOpen] = useState<number | null>(null);
  return (
    <Screen header={<AppBar title="Help" trailing={null} onLeading={() => router.pop()} style={{ padding: "4px 14px 0" }} />}>
      <TitleBlock top={14} title="How can we help?" subtitle="Pick what’s going on." />
      <VStack gap={10}>
        {HelpTopics.map((t) => <SelectionTile key={t} icon={topicIcon(t)} title={topicTitle(t)} onClick={() => router.push({ n: "helpCaptain", topic: t })} />)}
        <SelectionTile icon="warning" title="Emergency" subtitle="Damage, an accident or a safety worry" iconTone="error" onClick={() => router.push({ n: "helpEmergency" })} />
      </VStack>
      <TD k="label" style={{ paddingTop: 26, paddingBottom: 4 }}>Common questions</TD>
      {faqs.map(([q, a], i) => (
        <div key={i}>
          <Tap className="wh-nopress" onClick={() => setOpen(open === i ? null : i)} style={{ display: "flex", flexDirection: "column", gap: 8, padding: "16px 0", width: "100%", textAlign: "left" }}>
            <HStack>
              <TD k="rowTitle" style={{ flex: 1 }}>{q}</TD>
              <Icon name="chevron" size={15} color={C.secondary} style={{ transform: `rotate(${open === i ? 90 : 0}deg)`, transition: "transform .2s" }} />
            </HStack>
            {open === i && <TD k="body" style={{ animation: "wh-fade .25s both" }}>{a}</TD>}
          </Tap>
          <Divider />
        </div>
      ))}
    </Screen>
  );
}

/** Sort it out with your latest captain. "Still not sorted?" only leads to us for emergencies. */
export function HelpCaptainScreen({ topic }: { topic: HelpTopic }) {
  const { store, router } = useApp();
  const [stillNotSorted, setStillNotSorted] = useState(false);
  const [pinged, setPinged] = useState(false);
  const o = store.latestCaptainOrder;
  const w = o?.captain;
  return (
    <Screen canvas header={<AppBar title="Help" trailing={null} onLeading={() => router.pop()} style={{ padding: "4px 14px 0" }} />}
      footer={o && !stillNotSorted && !pinged ? <StackedFooter><Button title="Still not sorted?" kind="text" onClick={() => setStillNotSorted(true)} /></StackedFooter> : undefined}>
      {o && w ? (
        <>
          <TitleBlock top={14} title={`Let’s sort it with ${w.name}`} subtitle={`${topicTitle(topic)}. Your captain can fix most things fastest, often the same day.`} />
          <VStack gap={14} style={card(16)}>
            <HStack gap={12}>
              <Avatar initials={w.initials} size={50} />
              <VStack gap={2}>
                <TD k="title" w={600} s={17}>{w.name}</TD>
                <TD k="caption">{`${o.vehicle.plate} · ${Fmt.day(o.slot.date)}`}</TD>
              </VStack>
            </HStack>
            <HStack gap={10}>
              <Button title={`Call ${w.name}`} icon="phone" onClick={() => Support.call()} />
              <Button title="WhatsApp" icon="whatsapp" kind="outline" />
            </HStack>
          </VStack>
          {pinged && <Banner tone="ok" icon="check" text={`We’ve asked ${w.name} to get back to you about this.`} style={{ marginTop: 16 }} />}
          {stillNotSorted && !pinged && (
            <VStack gap={12} className="wh-slide-up" style={{ ...card(16), marginTop: 16 }}>
              <TD k="title">Is this an emergency?</TD>
              <TD k="body">Damage to your vehicle, an accident, or a safety worry.</TD>
              <Button title="Yes, it’s an emergency" kind="danger" onClick={() => router.push({ n: "helpEmergency" })} />
              <Button title={`No, ask ${w.name} again`} kind="outline" onClick={() => setPinged(true)} />
            </VStack>
          )}
        </>
      ) : (
        <>
          <TitleBlock top={14} title="Your captain is your first stop" subtitle="Once you’ve booked a wash, you can reach your captain here and sort things out directly." />
          <Button title="Book a wash" style={{ marginTop: 8 }} onClick={() => { store.startNewBooking(); router.replace([{ n: "vehicleType" }]); }} />
        </>
      )}
    </Screen>
  );
}

/** Only emergencies are connected to the team. */
export function EmergencyHelpScreen() {
  const { router } = useApp();
  return (
    <Screen header={<AppBar title="Emergency" trailing={null} onLeading={() => router.pop()} style={{ padding: "4px 14px 0" }} />}
      footer={<StackedFooter><Button title="Call us now" icon="phone" kind="danger" onClick={() => Support.call()} /><Button title="WhatsApp us" kind="text" /></StackedFooter>}>
      <div style={{ paddingTop: 20 }}><StateCircle icon="warning" tone="error" size={64} /></div>
      <TD k="screen" style={{ paddingTop: 18 }}>We’re here for emergencies</TD>
      <TD k="body" style={{ paddingTop: 6 }}>Damage to your vehicle, an accident, or a safety worry. A real person picks up.</TD>
      <TD k="caption" style={{ paddingTop: 14 }}>{Support.hours}</TD>
    </Screen>
  );
}

// MARK: Refund UPI ID

/** Asked only when a refund needs somewhere to go. Saved to the profile; with no order it edits the saved ID. */
export function RefundUPIScreen({ orderId }: { orderId: string | null }) {
  const { store, router } = useApp();
  const [upi, setUpi] = useState(store.customer?.refundUPI ?? "");
  const [showError, setShowError] = useState(false);
  const [saving, setSaving] = useState(false);
  const order = orderId ? store.order(orderId === "current" ? store.currentOrderId ?? "" : orderId) : null;
  const valid = Validators.isValidUPI(upi);
  const amount = Fmt.rupees(order?.refund?.amount ?? order?.price ?? 0);
  const save = async () => {
    if (!valid) { setShowError(true); return; }
    setSaving(true);
    await sleep(500);
    store.saveRefundUPI(upi);
    setSaving(false);
    if (order) {
      store.currentOrderId = order.id;
      store.toast = `Refund on its way to ${store.customer?.refundUPI ?? upi}`;
      router.pop();
      router.push({ n: "refund" });
    } else {
      store.toast = "UPI ID saved";
      router.pop();
    }
  };
  return (
    <Screen header={<AppBar title={order ? "Your refund" : "Refund UPI ID"} trailing={null} onLeading={() => router.pop()} style={{ padding: "4px 14px 0" }} />}
      footer={<FooterBar showCall={false}><Button title={order ? `Send ${amount} here` : "Save"} enabled={!!upi} loading={saving} onClick={save} /></FooterBar>}>
      {order ? <TitleBlock top={14} title={`Where should we send your ${amount}?`} subtitle="Refunds go to UPI only for now. Type the UPI ID you use in Google Pay, PhonePe or Paytm." />
        : <TitleBlock top={14} title="Refund UPI ID" subtitle="If we ever need to refund you, the money goes here." />}
      <TextField label="UPI ID" value={upi} onChange={(v) => { setUpi(v); setShowError(false); }} placeholder="name@okhdfc" helper="Looks like name@bank or 9876543210@ybl"
        error={showError && !valid ? "That doesn’t look like a UPI ID. Check for the @ part." : null} inputMode="email" autoFocus onSubmit={save} />
      <HStack align="start" gap={10} style={{ paddingTop: 18 }}>
        <Icon name="shield" size={15} color={C.secondary} />
        <T k="caption">We save it to your profile so you don’t have to type it again. You can change it anytime in Profile.</T>
      </HStack>
    </Screen>
  );
}
