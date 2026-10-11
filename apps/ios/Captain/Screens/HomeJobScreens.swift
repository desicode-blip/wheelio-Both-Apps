import SwiftUI

// MARK: Tabs (Home · Jobs · Money · Me)

struct CaptainTabs: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var showNudge = false

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Group {
                switch router.tab {
                case 1: JobsTab()
                case 2: MoneyTab()
                case 3: MeTab()
                default: CaptainHome()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            WBottomNav(items: [
                WNavItem(id: 0, title: store.t("Home", "होम", "హోమ్"), icon: .home),
                WNavItem(id: 1, title: store.t("Jobs", "काम", "పనులు"), icon: .list),
                WNavItem(id: 2, title: store.t("Money", "पैसे", "డబ్బు"), icon: .rupee),
                WNavItem(id: 3, title: store.t("Me", "मैं", "నేను"), icon: .user),
            ], selection: $router.tab)
        }
        .background(WColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNudge) { SignUpNudgeSheet() }
        .task(id: store.registered) {
            // After a guest has looked around for a while, offer the light sign-up once.
            guard store.exploring, !store.registered, !store.nudgeShown else { return }
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard !Task.isCancelled, !store.registered, !store.nudgeShown, router.path.isEmpty else { return }
            store.nudgeShown = true
            showNudge = true
        }
    }
}

// MARK: W20 offline · W21 online · W24 daily limit · W50 low signal

struct CaptainHome: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var ringTask: Task<Void, Never>? = nil

    var limitReached: Bool { store.jobsToday >= store.jobLimit }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        if store.registered {
                            WProfilePhoto(size: 40, badge: false)
                            Text(store.firstName).wText(.title, size: 18)
                        } else {
                            // Guest: tap to sign up (name, number, code), then back to Home.
                            Button { router.push(.signUp(login: false)) } label: {
                                HStack(spacing: 10) {
                                    WIconView(icon: .user, size: 18, color: WColor.primaryStrong)
                                        .frame(width: 40, height: 40).background(WColor.primaryTint, in: Circle())
                                    Text(store.t("Guest", "मेहमान", "అతిథి")).wText(.title, size: 18)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(store.t("Guest. Tap to sign up", "मेहमान। साइन अप के लिए दबाएं", "అతిథి. సైన్ అప్‌కి నొక్కండి"))
                        }
                        Spacer()
                        Text(store.online ? store.t("Online", "ऑनलाइन", "ఆన్‌లైన్") : store.t("Offline", "ऑफ़लाइन", "ఆఫ్‌లైన్"))
                            .wText(.title, color: store.online ? WColor.heading : WColor.secondary)
                        Toggle("", isOn: Binding(get: { store.online }, set: { setOnline($0) })).labelsHidden().tint(WColor.success)
                            .scaleEffect(1.15)
                            .padding(.trailing, 4)
                        if store.registered { WNotificationBell() }
                    }
                    .padding(.top, 14)
                    if store.lowSignal {
                        alertBox(.battery, .wait, store.t("Battery 12%.", "बैटरी 12%।", "బ్యాటరీ 12%."),
                                 store.t("Plug in soon. Jobs stop at 5%.", "जल्दी चार्ज करें। 5% पर काम रुक जाएगा।", "త్వరగా ఛార్జ్ చేయండి. 5% వద్ద పనులు ఆగుతాయి."))
                        alertBox(.wifiOff, .error, store.t("No internet.", "इंटरनेट नहीं।", "ఇంటర్నెట్ లేదు."),
                                 store.t("2 photos saved on phone. They upload when signal comes back.", "2 फ़ोटो फ़ोन में सेव हैं। सिग्नल आने पर अपलोड होंगी।", "2 ఫోటోలు ఫోన్‌లో ఉన్నాయి. సిగ్నల్ వచ్చాక అప్‌లోడ్ అవుతాయి."))
                    }
                    if store.signedUp {
                        todayCard
                    } else {
                        welcomeBanner
                        if store.registered { kycCard }
                    }
                    if limitReached && store.online && store.signedUp {
                        HStack(alignment: .top, spacing: 12) {
                            WIconView(icon: .calendar, size: 17, color: WColor.heading)
                            (Text(store.t("Day \(store.levelDay) limit done: \(store.jobsToday) of \(store.jobLimit). ", "दिन \(store.levelDay) की सीमा पूरी: \(store.jobsToday)/\(store.jobLimit)। ", "రోజు \(store.levelDay) పరిమితి పూర్తి: \(store.jobsToday)/\(store.jobLimit). ")).bold()
                             + Text(store.t("All good ratings? Tomorrow you get 6 to 8 jobs.", "सब रेटिंग अच्छी? कल 6 से 8 काम मिलेंगे।", "అన్ని రేటింగ్‌లు బాగుంటే రేపు 6 నుండి 8 పనులు.")))
                                .wText(.caption, color: WColor.inverse, size: 14.5)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
                    } else if store.online && !store.lowSignal {
                        VStack(spacing: 10) {
                            SearchPulseW()
                            Text(store.t("Looking for jobs…", "काम ढूँढ रहे हैं…", "పనుల కోసం చూస్తోంది…")).wText(.section, weight: .semibold)
                            Text(store.t("Keep the app open. Phone will ring.", "ऐप खुला रखें। फ़ोन बजेगा।", "యాప్ తెరిచి ఉంచండి. ఫోన్ మోగుతుంది.")).wText(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .wCard(padding: 22)
                    } else if !store.online {
                        VStack(spacing: 8) {
                            WIconView(icon: .power, size: 34, color: WColor.secondary)
                            Text(store.t("You’re offline", "आप ऑफ़लाइन हैं", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు")).wText(.section, weight: .semibold)
                            Text(store.t("Go online to get jobs near you", "पास के काम पाने के लिए ऑनलाइन जाएं", "దగ్గరి పనుల కోసం ఆన్‌లైన్‌కి వెళ్ళండి")).wText(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 34)
                    }
                }
                .padding(.horizontal, WSpace.gutterCaptain)
            }
            if !store.online {
                WFooter {
                    WButton(store.t("Go online", "ऑनलाइन जाएं", "ఆన్‌లైన్‌కి వెళ్ళండి"), icon: .power, size: .captain) { setOnline(true) }
                }
            }
        }
        .background(WColor.canvas)
        .onChange(of: store.online) { _, on in if on { ring() } else { ringTask?.cancel() } }
        .onAppear { if store.online { ring() } }
        .onDisappear { ringTask?.cancel() }
    }

    /// Guests sign up (name, number, code) before going online.
    func setOnline(_ on: Bool) {
        if on && !store.registered {
            store.onlineAfterSignUp = true
            router.push(.signUp(login: false))
        } else {
            store.online = on
        }
    }

    /// Soft welcome for guests and new captains, with a quiet hint of what's possible.
    var welcomeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WIconView(icon: .sparkle, size: 14, color: WColor.primaryStrong)
                Text(store.registered ? store.t("Welcome, \(store.firstName)", "स्वागत है, \(store.firstName)", "స్వాగతం, \(store.firstName)")
                                      : store.t("Welcome to \(Brand.name)", "\(Brand.name) में स्वागत है", "\(Brand.name) కి స్వాగతం"))
                    .wText(.label, color: WColor.primaryStrong)
            }
            (Text(store.t("Captains here earn up to ", "यहाँ कैप्टन महीने में ", "ఇక్కడ కెప్టెన్లు నెలకు "))
             + Text("₹80,000").bold()
             + Text(store.t(" a month.", " तक कमाते हैं।", " వరకు సంపాదిస్తారు.")))
                .wText(.title, color: WColor.heading, weight: .regular, size: 18)
            Text(store.t("Your hours, jobs near home, money every night.", "आपका समय, घर के पास काम, हर रात पैसे।", "మీ సమయం, ఇంటి దగ్గర పని, ప్రతి రాత్రి డబ్బు."))
                .wText(.caption)
        }
        .padding(18).padding(.trailing, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [WColor.primaryTint, Color(hex: 0xFFF6E3)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "figure.arms.open").font(.system(size: 54))
                .foregroundStyle(WColor.primary.opacity(0.14))
                .padding(14)
        }
    }

    var kycCard: some View {
        Button {
            store.kycFromJob = false
            router.push(.steps(problem: false))
        } label: {
            HStack(spacing: 14) {
                WIconBox(icon: .idCard, size: 48, tone: .wait, radius: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.t("Finish KYC to take jobs", "काम लेने के लिए KYC पूरा करें", "పనులకు KYC పూర్తి చేయండి")).wText(.title, size: 17)
                    Text("\(store.kycStagesDone)/4 · " + store.t("Aadhaar, photo, bank, training", "आधार, फ़ोटो, बैंक, ट्रेनिंग", "ఆధార్, ఫోటో, బ్యాంక్, శిక్షణ")).wText(.caption)
                }
                Spacer(minLength: 0)
                WIconView(icon: .chevron, size: 14, color: WColor.secondary)
            }
            .wCard(padding: 16)
        }
        .buttonStyle(.plain)
    }

    /// Demo: a job rings a few seconds after going online.
    func ring() {
        ringTask?.cancel()
        guard !limitReached else { return }
        ringTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, store.online, router.path.isEmpty, router.tab == 0 else { return }
            store.notify(.newJob, job: store.current, deliver: !store.appIsActive)
            router.push(.jobAlert(batched: store.batchedAlert))
        }
    }

    var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.t("Today", "आज", "ఈరోజు")).wText(.body)
            Text(Fmt.rupees(store.online || store.jobsToday > 0 ? store.earnedToday : 0)).wText(.hugeMoney).wMoney()
            HStack(spacing: 10) {
                stat(.check, .ok, "\(store.jobsToday) " + store.t("of", "/", "/") + " \(store.jobLimit)", store.t("Jobs done", "काम पूरे", "పూర్తైన పనులు"))
                stat(.star, .info, String(format: "%.1f", store.rating), store.t("Rating", "रेटिंग", "రేటింగ్"))
            }
        }
        .wCard(padding: 18)
    }

    func stat(_ icon: WIcon, _ tone: WTone, _ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WIconView(icon: icon, size: 21, color: tone == .ok ? WColor.heading : WColor.primaryStrong)
            Text(big).wText(.section, weight: .semibold)
            Text(small).wText(.caption, color: WColor.heading)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14))
    }

    func alertBox(_ icon: WIcon, _ tone: WTone, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            WIconView(icon: icon, size: 17, color: tone.bannerText)
            (Text(title + " ").bold() + Text(text)).wText(.caption, color: tone.bannerText, size: 14.5)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct SearchPulseW: View {
    @State var on = false
    var body: some View {
        ZStack {
            Circle().fill(WColor.primaryTint).frame(width: 88, height: 88).scaleEffect(on ? 1.1 : 0.92)
            WIconView(icon: .search, size: 32, color: WColor.primaryStrong, weight: .medium)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true } }
    }
}

// MARK: W22 New job alert (W22b batched, W22h Hindi, W22t Telugu)

struct JobAlertScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var batched = false
    @State var left = 10.0

    var body: some View {
        let j = store.current
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(store.t("New job", "नया काम", "కొత్త పని")).wText(.screen, color: .white, size: 23)
                Spacer()
                Text("0:\(String(format: "%02d", Int(left.rounded(.up))))").wText(.screen, color: .white, size: 23).wMoney()
            }
            .padding(.top, 14)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.35))
                    Capsule().fill(.white).frame(width: g.size.width * left / 10)
                }
            }
            .frame(height: 8).padding(.top, 12).padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    WIconBox(icon: j.isBike ? .bike : .car, size: 72, radius: 16, iconSize: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(store.t("Your pay", "आपकी कमाई", "మీ సంపాదన")).wText(.body)
                        Text(Fmt.rupees(j.pay)).wText(.bigMoney).wMoney()
                    }
                }
                HStack(spacing: 8) {
                    fact(.location, j.distance, store.t("away", "दूर", "దూరం"))
                    fact(.layers, j.floor, store.t("Floor", "फ्लोर", "ఫ్లోర్"))
                    fact(.clock, j.window, store.t("Today", "आज", "ఈరోజు"))
                }
                HStack(spacing: 10) {
                    WPlate(text: j.plate)
                    Text("\(j.type) · \(j.tower)").wText(.caption)
                }
                if batched {
                    HStack(alignment: .top, spacing: 10) {
                        WIconView(icon: .list, size: 15, color: WColor.onSuccess)
                        (Text(store.t("Next to your current job. ", "आपके अभी के काम के पास। ", "మీ ప్రస్తుత పని పక్కనే. ")).bold()
                         + Text(store.t("Starts after you finish at 8:55 AM.", "8:55 AM पर ख़त्म होने के बाद शुरू।", "8:55 AM కి పూర్తయ్యాక మొదలు.")))
                            .wText(.caption, color: WColor.onSuccess, size: 14.5)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(WColor.successTint, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            Spacer()
            WButton(store.t("Accept", "स्वीकार करें", "అంగీకరించండి"), icon: .check, kind: .success, size: .accept) {
                if store.signedUp {
                    router.replace([.goToVehicle])
                } else {
                    // First job: a quick KYC before accepting.
                    store.kycFromJob = true
                    router.replace([.steps(problem: false)])
                }
            }
            Button { router.pop() } label: {
                Text(store.t("Skip", "छोड़ें", "వదిలేయండి")).wText(.section, color: .white, weight: .semibold)
                    .frame(maxWidth: .infinity).frame(height: 56)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WSpace.gutterCaptain)
        .background(WColor.primary.ignoresSafeArea())
        .task {
            while left > 0 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                left = max(0, left - 0.1)
            }
            if router.path.last == .jobAlert(batched: batched) {
                store.notify(.jobTaken, job: store.current, deliver: false)
                router.replace([.jobMissed])
            }
        }
    }

    func fact(_ icon: WIcon, _ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WIconView(icon: icon, size: 20, color: WColor.primaryStrong)
            Text(big).wText(.section, weight: .semibold)
            Text(small).wText(.caption, color: WColor.heading)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: W23 Job went to someone else

struct JobMissedScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) { EmptyView() } content: {
            WFullState(icon: .clock, tone: .mute, title: store.t("Job went to someone else", "काम किसी और को मिल गया", "పని వేరొకరికి వెళ్ళింది"),
                       message: store.t("Time ran out. Keep the app open. Next job comes soon.", "समय ख़त्म हो गया। ऐप खुला रखें। अगला काम जल्दी आएगा।", "సమయం ముగిసింది. యాప్ తెరిచి ఉంచండి. త్వరలో పని వస్తుంది."),
                       primary: store.t("Back to home", "होम पर वापस", "హోమ్‌కి తిరిగి"), captain: true, onPrimary: { router.home() })
        }
    }
}

// MARK: W25 Today's jobs

struct JobsTab: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("Today’s jobs", "आज के काम", "ఈరోజు పనులు")).wTitle().padding(.top, 22).padding(.bottom, 4)
                if !store.signedUp {
                    GuestNotice(text: store.t("This is an example day. Your real jobs show here once you start.",
                                              "यह एक उदाहरण दिन है। शुरू करने के बाद आपके असली काम यहाँ दिखेंगे।",
                                              "ఇది ఒక ఉదాహరణ రోజు. మొదలుపెట్టాక మీ నిజమైన పనులు ఇక్కడ కనిపిస్తాయి."))
                }
                ForEach(store.queue) { j in
                    Button {
                        if j.status == .now && store.signedUp { router.push(.goToVehicle) }
                    } label: {
                        HStack(spacing: 14) {
                            Text(j.time).wText(.title, size: 17).wMoney().frame(width: 46, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                WPlate(text: j.plate)
                                Text([j.tower, j.floor, j.slot].filter { !$0.isEmpty }.joined(separator: " · ")).wText(.caption)
                                status(j.status)
                            }
                            Spacer()
                            Text(Fmt.rupees(j.pay)).wText(.section, weight: .semibold).wMoney()
                        }
                        .wCard(padding: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, WSpace.gutterCaptain)
            .padding(.bottom, 20)
        }
        .background(WColor.canvas)
    }

    func status(_ s: JobStatus) -> some View {
        Group {
            switch s {
            case .now: WBadge(text: store.t("Now", "अभी", "ఇప్పుడు"), tone: .info, icon: .drop)
            case .next: WBadge(text: store.t("Next", "अगला", "తదుపరి"), tone: .info, icon: .check)
            case .done: WBadge(text: store.t("Done", "पूरा", "పూర్తి"), tone: .ok, icon: .sparkle)
            }
        }
    }
}

// MARK: W26 Go to vehicle

struct GoToVehicleScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var playing = false

    var body: some View {
        let j = store.current
        WScreen(gutter: WSpace.gutterCaptain) {
            WAppBar(title: store.t("Go to vehicle", "गाड़ी तक जाएं", "వాహనం దగ్గరికి వెళ్ళండి"),
                    subtitle: store.t("Reach by", "पहुँचें", "చేరుకోండి") + " \(j.reachBy)",
                    onLeading: { router.home() }, onTrailing: { router.push(.help) })
                .padding(.horizontal, 4).padding(.top, 4)
        } content: {
            if store.slotEnded {
                WBanner(tone: .error, icon: .warning, title: store.t("Slot is over.", "समय खत्म।", "సమయం ముగిసింది."),
                        text: store.t("Tap I’m at the car now, or call support. Otherwise the job is cancelled and a penalty applies.",
                                      "अभी ‘मैं गाड़ी के पास हूँ’ दबाएं या सपोर्ट को कॉल करें। नहीं तो काम रद्द होगा और जुर्माना लगेगा।",
                                      "ఇప్పుడే ‘నేను కారు దగ్గర ఉన్నాను’ నొక్కండి లేదా సపోర్ట్‌కి కాల్ చేయండి. లేదంటే పని రద్దు, జరిమానా."),
                        actionTitle: store.t("Call support", "सपोर्ट को कॉल करें", "సపోర్ట్‌కి కాల్")) { Support.call() }
                    .padding(.top, 10)
            } else if store.jobLate {
                WBanner(tone: .wait, icon: .clock, title: store.t("You’re late.", "आप लेट हैं।", "మీరు ఆలస్యం."),
                        text: store.t("Reach now. −₹1 for every late minute.", "अभी पहुँचें। हर लेट मिनट पर −₹1।", "ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1."))
                    .padding(.top, 10)
            }
            VStack(alignment: .leading, spacing: 14) {
                WPlate(text: j.plate, large: true)
                HStack(spacing: 8) {
                    place(.building, j.tower, store.t("Building", "बिल्डिंग", "భవనం"))
                    place(.layers, j.floor, store.t("Floor", "फ्लोर", "ఫ్లోర్"))
                    place(.parking, j.slot.isEmpty ? "—" : j.slot, store.t("Slot", "स्लॉट", "స్లాట్"))
                }
            }
            .wCard(padding: 16)
            .padding(.top, 10)
            Button { playing.toggle() } label: {
                HStack(spacing: 14) {
                    WIconView(icon: playing ? .pause : .play, size: 18, color: WColor.primaryStrong)
                        .frame(width: 48, height: 48).background(.white, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t("Owner’s note", "मालिक का संदेश", "యజమాని నోట్")).wText(.title)
                        Text("0:12 · " + store.t("tap to play", "चलाने के लिए टैप करें", "ప్లే చేయడానికి నొక్కండి")).wText(.caption)
                    }
                    Spacer()
                }
                .padding(14).background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            HStack(spacing: 10) {
                Button { router.push(.gateProblem) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        WIconView(icon: .door, size: 22, color: WColor.heading)
                        Text(store.t("Gate pass", "गेट पास", "గేట్ పాస్")).wText(.title)
                        WBadge(text: store.t("Ready", "तैयार", "సిద్ధం"), tone: .ok, icon: .check)
                    }
                    .wOutlined(padding: 14, radius: 16)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 8) {
                    WIconView(icon: .image, size: 22, color: WColor.primaryStrong)
                    Text(store.t("Car photos", "गाड़ी की फ़ोटो", "కారు ఫోటోలు")).wText(.title)
                    Text(store.t("4 photos", "4 फ़ोटो", "4 ఫోటోలు")).wText(.caption)
                }
                .wOutlined(padding: 14, radius: 16)
            }
            .padding(.top, 14)
        } footer: {
            VStack(spacing: 0) {
                WFooter {
                    WButton(store.t("I’m at the car", "मैं गाड़ी के पास हूँ", "నేను కారు దగ్గర ఉన్నాను"), size: .captain) {
                        store.captainArrived()
                        store.resetJob()
                        router.push(.faceCheck)
                    }
                }
                HStack {
                    WLink(store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను"), type: .body) { router.push(.gateProblem) }
                    Spacer()
                    WLink(store.t("Can’t find car", "गाड़ी नहीं मिल रही", "కారు కనబడట్లేదు"), type: .body) { router.push(.cantFind) }
                }
                .padding(.horizontal, WSpace.gutterCaptain).padding(.bottom, 8)
                .background(.white)
            }
        }
        .onAppear { startNoShowIfNeeded() }
    }

    /// Demo: "I don't show up" switch in Screens runs late → slot over → cancelled.
    func startNoShowIfNeeded() {
        guard store.noShowDemo else { return }
        store.startNoShowDemo {
            if router.path.last == .goToVehicle { router.replace([.noShowCancelled]) }
        }
    }

    func place(_ icon: WIcon, _ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WIconView(icon: icon, size: 20, color: WColor.primaryStrong)
            Text(big).wText(.section, weight: .semibold).lineLimit(2).minimumScaleFactor(0.8)
            Text(small).wText(.caption, color: WColor.heading)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: W27 Can't get in

struct GateProblemScreen: View {
    @Environment(CaptainStore.self) var store
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను"))
        } content: {
            VStack(spacing: 12) {
                WStateCircle(icon: .door, tone: .wait, size: 112).padding(.top, 30)
                Text(store.t("Show this at the gate", "यह गेट पर दिखाएं", "ఇది గేట్ వద్ద చూపించండి")).wText(.section, weight: .semibold, size: 23)
                Text(store.t("Owner’s MyGate pass for today.", "आज के लिए मालिक का MyGate पास।", "ఈరోజు కోసం యజమాని MyGate పాస్.")).wBodyBig()
                VStack(spacing: 10) {
                    WIconView(icon: .image, size: 32, color: WColor.secondary)
                    Text("MyGate pass · \(store.current.owner), \(store.current.tower)").wText(.caption)
                }
                .frame(maxWidth: .infinity).frame(height: 196)
                .background(WColor.photo, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WColor.border))
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            WFooter {
                WButton(store.t("Call owner", "मालिक को कॉल करें", "యజమానికి కాల్ చేయండి"), icon: .phone, size: .captain) { Support.call() }
            }
        }
    }
}

// MARK: W28 Can't find car

struct CantFindScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Can’t find car", "गाड़ी नहीं मिल रही", "కారు కనబడట్లేదు"))
        } content: {
            Text(store.t("What do you see?", "आपको क्या दिख रहा है?", "మీకు ఏం కనిపిస్తోంది?")).wTitle().padding(.top, 10).padding(.bottom, 16)
            VStack(spacing: 12) {
                option(.parking, store.t("Slot is empty", "स्लॉट खाली है", "స్లాట్ ఖాళీగా ఉంది"))
                option(.car, store.t("Different car in slot", "स्लॉट में दूसरी गाड़ी है", "స్లాట్‌లో వేరే కారు ఉంది"))
                option(.layers, store.t("Can’t find the floor", "फ्लोर नहीं मिल रहा", "ఫ్లోర్ కనబడట్లేదు"))
            }
            Text(store.t("We tell the owner and wait 10 minutes. You still get ₹[WAIT FEE] if the car isn’t there.",
                         "हम मालिक को बताएंगे और 10 मिनट रुकेंगे। गाड़ी न मिले तो भी आपको ₹[WAIT FEE] मिलेंगे।",
                         "మేము యజమానికి చెప్పి 10 నిమిషాలు ఆగుతాము. కారు లేకపోయినా మీకు ₹[WAIT FEE] వస్తుంది."))
                .wText(.caption).padding(.top, 16)
        } footer: {
            WFooter {
                WButton(store.t("Call owner", "मालिक को कॉल करें", "యజమానికి కాల్ చేయండి"), icon: .phone, size: .captain) { Support.call() }
            }
        }
    }

    func option(_ icon: WIcon, _ title: String) -> some View {
        Button { router.push(.ownerCancelled) } label: {
            HStack(spacing: 16) {
                WIconBox(icon: icon, size: 52, radius: 12)
                Text(title).wText(.value, size: 18)
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 84)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(WColor.border))
        }
        .buttonStyle(WPressStyle())
    }
}

// MARK: W29 Owner cancelled

struct OwnerCancelledScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) { EmptyView() } content: {
            WFullState(icon: .close, tone: .mute, title: store.t("Owner cancelled this job", "मालिक ने यह काम रद्द किया", "యజమాని ఈ పని రద్దు చేశారు"),
                       message: store.t("You were on the way, so you get ₹[CANCELLATION FEE] for the trip.", "आप रास्ते में थे, इसलिए आपको सफ़र के ₹[CANCELLATION FEE] मिलेंगे।", "మీరు దారిలో ఉన్నారు, కాబట్టి ప్రయాణానికి ₹[CANCELLATION FEE] వస్తుంది."),
                       primary: store.t("Back to jobs", "कामों पर वापस", "పనులకు తిరిగి"), captain: true,
                       onPrimary: { router.home(); router.tab = 1 })
        }
        .onAppear { store.notify(.ownerCancelled, job: store.current, deliver: false) }
    }
}
