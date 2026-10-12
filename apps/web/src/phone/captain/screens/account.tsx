"use client";

import { useEffect, useRef, useState } from "react";
import { C, S, toneBanner, toneBg } from "../../ds/tokens";
import {
  ActionSheet, Alert, AppBar, Banner, Button, Chip, Divider, FullState, HStack, IconBox, Link, OtpField, PhoneField, Plate, Screen, StateCircle,
  Tap, T, TD, TextField, ToggleRow, VStack, card,
} from "../../ds/components";
import { Icon } from "../../ds/icons";
import { Fmt, isToday, isYesterday, Validators } from "../../lib/fmt";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import { openWNotif, WKind, WNotifCategories, wIsMuted, type WNotif, type WNotifCategory } from "../store";

// MARK: Notification list

export function WNotificationsScreen() {
  const { store, router } = useCaptain();
  const [filter, setFilter] = useState<WNotifCategory | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);
  const [menu, setMenu] = useState<WNotif | null>(null);
  const items = store.notifications.filter((n) => filter == null || WKind.category(n.kind) === filter);
  const relative = (d: Date) => {
    const s = (Date.now() - d.getTime()) / 1000;
    if (s < 60) return store.t("Now", "अभी", "ఇప్పుడు");
    if (s < 3600) return `${Math.floor(s / 60)} min`;
    if (isToday(d)) return `${Math.floor(s / 3600)} h`;
    if (isYesterday(d)) return Fmt.time(d);
    return Fmt.date(d);
  };
  const sections = ([[store.t("Today", "आज", "ఈరోజు"), items.filter((n) => isToday(n.date))], [store.t("Yesterday", "कल", "నిన్న"), items.filter((n) => isYesterday(n.date))],
    [store.t("Earlier", "पहले", "ఇంతకు ముందు"), items.filter((n) => !isToday(n.date) && !isYesterday(n.date))]] as [string, WNotif[]][]).filter(([, l]) => l.length);
  const prefs = store.notifPrefs;
  return (
    <Screen canvas gutter={S.gutterCaptain}
      header={<AppBar title={store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు")} trailing="gear" onLeading={() => router.pop()} onTrailing={() => router.push({ n: "notificationSettings" })} style={{ padding: "4px 4px 0" }} />}>
      {!store.notificationsOn ? (
        <Banner tone="wait" icon="bellSlash" title={store.t("Alerts are off.", "अलर्ट बंद हैं।", "అలర్ట్‌లు ఆఫ్‌లో ఉన్నాయి.")} style={{ marginTop: 10 }}
          text={store.online ? store.t("New jobs still ring while you’re Online.", "ऑनलाइन रहते नए काम फिर भी बजेंगे।", "ఆన్‌లైన్‌లో ఉన్నప్పుడు కొత్త పనులు మోగుతాయి.") : store.t("Messages still come here.", "संदेश फिर भी यहाँ आएंगे।", "సందేశాలు ఇక్కడికి వస్తాయి.")}
          actionTitle={store.t("Turn on", "चालू करें", "ఆన్ చేయండి")} onAction={() => store.setNotifications(true)} />
      ) : store.systemPermission === "denied" ? (
        <Banner tone="error" icon="bellSlash" title={store.t("Blocked in browser settings.", "ब्राउज़र सेटिंग में बंद है।", "బ్రౌజర్ సెట్టింగ్స్‌లో బ్లాక్ అయింది.")} style={{ marginTop: 10 }}
          text={store.t("You may miss new jobs. Allow notifications.", "नए काम छूट सकते हैं। सूचनाएं चालू करें।", "కొత్త పనులు మిస్ కావచ్చు. నోటిఫికేషన్లు అనుమతించండి.")} />
      ) : wIsMuted(prefs) && prefs.mutedUntil ? (
        <Banner tone="info" icon="speakerOff" title={`${store.t("Muted till", "बंद है", "మ్యూట్")} ${Fmt.time(prefs.mutedUntil)}`} style={{ marginTop: 10 }}
          text={store.t("New jobs still ring while Online.", "ऑनलाइन रहते नए काम फिर भी बजेंगे।", "ఆన్‌లైన్‌లో కొత్త పనులు మోగుతాయి.")} actionTitle={store.t("Unmute", "चालू करें", "అన్‌మ్యూట్")} onAction={() => store.mute(null)} />
      ) : null}
      <div className="wh-scroll" style={{ overflowX: "auto", overflowY: "hidden", margin: "10px -16px 0", padding: "2px 16px" }}>
        <HStack gap={8}>
          <Chip title={store.t("All", "सभी", "అన్నీ")} selected={filter == null} height={40} onClick={() => setFilter(null)} />
          {WNotifCategories.map((c) => <Chip key={c} title={store.categoryTitle(c)} selected={filter === c} height={40} onClick={() => setFilter(c)} />)}
        </HStack>
      </div>
      {items.length === 0 ? (
        <VStack gap={12} align="center" style={{ paddingTop: 50 }}>
          <StateCircle icon="bell" size={80} />
          <TD k="section" w={600}>{store.t("Nothing here yet", "अभी कुछ नहीं", "ఇంకా ఏమీ లేదు")}</TD>
          <WBody center>{store.t("New jobs, money and level updates show up here.", "नए काम, पैसे और लेवल की खबरें यहाँ दिखेंगी।", "కొత్త పనులు, డబ్బు, స్థాయి వివరాలు ఇక్కడ కనిపిస్తాయి.")}</WBody>
        </VStack>
      ) : (
        <>
          <HStack style={{ paddingTop: 12 }}>
            <T k="label" style={{ flex: 1 }}>{store.unreadCount === 0 ? store.t("All read", "सब पढ़ लिया", "అన్నీ చదివారు") : store.t(`${store.unreadCount} new`, `${store.unreadCount} नई`, `${store.unreadCount} కొత్తవి`)}</T>
            {store.unreadCount > 0 && <Link title={store.t("Mark all read", "सब पढ़ा हुआ करें", "అన్నీ చదివినట్లు")} k="caption" onClick={() => store.markAllRead()} />}
          </HStack>
          {sections.map(([title, list]) => (
            <div key={title}>
              <TD k="label" c={C.muted} style={{ paddingTop: 16, paddingBottom: 8 }}>{title}</TD>
              <div style={{ ...card(0, 16), overflow: "hidden" }}>
                {list.map((n, i) => (
                  <div key={n.id}>
                    <Tap className="wh-nopress wh-row" onClick={() => { const m = openWNotif(n, store, router); if (m) setInfo(m); }} onContext={() => setMenu(n)}
                      style={{ display: "flex", alignItems: "flex-start", gap: 14, padding: 14, width: "100%", textAlign: "left", background: n.read ? "transparent" : "rgba(234,240,255,.35)" }}>
                      <IconBox icon={WKind.icon(n.kind)} size={44} tone={WKind.tone(n.kind)} radius={12} />
                      <VStack gap={4} style={{ flex: 1, minWidth: 0 }}>
                        <HStack align="baseline" gap={6}>
                          <TD k="title" w={n.read ? 400 : 600} s={16.5} style={{ flex: 1 }}>{store.title(n)}</TD>
                          <T k="small" c={C.muted}>{relative(n.date)}</T>
                        </HStack>
                        <TD k="caption" s={14.5} lines={3}>{store.body(n)}</TD>
                      </VStack>
                      <span style={{ width: 9, height: 9, borderRadius: 5, marginTop: 7, background: n.read ? "transparent" : C.primary, flexShrink: 0 }} />
                    </Tap>
                    {i < list.length - 1 && <Divider inset={70} />}
                  </div>
                ))}
              </div>
            </div>
          ))}
          <Button title={store.t("Clear all", "सब हटाएं", "అన్నీ తొలగించండి")} kind="text" onClick={() => setConfirmClear(true)} style={{ marginTop: 16 }} />
          <TD k="small" c={C.muted} center style={{ paddingBottom: 20 }}>{store.t("Press and hold a message to delete it or mark it unread.", "किसी संदेश को दबाकर रखें: हटाएं या ‘नहीं पढ़ा’ करें।", "సందేశాన్ని నొక్కి పట్టుకోండి: తొలగించండి లేదా చదవనిదిగా మార్చండి.")}</TD>
        </>
      )}
      <Alert open={info != null} title={info ?? ""} onClose={() => setInfo(null)} />
      <ActionSheet open={confirmClear} onClose={() => setConfirmClear(false)} title={store.t("Clear all messages?", "सब संदेश हटाएं?", "అన్ని సందేశాలు తొలగించాలా?")}
        message={store.t("Your jobs and money are not affected.", "आपके काम और पैसे पर असर नहीं होगा।", "మీ పనులు, డబ్బుపై ప్రభావం ఉండదు.")}
        actions={[{ title: store.t("Clear all", "सब हटाएं", "అన్నీ తొలగించండి"), role: "destructive", action: () => store.clearNotifications() }]} />
      <ActionSheet open={menu != null} onClose={() => setMenu(null)} title={menu ? store.title(menu) : undefined} actions={menu ? [
        menu.read ? { title: store.t("Mark unread", "‘नहीं पढ़ा’ करें", "చదవనిదిగా"), action: () => store.markUnread(menu.id) } : { title: store.t("Mark read", "पढ़ा हुआ करें", "చదివినట్లు"), action: () => store.markRead(menu.id) },
        { title: store.t("Delete", "हटाएं", "తొలగించండి"), role: "destructive", action: () => store.deleteNotification(menu.id) },
      ] : []} />
    </Screen>
  );
}

// MARK: Notification settings

export function WNotificationSettingsScreen() {
  const { store } = useCaptain();
  useEffect(() => { store.refreshSystemPermission(); }, [store]);
  const on = store.notificationsOn;
  const prefs = store.notifPrefs;
  return (
    <Screen canvas gutter={S.gutterCaptain} header={<WHeader title={store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు")} help={false} />}>
      <div style={{ ...card(16, 16), marginTop: 10 }}>
        <ToggleRow on={on} onChange={(v) => store.setNotifications(v)}>
          <TD k="title" s={18}>{store.t("Alerts", "अलर्ट", "అలర్ట్‌లు")}</TD>
          <TD k="caption">{on ? store.t("Banner and sound for updates.", "खबरों पर बैनर और आवाज़।", "అప్‌డేట్‌లకు బ్యానర్, శబ్దం.") : store.t("Off. Messages still come to the list.", "बंद। संदेश लिस्ट में आएंगे।", "ఆఫ్. సందేశాలు లిస్ట్‌లో వస్తాయి.")}</TD>
        </ToggleRow>
      </div>
      <HStack align="start" gap={12} style={{ padding: 16, borderRadius: 14, background: C.primaryTint, marginTop: 12 }}>
        <Icon name="bell" size={18} />
        <TD k="caption" c={C.inverse} s={14.5}>{store.t("New jobs always ring while you’re Online. To stop them, go Offline.", "ऑनलाइन रहते नए काम हमेशा बजेंगे। रोकने के लिए ऑफ़लाइन जाएं।", "ఆన్‌లైన్‌లో ఉన్నప్పుడు కొత్త పనులు ఎప్పుడూ మోగుతాయి. ఆపడానికి ఆఫ్‌లైన్‌కి వెళ్ళండి.")}</TD>
      </HStack>
      {store.systemPermission === "denied" && on && (
        <Banner tone="error" icon="bellSlash" style={{ marginTop: 12 }} title={store.t("Blocked in browser settings.", "ब्राउज़र सेटिंग में बंद है।", "బ్రౌజర్ సెట్టింగ్స్‌లో బ్లాక్.")}
          text={store.t("Allow notifications so the phone rings for jobs.", "सूचनाएं चालू करें ताकि काम पर फ़ोन बजे।", "పనులకు ఫోన్ మోగాలంటే నోటిఫికేషన్లు అనుమతించండి.")} />
      )}
      <div style={{ opacity: on ? 1 : 0.45, pointerEvents: on ? "auto" : "none", display: "flex", flexDirection: "column", paddingBottom: 24 }}>
        <div style={{ ...card(16, 16), marginTop: 20 }}>
          <ToggleRow on={prefs.soundOn} onChange={(v) => { store.notifPrefs.soundOn = v; }}>
            <TD k="title" s={18}>{store.t("Sound", "आवाज़", "శబ్దం")}</TD>
            <TD k="caption">{store.t("Off: banner only, no sound.", "बंद: सिर्फ़ बैनर, आवाज़ नहीं।", "ఆఫ్: బ్యానర్ మాత్రమే, శబ్దం లేదు.")}</TD>
          </ToggleRow>
        </div>
        <TD k="label" style={{ paddingTop: 22, paddingBottom: 8 }}>{store.t("Mute for a while", "कुछ देर बंद करें", "కాసేపు మ్యూట్")}</TD>
        <VStack gap={12} style={card(16, 16)}>
          {wIsMuted(prefs) && prefs.mutedUntil && (
            <HStack gap={8}>
              <Icon name="speakerOff" size={17} color={C.primaryStrong} />
              <T k="bodyStrong" style={{ flex: 1 }}>{`${store.t("Muted till", "बंद है", "మ్యూట్")} ${Fmt.day(prefs.mutedUntil)}, ${Fmt.time(prefs.mutedUntil)}`}</T>
              <Link title={store.t("Unmute", "चालू करें", "అన్‌మ్యూట్")} k="caption" onClick={() => store.mute(null)} />
            </HStack>
          )}
          <HStack gap={8}>
            <Chip title={store.t("1 hour", "1 घंटा", "1 గంట")} height={44} onClick={() => store.mute(3600)} />
            <Chip title={store.t("8 hours", "8 घंटे", "8 గంటలు")} height={44} onClick={() => store.mute(8 * 3600)} />
            <Chip title={store.t("Till morning", "सुबह तक", "ఉదయం వరకు")} height={44} onClick={() => store.muteUntilMorning()} />
          </HStack>
        </VStack>
        <div style={{ ...card(16, 16), marginTop: 12 }}>
          <ToggleRow on={prefs.quietHours} onChange={(v) => { store.notifPrefs.quietHours = v; }}>
            <TD k="title" s={18}>{store.t("Quiet at night", "रात में शांत", "రాత్రి నిశ్శబ్దం")}</TD>
            <TD k="caption">{store.t("10 PM – 7 AM: no sound.", "रात 10 – सुबह 7: आवाज़ नहीं।", "రాత్రి 10 – ఉదయం 7: శబ్దం లేదు.")}</TD>
          </ToggleRow>
        </div>
        <TD k="label" style={{ paddingTop: 22, paddingBottom: 8 }}>{store.t("What you hear about", "किस बारे में", "వేటి గురించి")}</TD>
        <div style={card(16, 16)}>
          {WNotifCategories.map((c, i) => (
            <div key={c}>
              <ToggleRow on={c === "account" || !prefs.off.includes(c)} disabled={c === "account"} style={{ padding: "10px 0" }}
                onChange={(v) => { store.notifPrefs.off = v ? prefs.off.filter((x) => x !== c) : [...prefs.off, c]; }}>
                <TD k="rowTitle" s={17}>{store.categoryTitle(c)}</TD>
                <TD k="caption">{store.categoryDetail(c)}</TD>
              </ToggleRow>
              {i < WNotifCategories.length - 1 && <Divider />}
            </div>
          ))}
        </div>
      </div>
    </Screen>
  );
}

// MARK: Banner + toast over every screen

export function WLiveBanner() {
  const { store, router } = useCaptain();
  const [info, setInfo] = useState<string | null>(null);
  const n = store.liveBanner;
  const t = store.toast;
  const start = useRef<number | null>(null);
  useEffect(() => {
    if (!n) return;
    const id = n.id;
    const h = setTimeout(() => { if (store.liveBanner?.id === id) store.liveBanner = null; }, 5000);
    return () => clearTimeout(h);
  }, [n, store]);
  useEffect(() => {
    if (!t) return;
    const h = setTimeout(() => { if (store.toast === t) store.toast = null; }, 3000);
    return () => clearTimeout(h);
  }, [t, store]);
  return (
    <>
      {n && (
        <div key={n.id} className="wh-banner-in" style={{ position: "absolute", top: "calc(var(--sat) + 4px)", left: 12, right: 12, zIndex: 60 }}
          onPointerDown={(e) => { start.current = e.clientY; }}
          onPointerUp={(e) => { if (start.current != null && e.clientY - start.current < -10) store.liveBanner = null; start.current = null; }}>
          <Tap onClick={() => { const m = openWNotif(n, store, router); if (m) setInfo(m); }}
            style={{ display: "flex", alignItems: "flex-start", gap: 12, padding: 14, width: "100%", textAlign: "left", background: "#fff", borderRadius: 18, boxShadow: `0 6px 16px ${C.shadow}` }}>
            <IconBox icon={WKind.icon(n.kind)} size={40} tone={WKind.tone(n.kind)} radius={10} />
            <VStack gap={2} style={{ flex: 1, minWidth: 0 }}>
              <TD k="title" s={16}>{store.title(n)}</TD>
              <TD k="caption" lines={2}>{store.body(n)}</TD>
            </VStack>
          </Tap>
        </div>
      )}
      {t && (
        <div key={t} className="wh-slide-up" style={{ position: "absolute", left: 0, right: 0, bottom: "calc(110px + var(--sab))", display: "flex", justifyContent: "center", zIndex: 60, pointerEvents: "none" }}>
          <span style={{ padding: "12px 16px", borderRadius: 999, background: C.inverse, maxWidth: "86%" }}><T k="caption" c="#fff" w={500}>{t}</T></span>
        </div>
      )}
      <Alert open={info != null} title={info ?? ""} onClose={() => setInfo(null)} />
    </>
  );
}

// MARK: Change phone (code to the new number)

export function WChangePhoneScreen() {
  const { store, router } = useCaptain();
  const [stage, setStage] = useState<"number" | "code" | "done">("number");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [wrong, setWrong] = useState(false);
  const [loading, setLoading] = useState(false);
  const digits = Validators.digitsOnly(phone).slice(0, 10);
  const canSend = Validators.isValidMobile(phone) && digits !== store.phone;
  const send = async () => { if (!canSend) return; setLoading(true); await store.requestPhoneChange(digits); setLoading(false); setCode(""); setWrong(false); setStage("code"); };
  const verify = async (c = code) => { if (loading || c.length !== 6) return; setLoading(true); const ok = await store.confirmPhoneChange(c); setLoading(false); if (ok) setStage("done"); else setWrong(true); };
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Phone number", "फ़ोन नंबर", "ఫోన్ నంబర్")} />}
      footer={stage !== "done" ? <WFooter>{stage === "number"
        ? <Button title={store.t("Send code", "कोड भेजें", "కోడ్ పంపండి")} size="captain" enabled={canSend} loading={loading} onClick={send} />
        : <Button title={store.t("Verify", "जाँचें", "ధృవీకరించండి")} size="captain" enabled={code.length === 6} loading={loading} onClick={() => verify()} />}</WFooter> : undefined}>
      {stage === "number" && (
        <>
          <WTitle style={{ paddingTop: 10 }}>{store.t("New number", "नया नंबर", "కొత్త నంబర్")}</WTitle>
          <WBody style={{ paddingTop: 6, paddingBottom: 18 }}>{store.t(`Now: ${Fmt.phone(store.phone)}. We send a code to the new number.`, `अभी: ${Fmt.phone(store.phone)}। नए नंबर पर कोड भेजेंगे।`, `ఇప్పుడు: ${Fmt.phone(store.phone)}. కొత్త నంబర్‌కి కోడ్ పంపుతాము.`)}</WBody>
          <PhoneField number={phone} onChange={setPhone} large />
          {digits === store.phone && <TD k="caption" style={{ paddingTop: 8 }}>{store.t("That’s your current number.", "यह आपका अभी का नंबर है।", "ఇది మీ ప్రస్తుత నంబర్.")}</TD>}
        </>
      )}
      {stage === "code" && (
        <>
          <WTitle style={{ paddingTop: 10 }}>{store.t("Enter the code", "कोड डालें", "కోడ్ ఎంటర్ చేయండి")}</WTitle>
          <WBody style={{ paddingTop: 6, paddingBottom: 22 }}>{store.t(`Sent to ${Fmt.phone(digits)}.`, `${Fmt.phone(digits)} पर भेजा।`, `${Fmt.phone(digits)} కి పంపాము.`)}</WBody>
          <OtpField code={code} error={wrong} boxSize={48} onChange={(v) => { setCode(v); if (wrong && v.length < 6) setWrong(false); if (v.length === 6) verify(v); }} />
          {wrong && <TD k="caption" c={C.destructive} style={{ paddingTop: 14 }}>{store.t("Wrong code. Try again.", "गलत कोड। फिर कोशिश करें।", "తప్పు కోడ్. మళ్ళీ ప్రయత్నించండి.")}</TD>}
          <TD k="caption" c={C.muted} style={{ paddingTop: 30 }}>Demo code: 123456</TD>
        </>
      )}
      {stage === "done" && (
        <div style={{ paddingTop: 40 }}>
          <FullState icon="check" tone="ok" captain title={store.t("Number changed", "नंबर बदल गया", "నంబర్ మారింది")}
            message={store.t(`Log in with ${Fmt.phone(store.phone)} from now.`, `अब ${Fmt.phone(store.phone)} से लॉग इन करें।`, `ఇకపై ${Fmt.phone(store.phone)} తో లాగిన్ అవ్వండి.`)}
            primary={store.t("Done", "ठीक है", "సరే")} onPrimary={() => router.pop()} />
        </div>
      )}
    </Screen>
  );
}

// MARK: Change payout UPI (code to the registered phone)

export function WEditUPIScreen() {
  const { store, router } = useCaptain();
  const [stage, setStage] = useState<"upi" | "code">("upi");
  const [upi, setUpi] = useState(store.upi);
  const [code, setCode] = useState("");
  const [showError, setShowError] = useState(false);
  const [wrong, setWrong] = useState(false);
  const [loading, setLoading] = useState(false);
  const valid = Validators.isValidUPI(upi);
  const same = upi.toLowerCase() === store.upi.toLowerCase();
  const send = async () => { if (!valid) { setShowError(true); return; } if (same) return; setLoading(true); await store.requestUPIChange(upi); setLoading(false); setCode(""); setWrong(false); setStage("code"); };
  const verify = async (c = code) => {
    if (loading || c.length !== 6) return;
    setLoading(true);
    const ok = await store.confirmUPIChange(c);
    setLoading(false);
    if (ok) { store.toast = store.t("UPI saved", "UPI सेव हो गया", "UPI సేవ్ అయింది"); router.pop(); } else setWrong(true);
  };
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Payout UPI", "पेमेंट UPI", "చెల్లింపు UPI")} />}
      footer={<WFooter>{stage === "upi"
        ? <Button title={store.t("Send code", "कोड भेजें", "కోడ్ పంపండి")} size="captain" enabled={!!upi && !same} loading={loading} onClick={send} />
        : <Button title={store.t("Verify and save", "जाँचें और सेव करें", "ధృవీకరించి సేవ్ చేయండి")} size="captain" enabled={code.length === 6} loading={loading} onClick={() => verify()} />}</WFooter>}>
      {stage === "upi" ? (
        <>
          <WTitle style={{ paddingTop: 10 }}>{store.t("Where should money go?", "पैसे कहाँ भेजें?", "డబ్బు ఎక్కడికి పంపాలి?")}</WTitle>
          <WBody style={{ paddingTop: 6, paddingBottom: 18 }}>{store.t(`Now: ${store.upi}`, `अभी: ${store.upi}`, `ఇప్పుడు: ${store.upi}`)}</WBody>
          <TextField label="UPI ID" value={upi} onChange={(v) => { setUpi(v); setShowError(false); }} placeholder="name@ybl" inputMode="email" large autoFocus onSubmit={send}
            helper={store.t("Like name@ybl or 9876543210@paytm", "जैसे name@ybl या 9876543210@paytm", "ఉదా: name@ybl లేదా 9876543210@paytm")}
            error={showError && !valid ? store.t("Check the UPI ID. It needs an @.", "UPI ID जाँचें। इसमें @ होना चाहिए।", "UPI ID చూడండి. అందులో @ ఉండాలి.") : null} />
          {same && upi && <TD k="caption" style={{ paddingTop: 8 }}>{store.t("That’s your current UPI.", "यह आपका अभी का UPI है।", "ఇది మీ ప్రస్తుత UPI.")}</TD>}
          <HStack align="start" gap={10} style={{ paddingTop: 18 }}>
            <Icon name="shield" size={16} color={C.secondary} />
            <T k="caption">{store.t(`For safety we send a code to ${Fmt.phone(store.phone)} first.`, `सुरक्षा के लिए पहले ${Fmt.phone(store.phone)} पर कोड भेजेंगे।`, `భద్రత కోసం ముందుగా ${Fmt.phone(store.phone)} కి కోడ్ పంపుతాము.`)}</T>
          </HStack>
        </>
      ) : (
        <>
          <WTitle style={{ paddingTop: 10 }}>{store.t("Enter the code", "कोड डालें", "కోడ్ ఎంటర్ చేయండి")}</WTitle>
          <WBody style={{ paddingTop: 6, paddingBottom: 22 }}>{store.t(`Sent to ${Fmt.phone(store.phone)}. UPI changes to ${store.pendingUPI} after this.`, `${Fmt.phone(store.phone)} पर भेजा। इसके बाद UPI ${store.pendingUPI} होगा।`, `${Fmt.phone(store.phone)} కి పంపాము. తర్వాత UPI ${store.pendingUPI} అవుతుంది.`)}</WBody>
          <OtpField code={code} error={wrong} boxSize={48} onChange={(v) => { setCode(v); if (wrong && v.length < 6) setWrong(false); if (v.length === 6) verify(v); }} />
          {wrong && <TD k="caption" c={C.destructive} style={{ paddingTop: 14 }}>{store.t("Wrong code. Try again.", "गलत कोड। फिर कोशिश करें।", "తప్పు కోడ్. మళ్ళీ ప్రయత్నించండి.")}</TD>}
          <TD k="caption" c={C.muted} style={{ paddingTop: 30 }}>Demo code: 123456</TD>
        </>
      )}
    </Screen>
  );
}

// MARK: Job cancelled: didn't reach in time

export function WNoShowCancelledScreen() {
  const { store, router } = useCaptain();
  const plate = store.noShowPlate || store.current.plate;
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}
      footer={<WFooter><Button title={store.t("Back to jobs", "कामों पर वापस", "పనులకు తిరిగి")} size="captain" onClick={() => { router.home(); router.tab = 1; }} /></WFooter>}>
      <VStack gap={14} align="center" style={{ flex: 1, justifyContent: "center" }}>
        <StateCircle icon="ban" tone="error" size={112} />
        <TD k="section" w={600} s={23}>{store.t("Job cancelled", "काम रद्द हुआ", "పని రద్దయింది")}</TD>
        <Plate text={plate} />
        <WBody center>{store.t("You didn’t reach or update the job in the time slot. The owner got a full refund.", "आप समय पर नहीं पहुँचे और काम अपडेट नहीं किया। मालिक को पूरे पैसे वापस मिले।", "మీరు సమయానికి చేరుకోలేదు, పని అప్‌డేట్ చేయలేదు. యజమానికి పూర్తి డబ్బు తిరిగి వచ్చింది.")}</WBody>
        <HStack align="start" gap={12} style={{ width: "100%", padding: 16, borderRadius: 14, background: toneBg.error }}>
          <Icon name="rupee" size={18} color={C.destructive} />
          <TD k="caption" c={toneBanner.error} s={14.5}>{store.t("Penalty ₹[NO-SHOW PENALTY] is cut from your next payout.", "जुर्माना ₹[NO-SHOW PENALTY] अगले पेमेंट से कटेगा।", "జరిమానా ₹[NO-SHOW PENALTY] తదుపరి చెల్లింపు నుండి తగ్గుతుంది.")}</TD>
        </HStack>
        <TD k="caption" center>{store.t("If you can’t reach a job, tell us in Help before the slot ends.", "अगर काम पर नहीं पहुँच सकते, तो समय खत्म होने से पहले मदद में बताएं।", "పనికి చేరుకోలేకపోతే, సమయం ముగియక ముందే సహాయంలో చెప్పండి.")}</TD>
      </VStack>
    </Screen>
  );
}
