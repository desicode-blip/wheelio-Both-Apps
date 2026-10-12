"use client";

import { useState } from "react";
import { Brand, C, S, toneBg, toneFg, type Tone } from "../../ds/tokens";
import {
  Banner, Button, Divider, HStack, IconBox, KeyValueCard, Link, ListRow, PhotoPlaceholder, Screen, Segmented, Sheet, StateCircle, Tap, T, TD, VStack, card,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt, Support } from "../../lib/fmt";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import { HelpTopics, wIsMuted, type HelpTopic } from "../store";
import { HelpLadder, WProfilePhoto } from "./parts";
import { GuestNotice, LangTile } from "./welcome";

const TabScroll = ({ children }: { children: React.ReactNode }) => (
  <div className="wh-scroll" style={{ position: "absolute", inset: 0, background: C.canvas, paddingTop: "var(--sat)" }}>
    <VStack gap={14} style={{ padding: `0 ${S.gutterCaptain}px 20px` }}>{children}</VStack>
  </div>
);

// MARK: W40 Money

export function MoneyTab() {
  const { store, router } = useCaptain();
  const [range, setRange] = useState(0);
  const tile = (icon: IconName, tone: Tone, big: string, small: string) => (
    <VStack gap={6} style={{ flex: 1, padding: 14, borderRadius: 14, background: toneBg[tone] }}>
      <Icon name={icon} size={22} color={tone === "ok" ? C.heading : toneFg[tone]} />
      <T k="section" w={600} mono>{big}</T>
      <T k="caption" c={C.heading}>{small}</T>
    </VStack>
  );
  return (
    <TabScroll>
      <WTitle style={{ paddingTop: 22 }}>{store.t("Money", "पैसे", "డబ్బు")}</WTitle>
      {!store.signedUp && <GuestNotice text={store.t("Example earnings. Your money shows here after your first job, and comes to your UPI every night.", "उदाहरण कमाई। पहले काम के बाद आपके पैसे यहाँ दिखेंगे और हर रात UPI पर आएंगे।", "ఉదాహరణ సంపాదన. మొదటి పని తర్వాత మీ డబ్బు ఇక్కడ కనిపిస్తుంది, ప్రతి రాత్రి UPI కి వస్తుంది.")} />}
      <Segmented options={[store.t("Today", "आज", "ఈరోజు"), store.t("This week", "इस हफ़्ते", "ఈ వారం")]} selection={range} onChange={setRange} height={50} />
      <VStack gap={10} style={card(18)}>
        <TD k="caption">{range === 0 ? store.t("Comes to UPI tonight before 12", "आज रात 12 से पहले UPI में आएगा", "ఈ రాత్రి 12 లోపు UPI కి వస్తుంది") : store.t("This week so far", "इस हफ़्ते अब तक", "ఈ వారం ఇప్పటి వరకు")}</TD>
        <T k="bigMoney" mono>{Fmt.rupees(range === 0 ? store.earnedToday : 4562)}</T>
        <HStack gap={10}>
          {tile("check", "ok", Fmt.rupees(range === 0 ? store.approvedToday : 4342), store.t("Approved", "मंज़ूर", "ఆమోదించబడింది"))}
          {tile("clock", "wait", Fmt.rupees(range === 0 ? store.waitingToday : 220), store.t("Waiting", "इंतज़ार में", "వేచి ఉంది"))}
        </HStack>
      </VStack>
      <VStack style={card(14)}>
        <ListRow icon="receipt" title={`${store.t("Yesterday", "कल", "నిన్న")} · ₹1,262`} subtitle={`${store.t("Paid", "भेजा", "చెల్లించారు")} 11:48 PM · ${store.upi}`} onClick={() => router.push({ n: "payoutDetail" })} />
        <Divider inset={54} />
        <ListRow icon="receipt" title={`${store.t("Thu", "गुरु", "గురు")} · ₹980`} subtitle={`${store.t("Paid", "भेजा", "చెల్లించారు")} 11:52 PM`} onClick={() => router.push({ n: "payoutDetail" })} />
        <Divider inset={54} />
        {store.noShowCancelled && (
          <>
            <ListRow icon="ban" tone="error" title={`${store.t("Penalty", "जुर्माना", "జరిమానా")} · −₹[NO-SHOW PENALTY]`}
              subtitle={`${store.t("Didn’t reach", "नहीं पहुँचे", "చేరుకోలేదు")} ${store.noShowPlate} · ${store.t("cut from next payout", "अगले पेमेंट से कटेगा", "తదుపరి చెల్లింపు నుండి")}`}
              onClick={() => router.push({ n: "noShowCancelled" })} />
            <Divider inset={54} />
          </>
        )}
        <ListRow icon="lock" tone="wait" title={`${store.t("On hold", "रोका गया", "నిలిపివేయబడింది")} · ₹116`} subtitle={store.t("Owner reported a problem", "मालिक ने शिकायत की", "యజమాని సమస్య చెప్పారు")} onClick={() => router.push({ n: "payoutHeld" })} />
      </VStack>
    </TabScroll>
  );
}

// MARK: W41 Payout detail

export function PayoutDetailScreen() {
  const { store } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Fri, 9 Oct", "शुक्र, 9 अक्टू", "శుక్ర, 9 అక్టో")} subtitle={store.t("Paid 11:48 PM", "11:48 PM पर भेजा", "11:48 PM కి చెల్లించారు")} />}>
      <TD k="caption" style={{ paddingTop: 14 }}>{`${store.t("Sent to", "भेजा गया", "పంపబడింది")} ${store.upi}`}</TD>
      <T k="bigMoney" mono style={{ paddingTop: 4 }}>₹1,262</T>
      <HStack gap={8} style={{ padding: "0 12px", height: 32, borderRadius: 999, background: C.successTint, marginTop: 10, marginBottom: 18 }}>
        <Icon name="check" size={13} color={C.onSuccess} />
        <T k="label" c={C.onSuccess}>{store.t("Paid", "भेज दिया", "చెల్లించారు")}</T>
      </HStack>
      <KeyValueCard boldLast rows={[
        [store.t("9 jobs", "9 काम", "9 పనులు"), "₹1,290"],
        [store.t("Late (2 jobs)", "देरी (2 काम)", "ఆలస్యం (2 పనులు)"), "−₹28"],
        [store.t("Total", "कुल", "మొత్తం"), "₹1,262"],
      ]} />
      <TD k="caption" style={{ paddingTop: 18 }}>UPI ref 4410 2219 8830</TD>
    </Screen>
  );
}

// MARK: W42 Money held

export function PayoutHeldScreen() {
  const { store } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Money held", "पैसे रोके गए", "డబ్బు నిలిపివేయబడింది")} />}
      footer={<WFooter><Button title={store.t("Explain by voice", "आवाज़ में बताएं", "వాయిస్‌తో వివరించండి")} icon="mic" kind="outline" size="captain" /></WFooter>}>
      <WTitle style={{ paddingTop: 10 }}>{store.t("₹116 is on hold", "₹116 रोके गए हैं", "₹116 నిలిపివేయబడింది")}</WTitle>
      <WBody style={{ paddingTop: 6, paddingBottom: 18 }}>{store.t("Owner said the bonnet had water streaks.", "मालिक ने कहा बोनट पर पानी के निशान थे।", "బానెట్‌పై నీటి గీతలు ఉన్నాయని యజమాని చెప్పారు.")}</WBody>
      <HStack gap={8}>
        <PhotoPlaceholder height={96} icon="car" tag={store.t("Before", "पहले", "ముందు")} />
        <PhotoPlaceholder height={96} icon="sparkle" tag={store.t("After", "बाद", "తర్వాత")} tagTone="ok" />
        <PhotoPlaceholder height={96} icon="image"><T k="small" style={{ position: "absolute", bottom: 14 }}>{store.t("Owner", "मालिक", "యజమాని")}</T></PhotoPlaceholder>
      </HStack>
      <Banner tone="info" icon="clock" style={{ marginTop: 16 }} text={store.t("We decide within 24 hours. Your other jobs are paid as normal.", "हम 24 घंटे में फ़ैसला करेंगे। बाकी कामों के पैसे सामान्य रूप से मिलेंगे।", "24 గంటల్లో నిర్ణయిస్తాము. మీ ఇతర పనుల డబ్బు మామూలుగానే వస్తుంది.")} />
    </Screen>
  );
}

// MARK: W43 My level

export function LevelScreen() {
  const { store } = useCaptain();
  const day = (d: number, sub: string) => {
    const state = d < store.levelDay ? 0 : d === store.levelDay ? 1 : 2;
    return (
      <VStack gap={6} align="center" style={{ flex: 1 }}>
        <span style={{ width: 58, height: 58, borderRadius: 29, background: state === 0 ? C.success : state === 1 ? C.primary : C.primaryTint, display: "grid", placeItems: "center" }}>
          <Icon name={state === 0 ? "check" : "calendar"} size={23} color={state === 0 ? C.onSuccess : state === 1 ? "#fff" : C.heading} />
        </span>
        <T k="title">{store.t(`Day ${d}`, `दिन ${d}`, `రోజు ${d}`)}</T>
        <T k="caption">{sub}</T>
      </VStack>
    );
  };
  return (
    <Screen canvas gutter={S.gutterCaptain} header={<WHeader title={store.t("My level", "मेरा लेवल", "నా స్థాయి")} />}>
      <VStack gap={16} style={{ ...card(18), marginTop: 10 }}>
        <TD k="section" w={600}>{store.t(`New captain: day ${store.levelDay} of 3`, `नए कैप्टन: दिन ${store.levelDay} / 3`, `కొత్త కెప్టెన్: రోజు ${store.levelDay} / 3`)}</TD>
        <HStack>
          {day(1, `2 ${store.t("jobs", "काम", "పనులు")}`)}
          {day(2, `4 ${store.t("jobs", "काम", "పనులు")}`)}
          {day(3, "6–8")}
        </HStack>
      </VStack>
      <VStack gap={8} style={{ ...card(18), marginTop: 14 }}>
        <TD k="caption">{store.t("Your rating", "आपकी रेटिंग", "మీ రేటింగ్")}</TD>
        <HStack gap={10}>
          <T k="bigMoney">{store.rating.toFixed(1)}</T>
          {[0, 1, 2, 3, 4].map((i) => <Icon key={i} name="starFill" size={18} color={C.star} />)}
        </HStack>
        <TD k="caption">{store.t("From 6 washes · keep every wash at 4★ or more", "6 धुलाई से · हर धुलाई 4★ या ज़्यादा रखें", "6 వాష్‌ల నుండి · ప్రతి వాష్ 4★ లేదా ఎక్కువ ఉంచండి")}</TD>
      </VStack>
    </Screen>
  );
}

// MARK: W44 Probation extended

export function ProbationScreen() {
  const { store, router } = useCaptain();
  const dot = (icon: IconName, bg: string, fg: string, title: string, sub: string, k: number) => (
    <VStack key={k} gap={6} align="center" style={{ flex: 1 }}>
      <span style={{ width: 52, height: 52, borderRadius: 26, background: bg, display: "grid", placeItems: "center" }}><Icon name={icon} size={20} color={fg} /></span>
      <T k="label" c={C.heading}>{title}</T>
      <T k="caption">{sub}</T>
    </VStack>
  );
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}
      footer={<WFooter><Button title={store.t("Watch 30-sec tip", "30 सेकंड की टिप देखें", "30 సెకన్ల చిట్కా చూడండి")} icon="play" kind="outline" size="captain" onClick={() => router.push({ n: "refresher" })} /></WFooter>}>
      <VStack gap={14} align="center" style={{ flex: 1, justifyContent: "center" }}>
        <StateCircle icon="calendar" tone="wait" size={112} />
        <TD k="section" w={600} s={23} center>{store.t("1 more day at 4 jobs", "4 काम पर 1 दिन और", "4 పనులతో ఇంకో 1 రోజు")}</TD>
        <WBody center>{store.t("One owner gave 3★: “Mirror was dusty.” Get 4★ or more on all jobs tomorrow to move up.", "एक मालिक ने 3★ दिए: “शीशे पर धूल थी।” कल सभी कामों पर 4★ या ज़्यादा लें तो आगे बढ़ेंगे।", "ఒక యజమాని 3★ ఇచ్చారు: “అద్దం దుమ్ముగా ఉంది.” రేపు అన్ని పనులకు 4★ పైన వస్తే ముందుకు వెళ్తారు.")}</WBody>
        <HStack style={{ width: "100%", paddingTop: 8 }}>
          {dot("check", C.success, C.onSuccess, store.t("Day 1", "दिन 1", "రోజు 1"), "2", 0)}
          {dot("close", C.destructive, "#fff", store.t("Day 2", "दिन 2", "రోజు 2"), "4", 1)}
          {dot("calendar", C.primary, "#fff", store.t("Day 2", "दिन 2", "రోజు 2"), "4", 2)}
          {dot("calendar", C.primaryTint, C.heading, store.t("Day 3", "दिन 3", "రోజు 3"), "6–8", 3)}
        </HStack>
      </VStack>
    </Screen>
  );
}

// MARK: W45 Refresher video

export function RefresherScreen() {
  const { store, router } = useCaptain();
  return (
    <Screen gutter={0} header={<WHeader title={store.t("New tip", "नई टिप", "కొత్త చిట్కా")} back={false} help={false} />}
      footer={<WFooter><Button title={store.t("Play", "चलाएं", "ప్లే చేయండి")} icon="play" size="captain" onClick={() => router.replace([{ n: "video", index: 2 }])} /></WFooter>}>
      <div style={{ height: 202, background: C.camera, display: "grid", placeItems: "center" }}>
        <span style={{ width: 72, height: 72, borderRadius: 36, background: "rgba(255,255,255,.18)", display: "grid", placeItems: "center" }}><Icon name="play" size={28} color="#fff" fill /></span>
      </div>
      <VStack gap={8} style={{ padding: 16 }}>
        <WTitle>{store.t("Mirrors and number plate", "शीशे और नंबर प्लेट", "అద్దాలు, నంబర్ ప్లేట్")}</WTitle>
        <WBody>{store.t("30 seconds. Watch it fully to get jobs again.", "30 सेकंड। पूरा देखें, फिर काम मिलेंगे।", "30 సెకన్లు. పూర్తిగా చూస్తే మళ్ళీ పనులు వస్తాయి.")}</WBody>
        <HStack gap={10} style={{ padding: 14, borderRadius: 12, background: C.waitTint, marginTop: 8 }}>
          <Icon name="lock" size={16} color={C.waitText} />
          <T k="caption" c={C.waitText} s={14.5}>{store.t("New jobs are paused until you watch.", "देखने तक नए काम रुके हैं।", "చూసే వరకు కొత్త పనులు ఆగాయి.")}</T>
        </HStack>
      </VStack>
    </Screen>
  );
}

// MARK: W46 Blocked

export function BlockedScreen() {
  const { store } = useCaptain();
  return (
    <Screen gutter={S.gutterCaptain} scrolls={false}>
      <VStack gap={14} align="center" style={{ flex: 1, justifyContent: "center" }}>
        <StateCircle icon="ban" tone="error" size={112} />
        <TD k="section" w={600} s={23} center>{store.t("You can’t take jobs now", "अभी आप काम नहीं ले सकते", "ఇప్పుడు మీరు పనులు తీసుకోలేరు")}</TD>
        <WBody center>{store.t("Too many low ratings in the last 2 weeks. If you think this is wrong, ask us to check again.", "पिछले 2 हफ़्तों में बहुत कम रेटिंग। अगर यह गलत है, तो हमसे फिर जाँचने को कहें।", "గత 2 వారాల్లో చాలా తక్కువ రేటింగ్‌లు. ఇది తప్పు అనుకుంటే మళ్ళీ తనిఖీ చేయమని అడగండి.")}</WBody>
        <Button title={store.t("Ask to check again", "फिर से जाँच का अनुरोध", "మళ్ళీ తనిఖీ చేయమని అడగండి")} icon="mic" kind="outline" size="captain" style={{ marginTop: 6 }} />
        <T k="caption">{store.t("Your pending money (₹464) will still be paid.", "आपके बाकी पैसे (₹464) फिर भी मिलेंगे।", "మీ బాకీ డబ్బు (₹464) చెల్లిస్తాము.")}</T>
      </VStack>
    </Screen>
  );
}

// MARK: W47 Me

export function MeTab() {
  const { store, router } = useCaptain();
  const [showLanguages, setShowLanguages] = useState(false);
  return (
    <>
      <TabScroll>
        {store.registered ? (
          <HStack gap={14} style={{ paddingTop: 22 }}>
            <WProfilePhoto size={60} />
            <VStack gap={2}>
              <TD k="section" w={600} s={22}>{store.name}</TD>
              <TD k="caption">{store.signedUp ? `${Fmt.phoneShort(store.phone)} · ★ ${store.rating.toFixed(1)}` : Fmt.phoneShort(store.phone)}</TD>
            </VStack>
          </HStack>
        ) : (
          <VStack gap={12} style={{ ...card(18), marginTop: 22 }}>
            <HStack gap={14}>
              <span style={{ width: 60, height: 60, borderRadius: 30, background: C.primaryTint, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="user" size={25} color={C.secondary} /></span>
              <VStack gap={2}>
                <TD k="section" w={600} s={20}>{store.t("You’re looking around", "आप ऐप देख रहे हैं", "మీరు యాప్ చూస్తున్నారు")}</TD>
                <TD k="caption">{store.t("Sign up with your name and number", "नाम और नंबर से साइन अप करें", "పేరు, నంబర్‌తో సైన్ అప్")}</TD>
              </VStack>
            </HStack>
            <Button title={store.t("Sign up", "साइन अप करें", "సైన్ అప్")} size="captain" onClick={() => router.push({ n: "signUp", login: false })} />
            <Link title={store.t("Already a captain? Log in", "पहले से कैप्टन हैं? लॉग इन करें", "ఇప్పటికే కెప్టెన్‌నా? లాగిన్")} onClick={() => router.push({ n: "signUp", login: true })} style={{ alignSelf: "center" }} />
          </VStack>
        )}
        {store.registered && !store.signedUp && (
          <Tap onClick={() => { store.kycFromJob = false; router.push({ n: "steps", problem: false }); }} style={{ ...card(14), display: "flex", alignItems: "center", gap: 14, textAlign: "left" }}>
            <IconBox icon="idCard" size={44} tone="wait" radius={12} />
            <VStack gap={2} style={{ flex: 1 }}>
              <TD k="title" s={17}>{store.t("Finish KYC", "KYC पूरा करें", "KYC పూర్తి చేయండి")}</TD>
              <TD k="caption">{`${store.kycStagesDone}/4 · ` + store.t("Needed to take jobs", "काम लेने के लिए ज़रूरी", "పనులు తీసుకోవడానికి అవసరం")}</TD>
            </VStack>
            <Icon name="chevron" size={14} color={C.secondary} />
          </Tap>
        )}
        <VStack style={card(14)}>
          <ListRow icon="location" title={store.t("Where I work", "मैं कहाँ काम करूँ", "నేను ఎక్కడ పని చేస్తాను")} subtitle={store.workSummary} onClick={() => router.push({ n: "workArea" })} />
          <Divider inset={54} />
          <ListRow icon="languages" title={store.t("Language", "भाषा", "భాష")} subtitle={store.langName} onClick={() => setShowLanguages(true)} />
          {store.registered && (
            <>
              <Divider inset={54} />
              <ListRow icon="phone" title={store.t("Phone number", "फ़ोन नंबर", "ఫోన్ నంబర్")} subtitle={Fmt.phone(store.phone)} onClick={() => router.push({ n: "changePhone" })} />
              <Divider inset={54} />
              <ListRow icon={store.notificationsOn ? "bell" : "bellSlash"} title={store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు")}
                subtitle={!store.notificationsOn ? store.t("Off", "बंद", "ఆఫ్") : wIsMuted(store.notifPrefs) ? store.t("Muted", "म्यूट", "మ్యూట్") : store.t("On", "चालू", "ఆన్")}
                onClick={() => router.push({ n: "notificationSettings" })} />
            </>
          )}
          {store.signedUp && (
            <>
              <Divider inset={54} />
              <ListRow icon="rupee" title={store.t("Payout UPI", "पेमेंट UPI", "చెల్లింపు UPI")} subtitle={store.upi} onClick={() => router.push({ n: "editUPI" })} />
              <Divider inset={54} />
              <ListRow icon="star" title={store.t("My level", "मेरा लेवल", "నా స్థాయి")} subtitle={store.t(`Day ${store.levelDay} of 3`, `दिन ${store.levelDay} / 3`, `రోజు ${store.levelDay} / 3`)} onClick={() => router.push({ n: "level" })} />
            </>
          )}
          <Divider inset={54} />
          <ListRow icon="play" title={store.t("Training videos", "ट्रेनिंग वीडियो", "శిక్షణ వీడియోలు")} onClick={() => router.push({ n: "training" })} />
          <Divider inset={54} />
          <ListRow icon="sparkle" title={store.t(`Why wash with ${Brand.name}`, `${Brand.name} के साथ क्यों`, `${Brand.name} తో ఎందుకు`)} onClick={() => router.push({ n: "welcome" })} />
        </VStack>
        <VStack style={card(14)}>
          <ListRow icon="help" title={store.t("Help", "मदद", "సహాయం")} onClick={() => router.push({ n: "help" })} />
          {store.registered && (
            <>
              <Divider inset={54} />
              <ListRow icon="logout" title={store.t("Log out", "लॉग आउट", "లాగ్ అవుట్")} onClick={() => { store.logOut(); router.home(); }} />
            </>
          )}
        </VStack>
      </TabScroll>
      <Sheet open={showLanguages} onClose={() => setShowLanguages(false)} height={380} gutter={S.gutterCaptain}>
        <VStack gap={12}>
          <TD k="section" w={600} s={21} style={{ paddingTop: 10, paddingBottom: 4 }}>{store.t("Choose your language", "भाषा चुनें", "భాష ఎంచుకోండి")}</TD>
          {([["en", "A", "English"], ["hi", "अ", "हिन्दी · Hindi"], ["te", "అ", "తెలుగు · Telugu"]] as const).map(([l, g, t]) => (
            <LangTile key={l} lang={l} glyph={g} title={t} height={72} onPick={() => setTimeout(() => setShowLanguages(false), 250)} />
          ))}
        </VStack>
      </Sheet>
    </>
  );
}

// MARK: W48 Help

export const helpTopicIcon = (t: HelpTopic): IconName => ({ money: "rupee", job: "car", rating: "star", app: "phone" } as const)[t];

export function WHelpScreen() {
  const { store, router } = useCaptain();
  const row = (icon: IconName, title: string, action: () => void, emergency = false) => (
    <Tap onClick={action} style={{ display: "flex", alignItems: "center", gap: 16, padding: "0 16px", height: 80, borderRadius: 16, background: emergency ? C.errorTint : "#fff", boxShadow: `inset 0 0 0 1px ${emergency ? "rgba(179,38,30,.4)" : C.border}` }}>
      <IconBox icon={icon} size={52} tone={emergency ? "error" : "info"} radius={12} />
      <T k="value" s={18} c={emergency ? C.destructive : C.heading} style={{ flex: 1, textAlign: "left" }}>{title}</T>
      <Icon name={emergency ? "phone" : "chevron"} size={emergency ? 19 : 15} color={emergency ? C.destructive : C.secondary} />
    </Tap>
  );
  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={store.t("Help", "मदद", "సహాయం")} help={false} />}>
      <WTitle style={{ paddingTop: 10 }}>{store.t("What’s the problem?", "क्या समस्या है?", "సమస్య ఏమిటి?")}</WTitle>
      <WBody style={{ paddingTop: 4, paddingBottom: 14 }}>{store.t("Most problems get fixed in a minute.", "ज़्यादातर समस्याएं एक मिनट में ठीक होती हैं।", "చాలా సమస్యలు ఒక్క నిమిషంలో తీరుతాయి.")}</WBody>
      <div style={{ paddingBottom: 18 }}><HelpLadder current={0} /></div>
      <VStack gap={12}>
        {HelpTopics.map((t) => <div key={t}>{row(helpTopicIcon(t), helpTopicTitle(t, store.t.bind(store)), () => router.push({ n: "helpFlow", topic: t }))}</div>)}
      </VStack>
      <TD k="label" style={{ paddingTop: 24, paddingBottom: 8 }}>{store.t("Emergency", "इमरजेंसी", "అత్యవసరం")}</TD>
      {row("warning", store.t("Accident, injury or safety", "दुर्घटना, चोट या सुरक्षा", "ప్రమాదం, గాయం లేదా భద్రత"), () => Support.call(), true)}
      <TD k="caption" style={{ paddingTop: 8 }}>{store.t("Only for emergencies. Works 24 hours.", "सिर्फ़ इमरजेंसी के लिए। 24 घंटे चालू।", "అత్యవసరాలకు మాత్రమే. 24 గంటలు.")}</TD>
    </Screen>
  );
}

export const helpTopicTitle = (t: HelpTopic, tr: (en: string, hi: string, te: string) => string) => ({
  money: tr("Money or payout", "पैसे या पेमेंट", "డబ్బు లేదా చెల్లింపు"),
  job: tr("Problem at a job", "काम पर समस्या", "పనిలో సమస్య"),
  rating: tr("Rating or photo check", "रेटिंग या फ़ोटो जाँच", "రేటింగ్ లేదా ఫోటో తనిఖీ"),
  app: tr("App not working", "ऐप नहीं चल रहा", "యాప్ పనిచేయట్లేదు"),
})[t];
