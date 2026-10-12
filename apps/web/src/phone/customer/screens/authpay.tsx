"use client";

import { useEffect, useRef, useState } from "react";
import { Brand, C, S } from "../../ds/tokens";
import { Banner, Button, FooterBar, FullState, HStack, IconBox, Link, OtpField, PhoneField, Screen, Segmented, Tap, T, TD, TextField, TitleBlock, VStack, card } from "../../ds/components";
import { Icon } from "../../ds/icons";
import { Fmt, Validators } from "../../lib/fmt";
import { useApp, callSupport } from "../ctx";
import { PlaceFmt, Slot, VT } from "../model";
import { SAMPLE_PHONE, type OtpStart, type PayView } from "../store";
import { PlainHeader } from "./parts";
import { BrandMark } from "./start";

// MARK: C14 Log in (C14b invalid)

export function LoginScreen({ showError = false }: { showError?: boolean }) {
  const { store, router } = useApp();
  const [phone, setPhone] = useState(showError ? "98480112" : "");
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(false);
  const valid = Validators.isValidMobile(phone);
  const submit = async () => {
    if (!valid) { setError(true); return; }
    setLoading(true);
    await store.requestOtp(Validators.digitsOnly(phone).slice(0, 10)).catch(() => {});
    setLoading(false);
    router.push({ n: "otp", start: "entering" });
  };
  return (
    <Screen header={<PlainHeader />}
      footer={<FooterBar showCall={false}><Button title="Get code" enabled={!!phone && (valid || !(error || showError))} loading={loading} onClick={submit} /></FooterBar>}>
      <TitleBlock top={8} title="Almost done. What’s your number?"
        subtitle={store.returningCustomer ? "We’ll send a 6-digit code to find your account." : "We’ll send a 6-digit code. Then just your name."} />
      <div style={{ paddingBottom: 18 }}>
        <Segmented options={["I’m new here", "I’ve booked before"]} selection={store.returningCustomer ? 1 : 0} onChange={(i) => { store.returningCustomer = i === 1; }} />
      </div>
      <PhoneField number={phone} onChange={(v) => { setPhone(v); setError(false); }} error={(error || showError) && !valid ? "Enter all 10 digits" : null} />
    </Screen>
  );
}

// MARK: C15 Enter the code (C15b wrong, C15c expired)

export function OtpScreen({ start = "entering" }: { start?: OtpStart }) {
  const { store, router } = useApp();
  const [code, setCode] = useState(start === "wrong" ? "482190" : "");
  const [state, setState] = useState<OtpStart>(start);
  const [triesLeft, setTriesLeft] = useState(2);
  const [seconds, setSeconds] = useState(24);
  const [loading, setLoading] = useState(false);
  const busy = useRef(false);

  useEffect(() => {
    const t = setInterval(() => setSeconds((s) => (s > 0 ? s - 1 : 0)), 1000);
    return () => clearInterval(t);
  }, []);

  const verify = async (c = code) => {
    if (busy.current || c.length !== 6) return;
    busy.current = true;
    setLoading(true);
    const r = await store.verifyOtp(c).catch(() => null);
    busy.current = false;
    setLoading(false);
    if (!r) { router.push({ n: "offline" }); return; }
    if (r.kind === "ok") {
      // Returning customers: phone + code only. New customers also give their name.
      if (r.isNew && !store.returningCustomer) router.push({ n: "name" }); else router.finishLogin();
    } else if (r.kind === "wrong") { setTriesLeft(r.triesLeft); setState("wrong"); }
    else { setState("expired"); setCode(""); }
  };

  return (
    <Screen header={<PlainHeader />}
      footer={<FooterBar showCall={false}><Button title="Verify" enabled={code.length === 6 && state === "entering"} loading={loading} onClick={() => verify()} /></FooterBar>}>
      <TD k="screen" style={{ paddingTop: 8 }}>Enter the code</TD>
      <HStack gap={4} style={{ paddingTop: 6, paddingBottom: 22, flexWrap: "wrap" }}>
        <T k="body">{`Sent to ${Fmt.phone(store.pendingPhone || SAMPLE_PHONE)}.`}</T>
        <Link title="Change" onClick={() => router.pop()} style={{ minHeight: 22 }} />
      </HStack>
      <OtpField code={code} error={state === "wrong"} boxSize={46} onChange={(v) => {
        setCode(v);
        if (state === "wrong" && v.length < 6) setState("entering");
        if (v.length === 6) verify(v);
      }} />
      {state === "entering" && (
        <>
          <TD k="caption" style={{ paddingTop: 22 }}>{seconds > 0 ? `Resend code in ${Fmt.clock(seconds)}` : ""}</TD>
          {seconds === 0 && <Link title="Resend code" onClick={() => setSeconds(30)} style={{ alignSelf: "flex-start", marginTop: 4 }} />}
        </>
      )}
      {state === "wrong" && (
        <HStack gap={6} style={{ paddingTop: 18 }}>
          <Icon name="warning" size={14} color={C.destructive} />
          <T k="caption" c={C.destructive}>{`That code doesn’t match. ${triesLeft} tries left.`}</T>
        </HStack>
      )}
      {state === "expired" && (
        <>
          <Banner tone="wait" icon="clock" text="That code expired. Get a new one." actionTitle="Resend" style={{ marginTop: 22 }}
            onAction={() => { setState("entering"); setCode(""); setSeconds(30); }} />
          <Button title="Get the code on a call instead" kind="text" fullWidth={false} style={{ marginTop: 20, alignSelf: "flex-start" }} />
        </>
      )}
      <TD k="caption" c={C.muted} style={{ paddingTop: 30 }}>Demo code: 123456</TD>
    </Screen>
  );
}

// MARK: C16 Your name

export function NameScreen() {
  const { store, router } = useApp();
  const [name, setName] = useState(store.customer?.name ?? "");
  return (
    <Screen header={<PlainHeader />}
      footer={<FooterBar showCall={false}><Button title="Continue" enabled={Validators.isValidName(name)} onClick={async () => {
        await store.updateName(name).catch(() => {});
        router.finishLogin();
      }} /></FooterBar>}>
      <TitleBlock top={8} title="What should we call you?" subtitle="Your captain sees your first name only." />
      <TextField label="Your name" value={name} onChange={setName} placeholder="Your name" caps="words" autoFocus />
    </Screen>
  );
}

// MARK: C18 Paying (C18b failed, C18c pending)

export function PayingScreen({ initial = "processing" }: { initial?: PayView }) {
  const { store, router } = useApp();
  const [view, setView] = useState<PayView>(initial);
  const [checking, setChecking] = useState(false);
  const started = useRef(false);

  const run = async () => {
    const outcome = await store.createOrderAndPay().catch(() => "failed" as const);
    if (outcome === "success") router.replace([{ n: "booked" }]);
    else setView(outcome);
  };

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    if (initial === "processing") run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const check = async () => {
    setChecking(true);
    await store.checkPendingPayment().catch(() => {});
    setChecking(false);
    router.replace([{ n: "booked" }]);
  };

  return (
    <Screen scrolls={false} header={view === "processing" ? <div style={{ height: 56 }} /> : <PlainHeader />}>
      {view === "processing" && <FullState icon="clock" title="Confirming payment" message="Don’t close the app. This takes a few seconds." spinning />}
      {view === "failed" && (
        <FullState icon="receipt" tone="error" title="Payment didn’t go through" message="Your bank declined it. No money was taken. Try again or use another method."
          primary="Try again" secondary="Change method"
          onPrimary={() => { store.demo.payment = "success"; setView("processing"); run(); }}
          onSecondary={() => { router.pop(); setTimeout(() => { router.showPaySheet = true; }, 450); }} />
      )}
      {view === "pending" && (
        <FullState icon="clock" tone="wait" title="Waiting for your bank"
          message="We haven’t heard back yet. If money left your account, it will be refunded automatically within 3 days."
          primary={checking ? "Checking…" : "Check again"} secondary="Call support" onPrimary={check} onSecondary={callSupport} />
      )}
    </Screen>
  );
}

// MARK: C19 You're booked

export function BookedScreen() {
  const { store, router } = useApp();
  const o = store.currentOrder;
  const track = () => {
    if (store.customer?.notificationsOn) router.replace([{ n: "live" }]);
    else router.replace([{ n: "notifyAsk" }]);
  };
  return (
    <Screen header={<div style={{ height: 30 }} />}
      footer={<FooterBar showCall={false}><Button title="Go home" onClick={() => { router.tab = 0; router.popToRoot(); }} /></FooterBar>}>
      <VStack align="center" style={{ paddingBottom: 24 }}>
        <div className="wh-scale-in" style={{ paddingBottom: 20 }}><StateCircleOk /></div>
        <TD k="screen">You’re booked</TD>
        {/* The booking details open tracking; there's no separate "Track" button. */}
        <Tap onClick={track} label="Track this booking" style={{ marginTop: 10, display: "flex", alignItems: "center", gap: 6, padding: "8px 14px", borderRadius: 999, background: C.canvas, boxShadow: `inset 0 0 0 1px ${C.border}` }}>
          <T k="body" c={C.heading}>{`${o ? Slot.full(o.slot) : "Today, 8 – 10 AM"} · ${o?.vehicle.plate ?? "TS 09 EA 4521"}`}</T>
          <Icon name="chevron" size={13} color={C.secondary} />
        </Tap>
      </VStack>
      <VStack gap={14} style={{ ...card(18), marginBottom: 18 }}>
        <HStack gap={12}>
          <IconBox icon="whatsapp" size={44} tone="ok" radius={12} />
          <VStack gap={1}>
            <TD k="title">One last thing: your gate pass</TD>
            <TD k="caption">We sent you a WhatsApp message</TD>
          </VStack>
        </HStack>
        <TD k="body">Reply there with your MyGate or society entry pass, so the captain can get in.</TD>
        <Button title="Open WhatsApp" icon="whatsapp" kind="outline" onClick={() => router.push({ n: "whatsApp" })} />
      </VStack>
      <Banner tone="info" icon="search" text="We’re finding a captain now. We’ll notify you when someone accepts." />
    </Screen>
  );
}

const StateCircleOk = () => (
  <span style={{ width: 96, height: 96, borderRadius: 48, background: C.successTint, display: "grid", placeItems: "center" }}>
    <Icon name="check" size={35} color={C.onSuccess} weight={500} />
  </span>
);

// MARK: C19b WhatsApp bot (reference)

export function WhatsAppScreen() {
  const { store, router } = useApp();
  const o = store.currentOrder;
  const bubble = (time: string, body: React.ReactNode) => (
    <VStack gap={4} align="end" style={{ padding: 12, maxWidth: 260, borderRadius: 10, background: "#fff", alignSelf: "flex-start" }}>
      <div style={{ fontSize: 14.5, lineHeight: "20px", color: C.heading, width: "100%" }}>{body}</div>
      <T k="small">{time}</T>
    </VStack>
  );
  return (
    <div className="wh-fill" style={{ background: "#ECE5DD", paddingBottom: "var(--sab)" }}>
      <HStack gap={10} style={{ background: "#fff", padding: "calc(var(--sat) + 6px) 12px 6px" }}>
        <Tap onClick={() => router.pop()} label="Go back" style={{ width: 36, height: 44, display: "grid", placeItems: "center" }}><Icon name="left" size={22} /></Tap>
        <BrandMark size={26} showName={false} />
        <VStack>
          <TD k="title">{Brand.name}</TD>
          <TD k="caption">Business account</TD>
        </VStack>
      </HStack>
      <div className="wh-scroll" style={{ flex: 1 }}>
        <VStack gap={12} style={{ padding: 16 }}>
          {bubble("7:42 AM", <>Booking confirmed<br /><b>{o?.vehicle.plate ?? "TS 09 EA 4521"}</b>{` · ${o ? VT.short(o.vehicle.type) : "Hatchback"}`}<br />{o ? Slot.full(o.slot) : "Today, 8 – 10 AM"}<br />{`${o ? PlaceFmt.title(o.place) : "My Home Avatar, Tower 3"}, ${o ? PlaceFmt.parkingShort(o.place) : "B2 slot 41"}`}<br />{`${Fmt.rupees(o?.price ?? 149)} held safely`}</>)}
          {bubble("7:42 AM", <>Please reply with your <b>society entry pass</b> (MyGate, NoBrokerHood or a photo of the gate pass). The captain needs it to get in.</>)}
          <HStack style={{ justifyContent: "flex-end" }}>
            <div style={{ padding: 4, borderRadius: 12, background: "#DCF8C6" }}>
              <VStack gap={6} align="center" style={{ width: 160, height: 110, justifyContent: "center", borderRadius: 10, background: C.photo }}>
                <Icon name="image" size={22} color={C.secondary} />
                <T k="small">MyGate pass</T>
              </VStack>
            </div>
          </HStack>
          {bubble("7:44 AM", "Got it. Pass saved for this booking. We’ll share it with your captain only.")}
        </VStack>
      </div>
      <TD k="caption" center style={{ padding: 14 }}>Reference only: WhatsApp is outside the app. Message templates for the bot.</TD>
    </div>
  );
}

// MARK: C49 Notifications ask

export function NotifyAskScreen() {
  const { store, router } = useApp();
  return (
    <Screen scrolls={false} header={<PlainHeader />}>
      <FullState icon="bell" title="Know when it’s done" message="We’ll tell you when a captain accepts and when the photos are ready. No spam."
        primary="Turn on notifications" secondary="Not now"
        onPrimary={() => { store.setNotifications(true); router.replace([{ n: "live" }]); }}
        onSecondary={() => router.replace([{ n: "live" }])} />
    </Screen>
  );
}

