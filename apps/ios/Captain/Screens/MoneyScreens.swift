import SwiftUI

// MARK: W40 Money

struct MoneyTab: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var range = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.t("Money", "पैसे", "డబ్బు")).wTitle().padding(.top, 22)
                if !store.signedUp {
                    GuestNotice(text: store.t("Example earnings. Your money shows here after your first job, and comes to your UPI every night.",
                                              "उदाहरण कमाई। पहले काम के बाद आपके पैसे यहाँ दिखेंगे और हर रात UPI पर आएंगे।",
                                              "ఉదాహరణ సంపాదన. మొదటి పని తర్వాత మీ డబ్బు ఇక్కడ కనిపిస్తుంది, ప్రతి రాత్రి UPI కి వస్తుంది."))
                }
                WSegmented(options: [store.t("Today", "आज", "ఈరోజు"), store.t("This week", "इस हफ़्ते", "ఈ వారం")], selection: $range, height: 50)
                VStack(alignment: .leading, spacing: 10) {
                    Text(range == 0 ? store.t("Comes to UPI tonight before 12", "आज रात 12 से पहले UPI में आएगा", "ఈ రాత్రి 12 లోపు UPI కి వస్తుంది")
                                    : store.t("This week so far", "इस हफ़्ते अब तक", "ఈ వారం ఇప్పటి వరకు"))
                        .wText(.caption)
                    Text(Fmt.rupees(range == 0 ? store.earnedToday : 4562)).wText(.bigMoney).wMoney()
                    HStack(spacing: 10) {
                        tile(.check, .ok, Fmt.rupees(range == 0 ? store.approvedToday : 4342), store.t("Approved", "मंज़ूर", "ఆమోదించబడింది"))
                        tile(.clock, .wait, Fmt.rupees(range == 0 ? store.waitingToday : 220), store.t("Waiting", "इंतज़ार में", "వేచి ఉంది"))
                    }
                }
                .wCard(padding: 18)
                VStack(spacing: 0) {
                    WListRow(icon: .receipt, title: store.t("Yesterday", "कल", "నిన్న") + " · ₹1,262",
                             subtitle: store.t("Paid", "भेजा", "చెల్లించారు") + " 11:48 PM · \(store.upi)") { router.push(.payoutDetail) }
                    WDivider(inset: 54)
                    WListRow(icon: .receipt, title: store.t("Thu", "गुरु", "గురు") + " · ₹980",
                             subtitle: store.t("Paid", "भेजा", "చెల్లించారు") + " 11:52 PM") { router.push(.payoutDetail) }
                    WDivider(inset: 54)
                    if store.noShowCancelled {
                        WListRow(icon: .ban, title: store.t("Penalty", "जुर्माना", "జరిమానా") + " · −₹[NO-SHOW PENALTY]",
                                 subtitle: store.t("Didn’t reach", "नहीं पहुँचे", "చేరుకోలేదు") + " \(store.noShowPlate) · " + store.t("cut from next payout", "अगले पेमेंट से कटेगा", "తదుపరి చెల్లింపు నుండి"),
                                 tone: .error) { router.push(.noShowCancelled) }
                        WDivider(inset: 54)
                    }
                    WListRow(icon: .lock, title: store.t("On hold", "रोका गया", "నిలిపివేయబడింది") + " · ₹116",
                             subtitle: store.t("Owner reported a problem", "मालिक ने शिकायत की", "యజమాని సమస్య చెప్పారు"), tone: .wait) { router.push(.payoutHeld) }
                }
                .wCard(padding: 14)
            }
            .padding(.horizontal, WSpace.gutterCaptain)
            .padding(.bottom, 20)
        }
        .background(WColor.canvas)
    }

    func tile(_ icon: WIcon, _ tone: WTone, _ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WIconView(icon: icon, size: 21, color: tone == .ok ? WColor.heading : tone.foreground)
            Text(big).wText(.section, weight: .semibold).wMoney()
            Text(small).wText(.caption, color: WColor.heading)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: W41 Payout detail

struct PayoutDetailScreen: View {
    @Environment(CaptainStore.self) var store
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Fri, 9 Oct", "शुक्र, 9 अक्टू", "శుక్ర, 9 అక్టో"), subtitle: store.t("Paid 11:48 PM", "11:48 PM पर भेजा", "11:48 PM కి చెల్లించారు"))
        } content: {
            Text(store.t("Sent to", "भेजा गया", "పంపబడింది") + " \(store.upi)").wText(.caption).padding(.top, 14)
            Text("₹1,262").wText(.bigMoney).wMoney().padding(.top, 4)
            HStack(spacing: 8) {
                WIconView(icon: .check, size: 12, color: WColor.onSuccess)
                Text(store.t("Paid", "भेज दिया", "చెల్లించారు")).wText(.label, color: WColor.onSuccess)
                Spacer()
            }
            .padding(.horizontal, 12).frame(height: 32)
            .background(WColor.successTint, in: Capsule())
            .padding(.top, 10).padding(.bottom, 18)
            WKeyValueCard(rows: [
                (store.t("9 jobs", "9 काम", "9 పనులు"), "₹1,290"),
                (store.t("Late (2 jobs)", "देरी (2 काम)", "ఆలస్యం (2 పనులు)"), "−₹28"),
                (store.t("Total", "कुल", "మొత్తం"), "₹1,262"),
            ], boldLast: true)
            Text("UPI ref 4410 2219 8830").wText(.caption).padding(.top, 18)
        } footer: { EmptyView() }
    }
}

// MARK: W42 Money held

struct PayoutHeldScreen: View {
    @Environment(CaptainStore.self) var store
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Money held", "पैसे रोके गए", "డబ్బు నిలిపివేయబడింది"))
        } content: {
            Text(store.t("₹116 is on hold", "₹116 रोके गए हैं", "₹116 నిలిపివేయబడింది")).wTitle().padding(.top, 10)
            Text(store.t("Owner said the bonnet had water streaks.", "मालिक ने कहा बोनट पर पानी के निशान थे।", "బానెట్‌పై నీటి గీతలు ఉన్నాయని యజమాని చెప్పారు."))
                .wBodyBig().padding(.top, 6).padding(.bottom, 18)
            HStack(spacing: 8) {
                WPhotoPlaceholder(icon: .car, tag: store.t("Before", "पहले", "ముందు")).frame(height: 96)
                WPhotoPlaceholder(icon: .sparkle, tag: store.t("After", "बाद", "తర్వాత"), tagTone: .ok).frame(height: 96)
                WPhotoPlaceholder(icon: .image).frame(height: 96).overlay(alignment: .bottom) {
                    Text(store.t("Owner", "मालिक", "యజమాని")).wText(.small).padding(.bottom, 14)
                }
            }
            WBanner(tone: .info, icon: .clock, text: store.t("We decide within 24 hours. Your other jobs are paid as normal.", "हम 24 घंटे में फ़ैसला करेंगे। बाकी कामों के पैसे सामान्य रूप से मिलेंगे।", "24 గంటల్లో నిర్ణయిస్తాము. మీ ఇతర పనుల డబ్బు మామూలుగానే వస్తుంది."))
                .padding(.top, 16)
        } footer: {
            WFooter {
                WButton(store.t("Explain by voice", "आवाज़ में बताएं", "వాయిస్‌తో వివరించండి"), icon: .mic, kind: .outline, size: .captain) {}
            }
        }
    }
}

// MARK: W43 My level

struct LevelScreen: View {
    @Environment(CaptainStore.self) var store
    var body: some View {
        WScreen(canvas: true, gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("My level", "मेरा लेवल", "నా స్థాయి"))
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.t("New captain: day \(store.levelDay) of 3", "नए कैप्टन: दिन \(store.levelDay) / 3", "కొత్త కెప్టెన్: రోజు \(store.levelDay) / 3")).wText(.section, weight: .semibold)
                HStack {
                    day(1, "2 " + store.t("jobs", "काम", "పనులు"))
                    day(2, "4 " + store.t("jobs", "काम", "పనులు"))
                    day(3, "6–8")
                }
            }
            .wCard(padding: 18)
            .padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                Text(store.t("Your rating", "आपकी रेटिंग", "మీ రేటింగ్")).wText(.caption)
                HStack(spacing: 10) {
                    Text(String(format: "%.1f", store.rating)).wText(.bigMoney)
                    ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").foregroundStyle(WColor.star) }
                }
                Text(store.t("From 6 washes · keep every wash at 4★ or more", "6 धुलाई से · हर धुलाई 4★ या ज़्यादा रखें", "6 వాష్‌ల నుండి · ప్రతి వాష్ 4★ లేదా ఎక్కువ ఉంచండి")).wText(.caption)
            }
            .wCard(padding: 18)
            .padding(.top, 14)
        } footer: { EmptyView() }
    }

    func day(_ d: Int, _ sub: String) -> some View {
        let state = d < store.levelDay ? 0 : (d == store.levelDay ? 1 : 2)
        return VStack(spacing: 6) {
            WIconView(icon: state == 0 ? .check : .calendar, size: 22, color: state == 0 ? WColor.onSuccess : (state == 1 ? .white : WColor.heading))
                .frame(width: 58, height: 58)
                .background(state == 0 ? WColor.success : (state == 1 ? WColor.primary : WColor.primaryTint), in: Circle())
            Text(store.t("Day \(d)", "दिन \(d)", "రోజు \(d)")).wText(.title)
            Text(sub).wText(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: W44 Probation extended

struct ProbationScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) { EmptyView() } content: {
            VStack(spacing: 14) {
                Spacer()
                WStateCircle(icon: .calendar, tone: .wait, size: 112)
                Text(store.t("1 more day at 4 jobs", "4 काम पर 1 दिन और", "4 పనులతో ఇంకో 1 రోజు")).wText(.section, weight: .semibold, size: 23)
                Text(store.t("One owner gave 3★: “Mirror was dusty.” Get 4★ or more on all jobs tomorrow to move up.",
                             "एक मालिक ने 3★ दिए: “शीशे पर धूल थी।” कल सभी कामों पर 4★ या ज़्यादा लें तो आगे बढ़ेंगे।",
                             "ఒక యజమాని 3★ ఇచ్చారు: “అద్దం దుమ్ముగా ఉంది.” రేపు అన్ని పనులకు 4★ పైన వస్తే ముందుకు వెళ్తారు."))
                    .wBodyBig().multilineTextAlignment(.center)
                HStack {
                    dot(.check, WColor.success, WColor.onSuccess, store.t("Day 1", "दिन 1", "రోజు 1"), "2")
                    dot(.close, WColor.destructive, .white, store.t("Day 2", "दिन 2", "రోజు 2"), "4")
                    dot(.calendar, WColor.primary, .white, store.t("Day 2", "दिन 2", "రోజు 2"), "4")
                    dot(.calendar, WColor.primaryTint, WColor.heading, store.t("Day 3", "दिन 3", "రోజు 3"), "6–8")
                }
                .padding(.top, 8)
                Spacer()
            }
        } footer: {
            WFooter {
                WButton(store.t("Watch 30-sec tip", "30 सेकंड की टिप देखें", "30 సెకన్ల చిట్కా చూడండి"), icon: .play, kind: .outline, size: .captain) {
                    router.push(.refresher)
                }
            }
        }
    }

    func dot(_ icon: WIcon, _ bg: Color, _ fg: Color, _ title: String, _ sub: String) -> some View {
        VStack(spacing: 6) {
            WIconView(icon: icon, size: 18, color: fg).frame(width: 52, height: 52).background(bg, in: Circle())
            Text(title).wText(.label, color: WColor.heading)
            Text(sub).wText(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: W45 Refresher video

struct RefresherScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: 0) {
            WHeader(title: store.t("New tip", "नई टिप", "కొత్త చిట్కా"), back: false, help: false)
        } content: {
            ZStack {
                WColor.camera
                Image(systemName: "play.fill").font(.system(size: 26)).foregroundStyle(.white)
                    .frame(width: 72, height: 72).background(.white.opacity(0.18), in: Circle())
            }
            .frame(height: 202)
            VStack(alignment: .leading, spacing: 8) {
                Text(store.t("Mirrors and number plate", "शीशे और नंबर प्लेट", "అద్దాలు, నంబర్ ప్లేట్")).wTitle()
                Text(store.t("30 seconds. Watch it fully to get jobs again.", "30 सेकंड। पूरा देखें, फिर काम मिलेंगे।", "30 సెకన్లు. పూర్తిగా చూస్తే మళ్ళీ పనులు వస్తాయి.")).wBodyBig()
                HStack(spacing: 10) {
                    WIconView(icon: .lock, size: 15, color: WColor.waitText)
                    Text(store.t("New jobs are paused until you watch.", "देखने तक नए काम रुके हैं।", "చూసే వరకు కొత్త పనులు ఆగాయి.")).wText(.caption, color: WColor.waitText, size: 14.5)
                    Spacer()
                }
                .padding(14).background(WColor.waitTint, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 8)
            }
            .padding(16)
        } footer: {
            WFooter {
                WButton(store.t("Play", "चलाएं", "ప్లే చేయండి"), icon: .play, size: .captain) { router.replace([.video(2)]) }
            }
        }
    }
}

// MARK: W46 Blocked

struct BlockedScreen: View {
    @Environment(CaptainStore.self) var store
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) { EmptyView() } content: {
            VStack(spacing: 14) {
                Spacer()
                WStateCircle(icon: .ban, tone: .error, size: 112)
                Text(store.t("You can’t take jobs now", "अभी आप काम नहीं ले सकते", "ఇప్పుడు మీరు పనులు తీసుకోలేరు")).wText(.section, weight: .semibold, size: 23)
                Text(store.t("Too many low ratings in the last 2 weeks. If you think this is wrong, ask us to check again.",
                             "पिछले 2 हफ़्तों में बहुत कम रेटिंग। अगर यह गलत है, तो हमसे फिर जाँचने को कहें।",
                             "గత 2 వారాల్లో చాలా తక్కువ రేటింగ్‌లు. ఇది తప్పు అనుకుంటే మళ్ళీ తనిఖీ చేయమని అడగండి."))
                    .wBodyBig().multilineTextAlignment(.center)
                WButton(store.t("Ask to check again", "फिर से जाँच का अनुरोध", "మళ్ళీ తనిఖీ చేయమని అడగండి"), icon: .mic, kind: .outline, size: .captain) {}
                    .padding(.top, 6)
                Text(store.t("Your pending money (₹464) will still be paid.", "आपके बाकी पैसे (₹464) फिर भी मिलेंगे।", "మీ బాకీ డబ్బు (₹464) చెల్లిస్తాము.")).wText(.caption)
                Spacer()
            }
        }
    }
}

// MARK: W47 Me

struct MeTab: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if store.registered { profileHeader } else { guestHeader }
                if store.registered && !store.signedUp {
                    Button { store.kycFromJob = false; router.push(.steps(problem: false)) } label: {
                        HStack(spacing: 14) {
                            WIconBox(icon: .idCard, size: 44, tone: .wait, radius: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t("Finish KYC", "KYC पूरा करें", "KYC పూర్తి చేయండి")).wText(.title, size: 17)
                                Text("\(store.kycStagesDone)/4 · " + store.t("Needed to take jobs", "काम लेने के लिए ज़रूरी", "పనులు తీసుకోవడానికి అవసరం")).wText(.caption)
                            }
                            Spacer()
                            WIconView(icon: .chevron, size: 13, color: WColor.secondary)
                        }
                        .wCard(padding: 14)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 0) {
                    WListRow(icon: .languages, title: store.t("Language", "भाषा", "భాష"), subtitle: store.langName) {
                        let all = Lang.allCases
                        store.lang = all[(all.firstIndex(of: store.lang)! + 1) % all.count]
                    }
                    if store.registered {
                        WDivider(inset: 54)
                        WListRow(icon: .phone, title: store.t("Phone number", "फ़ोन नंबर", "ఫోన్ నంబర్"), subtitle: Fmt.phone(store.phone)) { router.push(.changePhone) }
                        WDivider(inset: 54)
                        WListRow(icon: store.notificationsOn ? .bell : .bellSlash, title: store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు"),
                                 subtitle: !store.notificationsOn ? store.t("Off", "बंद", "ఆఫ్")
                                    : (store.notifPrefs.isMuted() ? store.t("Muted", "म्यूट", "మ్యూట్") : store.t("On", "चालू", "ఆన్"))) { router.push(.notificationSettings) }
                    }
                    if store.signedUp {
                        WDivider(inset: 54)
                        WListRow(icon: .rupee, title: store.t("Payout UPI", "पेमेंट UPI", "చెల్లింపు UPI"), subtitle: store.upi) { router.push(.editUPI) }
                        WDivider(inset: 54)
                        WListRow(icon: .star, title: store.t("My level", "मेरा लेवल", "నా స్థాయి"), subtitle: store.t("Day \(store.levelDay) of 3", "दिन \(store.levelDay) / 3", "రోజు \(store.levelDay) / 3")) { router.push(.level) }
                    }
                    WDivider(inset: 54)
                    WListRow(icon: .play, title: store.t("Training videos", "ट्रेनिंग वीडियो", "శిక్షణ వీడియోలు")) { router.push(.training) }
                    WDivider(inset: 54)
                    WListRow(icon: .sparkle, title: store.t("Why wash with \(Brand.name)", "\(Brand.name) के साथ क्यों", "\(Brand.name) తో ఎందుకు")) { router.push(.welcome) }
                }
                .wCard(padding: 14)
                VStack(spacing: 0) {
                    WListRow(icon: .help, title: store.t("Help", "मदद", "సహాయం")) { router.push(.help) }
                    if store.registered {
                        WDivider(inset: 54)
                        WListRow(icon: .logout, title: store.t("Log out", "लॉग आउट", "లాగ్ అవుట్")) {
                            store.logOut()
                            router.home()
                        }
                    }
                }
                .wCard(padding: 14)
            }
            .padding(.horizontal, WSpace.gutterCaptain)
            .padding(.bottom, 20)
        }
        .background(WColor.canvas)
    }

    var profileHeader: some View {
        HStack(spacing: 14) {
            WProfilePhoto(size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name).wText(.section, weight: .semibold, size: 22)
                Text(store.signedUp ? "\(Fmt.phoneShort(store.phone)) · ★ \(String(format: "%.1f", store.rating))" : Fmt.phoneShort(store.phone)).wText(.caption)
            }
        }
        .padding(.top, 22)
    }

    var guestHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                WIconView(icon: .user, size: 24, color: WColor.secondary)
                    .frame(width: 60, height: 60).background(WColor.primaryTint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t("You’re looking around", "आप ऐप देख रहे हैं", "మీరు యాప్ చూస్తున్నారు")).wText(.section, weight: .semibold, size: 20)
                    Text(store.t("Sign up with your name and number", "नाम और नंबर से साइन अप करें", "పేరు, నంబర్‌తో సైన్ అప్")).wText(.caption)
                }
            }
            WButton(store.t("Sign up", "साइन अप करें", "సైన్ అప్"), size: .captain) { router.push(.signUp(login: false)) }
            WLink(store.t("Already a captain? Log in", "पहले से कैप्टन हैं? लॉग इन करें", "ఇప్పటికే కెప్టెన్‌నా? లాగిన్"), type: .body) {
                router.push(.signUp(login: true))
            }
            .frame(maxWidth: .infinity)
        }
        .wCard(padding: 18)
        .padding(.top, 22)
    }
}

// MARK: W48 Help

struct WHelpScreen: View {
    @Environment(CaptainStore.self) var store
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Help", "मदद", "సహాయం"), help: false)
        } content: {
            Text(store.t("Talk to us", "हमसे बात करें", "మాతో మాట్లాడండి")).wTitle().padding(.top, 10)
            Text("7 AM – 9 PM · Hindi, Telugu, English").wBodyBig().padding(.top, 4).padding(.bottom, 18)
            VStack(spacing: 12) {
                row(.rupee, store.t("Money problem", "पैसे की समस्या", "డబ్బు సమస్య"))
                row(.car, store.t("Problem at a job", "काम पर समस्या", "పనిలో సమస్య"))
            }
            Text(store.t("Emergency", "इमरजेंसी", "అత్యవసరం")).wText(.label).padding(.top, 24).padding(.bottom, 8)
            row(.warning, store.t("Accident, damage or safety", "दुर्घटना, नुकसान या सुरक्षा", "ప్రమాదం, నష్టం లేదా భద్రత"), emergency: true)
            Text(store.t("Emergency line works 24 hours.", "इमरजेंसी लाइन 24 घंटे चालू।", "అత్యవసర లైన్ 24 గంటలు పనిచేస్తుంది."))
                .wText(.caption).padding(.top, 8)
        } footer: {
            WFooter {
                WButton(store.t("Call now", "अभी कॉल करें", "ఇప్పుడే కాల్ చేయండి"), icon: .phone, size: .captain) { Support.call() }
            }
        }
    }

    func row(_ icon: WIcon, _ title: String, emergency: Bool = false) -> some View {
        Button { Support.call() } label: {
            HStack(spacing: 16) {
                WIconBox(icon: icon, size: 52, tone: emergency ? .error : .info, radius: 12)
                Text(title).wText(.value, color: emergency ? WColor.destructive : WColor.heading, size: 18)
                Spacer()
                if emergency { WIconView(icon: .phone, size: 18, color: WColor.destructive) }
            }
            .padding(.horizontal, 16).frame(height: 84)
            .background(emergency ? WColor.errorTint : .white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(emergency ? WColor.destructive.opacity(0.4) : WColor.border))
        }
        .buttonStyle(WPressStyle())
    }
}
