"use client";

import { useEffect, useState } from "react";
import { C, S, toneBanner, toneBg, type Tone } from "../../ds/tokens";
import { Avatar, Button, Chip, Divider, Flow, HStack, Link, PhotoPlaceholder, Screen, SelectionTile, StateCircle, Tap, T, TD, VStack, card } from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt, Support } from "../../lib/fmt";
import { useCaptain, WBody, WFooter, WHeader, WTitle } from "../ctx";
import { currentSociety, places, societies, type HelpTopic, type WorkMode } from "../store";
import { HelpLadder } from "./parts";
import { helpTopicTitle } from "./money";

// MARK: Support ladder: 1) quick check by the app → 2) sort it out with the owner → 3) team

export function HelpFlowScreen({ topic }: { topic: HelpTopic }) {
  const { store, router } = useCaptain();
  const [level, setLevel] = useState(1);
  const [checking, setChecking] = useState(true);
  const [jobIssue, setJobIssue] = useState<number | null>(null);
  const [sentMessage, setSentMessage] = useState<string | null>(null);
  const [callbackRequested, setCallbackRequested] = useState(false);
  const [solved, setSolved] = useState(false);
  const usesOwner = topic !== "app";

  // Step 1: the app checks first (photos, payouts, job status).
  useEffect(() => { const t = setTimeout(() => setChecking(false), 1800); return () => clearTimeout(t); }, []);

  const result = (icon: IconName, tone: Tone, title: string, text: string) => (
    <HStack align="start" gap={12} className="wh-fade-in" style={{ padding: 16, borderRadius: 16, background: toneBg[tone], marginTop: 12 }}>
      <Icon name={icon} size={21} color={tone === "ok" ? C.onSuccess : toneBanner[tone]} />
      <VStack gap={6} style={{ flex: 1 }}>
        <TD k="title" s={18}>{title}</TD>
        <TD k="body" s={15.5}>{text}</TD>
      </VStack>
    </HStack>
  );
  const photoCompare = (
    <HStack gap={8} style={{ paddingTop: 12 }}>
      <PhotoPlaceholder height={92} icon="car" tag={store.t("Before", "पहले", "ముందు")} />
      <PhotoPlaceholder height={92} icon="sparkle" tag={store.t("After", "बाद", "తర్వాత")} tagTone="ok" />
    </HStack>
  );

  const issues: [IconName, string, string][] = [
    ["door", store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను"), store.t("Show the owner’s gate pass to the guard. It’s on the Go to vehicle screen.", "गार्ड को मालिक का गेट पास दिखाएं। यह ‘गाड़ी तक जाएं’ स्क्रीन पर है।", "గార్డ్‌కి యజమాని గేట్ పాస్ చూపించండి. ఇది ‘వాహనం దగ్గరికి వెళ్ళండి’ స్క్రీన్‌లో ఉంది.")],
    ["search", store.t("Can’t find vehicle", "गाड़ी नहीं मिल रही", "వాహనం కనబడట్లేదు"), store.t("Check the owner’s vehicle photos and slot number. The plate on the vehicle must match.", "मालिक की गाड़ी की फ़ोटो और स्लॉट नंबर देखें। गाड़ी की प्लेट मिलनी चाहिए।", "యజమాని వాహనం ఫోటోలు, స్లాట్ నంబర్ చూడండి. ప్లేట్ సరిపోలాలి.")],
    ["warning", store.t("Vehicle already damaged", "गाड़ी पहले से खराब है", "వాహనం ముందే దెబ్బతింది"), store.t("Take a clear before-photo of the damage. Our photo check marks it as old damage, so you’re safe.", "नुकसान की साफ़ ‘पहले’ फ़ोटो लें। फ़ोटो जाँच इसे पुराना नुकसान मानेगी, आप सुरक्षित हैं।", "దెబ్బను స్పష్టంగా ‘ముందు’ ఫోటో తీయండి. ఫోటో తనిఖీ దాన్ని పాత దెబ్బగా గుర్తిస్తుంది.")],
    ["drop", store.t("No water available", "पानी नहीं है", "నీళ్ళు లేవు"), store.t("Use the society tap near the lift or ask the guard. For a water wash, 1 bucket is enough.", "लिफ़्ट के पास का नल इस्तेमाल करें या गार्ड से पूछें। पानी वाली धुलाई के लिए 1 बाल्टी काफ़ी है।", "లిఫ్ట్ దగ్గర కుళాయి వాడండి లేదా గార్డ్‌ని అడగండి. 1 బకెట్ చాలు.")],
  ];

  const j = store.current;
  const msgs = [
    store.t("I’m at the gate. Please allow entry.", "मैं गेट पर हूँ। कृपया अंदर आने दें।", "నేను గేట్ దగ్గర ఉన్నాను. లోపలికి అనుమతించండి."),
    store.t("I can’t find the vehicle. Is it in the slot?", "गाड़ी नहीं मिल रही। क्या स्लॉट में है?", "వాహనం కనబడట్లేదు. స్లాట్‌లో ఉందా?"),
    store.t("Please check the photos in the app.", "कृपया ऐप में फ़ोटो देखें।", "దయచేసి యాప్‌లో ఫోటోలు చూడండి."),
  ];

  return (
    <Screen gutter={S.gutterCaptain} header={<WHeader title={helpTopicTitle(topic, store.t.bind(store))} help={false} />}
      footer={!solved ? (
        <WFooter>
          <VStack gap={6}>
            {level < 3 ? (
              <>
                <Button title={store.t("Solved", "हल हो गया", "పరిష్కారమైంది")} icon="check" size="captain" enabled={!(level === 1 && checking)} onClick={() => setSolved(true)} />
                <Button title={store.t("Still a problem", "अभी भी समस्या है", "ఇంకా సమస్య ఉంది")} kind="text" enabled={!(level === 1 && checking)}
                  onClick={() => setLevel(level === 1 && !usesOwner ? 3 : level + 1)} />
              </>
            ) : !callbackRequested ? (
              <Button title={store.t("Ask our team to call me", "हमारी टीम से कॉल मँगवाएं", "మా బృందం కాల్ చేయమనండి")} icon="phone" size="captain" onClick={() => setCallbackRequested(true)} />
            ) : (
              <Button title={store.t("Back to home", "होम पर वापस", "హోమ్‌కి తిరిగి")} size="captain" onClick={() => router.home()} />
            )}
          </VStack>
        </WFooter>
      ) : undefined}>
      <div style={{ paddingTop: 10, paddingBottom: 20 }}><HelpLadder current={solved ? 4 : level} skipOwner={!usesOwner} /></div>
      {solved ? (
        <VStack gap={12} align="center" className="wh-fade-in" style={{ paddingTop: 24 }}>
          <StateCircle icon="check" tone="ok" size={96} />
          <TD k="section" w={600} s={22}>{store.t("Glad it’s sorted", "अच्छा हुआ, हल हो गया", "తీరింది, సంతోషం")}</TD>
          <WBody>{store.t("You can come back to Help any time.", "आप कभी भी मदद पर वापस आ सकते हैं।", "ఎప్పుడైనా సహాయానికి రావచ్చు.")}</WBody>
          <Button title={store.t("Back to home", "होम पर वापस", "హోమ్‌కి తిరిగి")} size="captain" style={{ marginTop: 10 }} onClick={() => router.home()} />
        </VStack>
      ) : level === 1 ? (
        <>
          <T k="label" c={C.secondary}>{store.t("Step 1 · We’re checking", "कदम 1 · हम जाँच रहे हैं", "దశ 1 · మేము తనిఖీ చేస్తున్నాం")}</T>
          {checking ? (
            <VStack gap={14} align="center" style={{ paddingTop: 30 }}>
              <StateCircle icon="sparkle" size={92} spinning />
              <WBody>{store.t("Checking photos and job details…", "फ़ोटो और काम की जानकारी देख रहे हैं…", "ఫోటోలు, పని వివరాలు చూస్తున్నాం…")}</WBody>
            </VStack>
          ) : topic === "money" ? (
            <>
              {result("lock", "wait", store.t("₹116 is on hold", "₹116 रोके गए हैं", "₹116 నిలిపివేయబడింది"), store.t("Owner said the bonnet had water streaks. Your after-photos look clean, so we asked the owner to check again. Other jobs are paid as normal.", "मालिक ने कहा बोनट पर पानी के निशान थे। आपकी बाद की फ़ोटो साफ़ हैं, इसलिए हमने मालिक से फिर देखने को कहा। बाकी कामों के पैसे सामान्य रूप से मिलेंगे।", "బానెట్‌పై నీటి గీతలు ఉన్నాయని యజమాని చెప్పారు. మీ తర్వాతి ఫోటోలు శుభ్రంగా ఉన్నాయి, అందుకే మళ్ళీ చూడమని యజమానిని అడిగాము. మిగతా పనుల డబ్బు మామూలుగానే వస్తుంది."))}
              {photoCompare}
            </>
          ) : topic === "rating" ? (
            <>
              {result("checkCircle", "ok", store.t("Your photos look good", "आपकी फ़ोटो ठीक हैं", "మీ ఫోటోలు బాగున్నాయి"), store.t("We compared before and after photos. If they show a good wash, a low rating won’t count against you.", "हमने पहले और बाद की फ़ोटो मिलाईं। अगर धुलाई अच्छी दिखी, तो कम रेटिंग आपके ख़िलाफ़ नहीं गिनी जाएगी।", "ముందు, తర్వాతి ఫోటోలు పోల్చాము. వాష్ బాగుంటే, తక్కువ రేటింగ్ మీకు వ్యతిరేకంగా లెక్కించబడదు."))}
              {photoCompare}
            </>
          ) : topic === "app" ? (
            result("refresh", "info", store.t("Try these", "ये करके देखें", "ఇవి ప్రయత్నించండి"), store.t("1. Turn internet off and on.  2. Close the app and open again.  3. Keep battery above 15%. Your photos are saved on the phone.", "1. इंटरनेट बंद करके चालू करें।  2. ऐप बंद करके फिर खोलें।  3. बैटरी 15% से ऊपर रखें। आपकी फ़ोटो फ़ोन में सेव हैं।", "1. ఇంటర్నెట్ ఆఫ్ చేసి ఆన్ చేయండి.  2. యాప్ మూసి మళ్ళీ తెరవండి.  3. బ్యాటరీ 15% పైన ఉంచండి. మీ ఫోటోలు ఫోన్‌లో సేవ్ అయ్యాయి."))
          ) : (
            <>
              <TD k="section" w={600} style={{ paddingTop: 10, paddingBottom: 10 }}>{store.t("What happened?", "क्या हुआ?", "ఏమైంది?")}</TD>
              <VStack gap={10}>
                {issues.map(([icon, title], i) => <SelectionTile key={i} icon={icon} title={title} selected={jobIssue === i} radio onClick={() => setJobIssue(i)} />)}
              </VStack>
              {jobIssue != null && <div style={{ paddingTop: 6 }}>{result("sparkle", "info", store.t("Try this", "ये करें", "ఇది చేయండి"), issues[jobIssue][2])}</div>}
            </>
          )}
        </>
      ) : level === 2 ? (
        <>
          <T k="label" c={C.secondary}>{store.t("Step 2 · Talk to the owner", "कदम 2 · मालिक से बात करें", "దశ 2 · యజమానితో మాట్లాడండి")}</T>
          <HStack gap={12} style={{ ...card(16), marginTop: 10 }}>
            <Avatar initials={j.owner.slice(0, 1)} size={52} />
            <VStack gap={4}>
              <TD k="title" s={18}>{j.owner}</TD>
              <TD k="caption">{`${j.society} · ${j.plate}`}</TD>
            </VStack>
          </HStack>
          <TD k="label" style={{ paddingTop: 18, paddingBottom: 8 }}>{store.t("Send a quick message", "जल्दी संदेश भेजें", "త్వరగా సందేశం పంపండి")}</TD>
          <VStack gap={8}>
            {msgs.map((m) => (
              <Tap key={m} onClick={() => setSentMessage(m)} style={{ display: "flex", alignItems: "center", gap: 10, padding: 14, borderRadius: 14, background: sentMessage === m ? C.successTint : "#fff", boxShadow: `inset 0 0 0 1px ${C.border}`, textAlign: "left" }}>
                <Icon name={sentMessage === m ? "checkCircle" : "chat"} size={17} color={sentMessage === m ? C.success : C.primaryStrong} />
                <T k="body" s={15.5} style={{ flex: 1 }}>{m}</T>
              </Tap>
            ))}
          </VStack>
          {sentMessage && <TD k="caption" c={C.onSuccess} style={{ paddingTop: 8 }}>{store.t("Sent. The owner gets it on WhatsApp.", "भेज दिया। मालिक को WhatsApp पर मिलेगा।", "పంపాము. యజమానికి WhatsApp లో వస్తుంది.")}</TD>}
          <Tap onClick={() => Support.call()} style={{ marginTop: 12, display: "flex", alignItems: "center", gap: 10, padding: 14, borderRadius: 14, background: C.primaryTint }}>
            <Icon name="phone" size={17} color={C.primaryStrong} />
            <T k="title" s={16} c={C.primaryStrong}>{store.t("Call owner (number stays hidden)", "मालिक को कॉल करें (नंबर छिपा रहेगा)", "యజమానికి కాల్ (నంబర్ దాచి ఉంటుంది)")}</T>
          </Tap>
        </>
      ) : (
        <>
          <T k="label" c={C.secondary}>{store.t("Step 3 · Our team", "कदम 3 · हमारी टीम", "దశ 3 · మా బృందం")}</T>
          {callbackRequested ? (
            <VStack gap={12} align="center" className="wh-fade-in" style={{ paddingTop: 24 }}>
              <StateCircle icon="phone" tone="ok" size={96} />
              <TD k="section" w={600} s={22}>{store.t("We’ll call you soon", "हम जल्दी कॉल करेंगे", "మేము త్వరలో కాల్ చేస్తాము")}</TD>
              <WBody center>{store.t(`Within 30 minutes on ${Fmt.phone(store.phone)}. Keep your phone close.`, `30 मिनट में ${Fmt.phone(store.phone)} पर। फ़ोन पास रखें।`, `30 నిమిషాల్లో ${Fmt.phone(store.phone)} కి. ఫోన్ దగ్గర ఉంచుకోండి.`)}</WBody>
              <T k="caption">{`${store.t("Ticket", "टिकट", "టికెట్")} #WH-2814`}</T>
            </VStack>
          ) : (
            <>
              <WBody style={{ paddingTop: 8 }}>{store.t("Sorry this didn’t get fixed. Our team will look at your photos and job, then call you.", "माफ़ करें, यह ठीक नहीं हुआ। हमारी टीम आपकी फ़ोटो और काम देखकर आपको कॉल करेगी।", "క్షమించండి, ఇది తీరలేదు. మా బృందం మీ ఫోటోలు, పని చూసి మీకు కాల్ చేస్తుంది.")}</WBody>
              <HStack gap={10} style={{ paddingTop: 14 }}>
                <Icon name="clock" size={17} color={C.secondary} />
                <T k="caption">7 AM – 9 PM · Hindi, Telugu, English</T>
              </HStack>
              <Button title={store.t("Explain by voice (optional)", "आवाज़ में बताएं (ज़रूरी नहीं)", "వాయిస్‌తో చెప్పండి (ఐచ్ఛికం)")} icon="mic" kind="outline" size="captain" style={{ marginTop: 18 }} />
            </>
          )}
        </>
      )}
    </Screen>
  );
}

// MARK: W57 Where I work: which jobs ring for this captain

export function WorkAreaScreen() {
  const { store, router } = useCaptain();
  const [mode, setMode] = useState<WorkMode>(store.workMode);
  const [radius, setRadius] = useState(store.radiusKm);
  const [picked, setPicked] = useState<string[]>(store.chosenSocieties);
  const [place, setPlace] = useState(store.workPlace);

  const choice = (m: WorkMode, icon: IconName, title: string, sub: string) => (
    <SelectionTile icon={icon} title={title} subtitle={sub} selected={mode === m} radio onClick={() => {
      setMode(m);
      if (m === "societies" && !picked.length) setPicked([currentSociety.name]);
    }} />
  );

  const save = () => {
    store.workMode = mode;
    store.radiusKm = radius;
    store.chosenSocieties = picked;
    store.workPlace = place;
    store.toast = store.t(`Saved: ${store.workSummary}`, `सेव हुआ: ${store.workSummary}`, `సేవ్ అయింది: ${store.workSummary}`);
    router.pop();
  };

  return (
    <Screen canvas gutter={S.gutterCaptain} header={<WHeader title={store.t("Where I work", "मैं कहाँ काम करूँ", "నేను ఎక్కడ పని చేస్తాను")} help={false} />}
      footer={<WFooter><Button title={store.t("Save", "सेव करें", "సేవ్ చేయండి")} size="captain" enabled={mode !== "societies" || picked.length > 0} onClick={save} /></WFooter>}>
      <WTitle style={{ paddingTop: 10 }}>{store.t("Which jobs should ring?", "कौन से काम बजें?", "ఏ పనులు మోగాలి?")}</WTitle>
      <WBody style={{ paddingTop: 4, paddingBottom: 16 }}>{store.t("You can change this any time.", "इसे कभी भी बदल सकते हैं।", "ఎప్పుడైనా మార్చవచ్చు.")}</WBody>
      <VStack gap={12} style={{ paddingBottom: 24 }}>
        {choice("all", "layers", store.t("All jobs", "सभी काम", "అన్ని పనులు"), store.t("Any job near you", "आपके आस-पास का कोई भी काम", "మీ దగ్గర ఏ పనైనా"))}
        {choice("societies", "building", store.t("My societies", "मेरी सोसाइटी", "నా సొసైటీలు"), store.t("Only buildings you pick", "सिर्फ़ आपकी चुनी बिल्डिंग", "మీరు ఎంచుకున్న భవనాలు మాత్రమే"))}
        {mode === "societies" && (
          <VStack gap={12} className="wh-fade-in">
            {/* Societies: "you're here now" first, then the rest with distance. */}
            <HStack align="start" gap={12} style={{ padding: 14, borderRadius: 14, background: C.primaryTint }}>
              <Icon name="locate" size={19} color={C.primaryStrong} />
              <VStack gap={6} align="start">
                <TD k="title" s={16}>{store.t(`You’re at ${currentSociety.name} now`, `आप अभी ${currentSociety.name} में हैं`, `మీరు ఇప్పుడు ${currentSociety.name} లో ఉన్నారు`)}</TD>
                <Link title={store.t("Only jobs here", "सिर्फ़ यहाँ के काम", "ఇక్కడి పనులు మాత్రమే")} k="caption" style={{ minHeight: 22 }} onClick={() => setPicked([currentSociety.name])} />
              </VStack>
            </HStack>
            <div style={card(14)}>
              {societies.map((s, i) => {
                const on = picked.includes(s.name);
                return (
                  <div key={s.name}>
                    <Tap className="wh-nopress" onClick={() => setPicked(on ? picked.filter((x) => x !== s.name) : [...picked, s.name])}
                      style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 0", width: "100%", textAlign: "left" }}>
                      <Icon name={on ? "squareCheck" : "square"} size={25} color={on ? C.primary : C.muted} />
                      <VStack gap={2}>
                        <TD k="rowTitle" s={16.5}>{s.name}</TD>
                        <TD k="caption">{`${s.area} · ${s.km < 1 ? `${Math.round(s.km * 1000)} m` : `${s.km.toFixed(1)} km`}`}</TD>
                      </VStack>
                    </Tap>
                    {i < societies.length - 1 && <Divider inset={36} />}
                  </div>
                );
              })}
            </div>
          </VStack>
        )}
        {choice("radius", "locate", store.t("Distance", "दूरी", "దూరం"), store.t("Jobs within a few km", "कुछ km के अंदर के काम", "కొన్ని కి.మీ లోపు పనులు"))}
        {mode === "radius" && (
          <HStack gap={8} className="wh-fade-in">
            {[1, 3, 5, 10].map((k) => <div key={k} style={{ flex: 1 }}><Chip title={`${k} km`} selected={radius === k} height={48} fill onClick={() => setRadius(k)} /></div>)}
          </HStack>
        )}
        {choice("place", "location", store.t("A place I choose", "मेरी चुनी जगह", "నేను ఎంచుకున్న ప్రదేశం"), store.t("Jobs in one area", "एक इलाके के काम", "ఒక ప్రాంతంలో పనులు"))}
        {mode === "place" && (
          <Flow gap={8}>
            {places.map((p) => <Chip key={p} title={p} selected={place === p} height={44} onClick={() => setPlace(p)} />)}
          </Flow>
        )}
      </VStack>
    </Screen>
  );
}
