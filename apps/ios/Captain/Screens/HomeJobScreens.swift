import SwiftUI
import AudioToolbox
import UIKit

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
    var hasPlan: Bool { store.signedUp && !store.queue.isEmpty }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            // Header stays put while the page scrolls.
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    WorkAreaChip().padding(.top, 12)
                    if store.lowSignal {
                        alertBox(.battery, .wait, store.t("Battery 12%.", "बैटरी 12%।", "బ్యాటరీ 12%."),
                                 store.t("Plug in soon. Jobs stop at 5%.", "जल्दी चार्ज करें। 5% पर काम रुक जाएगा।", "త్వరగా ఛార్జ్ చేయండి. 5% వద్ద పనులు ఆగుతాయి."))
                        alertBox(.wifiOff, .error, store.t("No internet.", "इंटरनेट नहीं।", "ఇంటర్నెట్ లేదు."),
                                 store.t("2 photos saved on phone. They upload when signal comes back.", "2 फ़ोटो फ़ोन में सेव हैं। सिग्नल आने पर अपलोड होंगी।", "2 ఫోటోలు ఫోన్‌లో ఉన్నాయి. సిగ్నల్ వచ్చాక అప్‌లోడ్ అవుతాయి."))
                    }
                    if store.signedUp {
                        if store.queue.isEmpty {
                            todayCard
                        } else {
                            // Once jobs come in, money/jobs/rating shrink to one line and
                            // the day's plan takes the space.
                            compactStats
                            DayPlan()
                        }
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
                    } else if !store.online && !hasPlan {
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
            if store.online && !store.lowSignal && !(limitReached && store.signedUp) {
                LiveBanner(text: store.t("Online · Looking for jobs near you", "ऑनलाइन · आपके पास काम ढूँढ रहे हैं", "ఆన్‌లైన్ · మీ దగ్గర పనులు వెతుకుతున్నాం"))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !store.online && !hasPlan {
                WFooter {
                    WButton(store.t("Go online", "ऑनलाइन जाएं", "ఆన్‌లైన్‌కి వెళ్ళండి"), icon: .power, size: .captain) { setOnline(true) }
                }
            }
        }
        .background(WColor.canvas)
        .animation(.easeInOut(duration: 0.3), value: store.online)
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

    var header: some View {
        HStack(spacing: 10) {
            if store.registered {
                WProfilePhoto(size: 40, badge: false)
                Text(store.firstName).wText(.title, size: 18).lineLimit(1).truncationMode(.tail)
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
            OnlineSwitch(online: store.online,
                         label: store.online ? store.t("Online", "ऑनलाइन", "ఆన్‌లైన్") : store.t("Offline", "ऑफ़लाइन", "ఆఫ్‌లైన్")) { setOnline($0) }
            if store.registered { WNotificationBell() }
        }
        .padding(.top, 10).padding(.bottom, 10)
        .padding(.horizontal, WSpace.gutterCaptain)
        .background(WColor.canvas)
        .overlay(alignment: .bottom) { Rectangle().fill(WColor.divider).frame(height: 1) }
    }

    /// Today's money, jobs and rating in one slim row (tap for Money).
    var compactStats: some View {
        Button { router.tab = 2 } label: {
            HStack(spacing: 0) {
                miniStat(.rupee, Fmt.rupees(store.earnedToday), store.t("Today", "आज", "ఈరోజు"))
                Divider().frame(height: 30)
                miniStat(.check, "\(store.jobsToday)/\(store.jobLimit)", store.t("Jobs", "काम", "పనులు"))
                Divider().frame(height: 30)
                miniStat(.star, String(format: "%.1f", store.rating), store.t("Rating", "रेटिंग", "రేటింగ్"))
            }
            .padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(WColor.border))
        }
        .buttonStyle(.plain)
    }

    func miniStat(_ icon: WIcon, _ big: String, _ small: String) -> some View {
        HStack(spacing: 8) {
            WIconView(icon: icon, size: 15, color: WColor.primaryStrong)
            VStack(alignment: .leading, spacing: 0) {
                Text(big).wText(.title, size: 17).wMoney().lineLimit(1).minimumScaleFactor(0.8)
                Text(small).wText(.small, color: WColor.secondary)
            }
        }
        .frame(maxWidth: .infinity)
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
            store.notify(.newJob, job: CaptainStore.offerPool[0], deliver: !store.appIsActive)
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

// MARK: Online / Offline switch with a subtle, always-on animation

/// Online: a green dot sends out a slow ripple ("you're live").
/// Offline: a grey dot gently breathes and the switch glows softly ("tap to go online").
struct OnlineSwitch: View {
    let online: Bool
    let label: String
    let set: (Bool) -> Void
    @State private var phase = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if online {
                    Circle().stroke(WColor.success, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .scaleEffect(phase ? 2.6 : 1)
                        .opacity(phase ? 0 : 0.8)
                }
                Circle().fill(online ? WColor.success : WColor.muted)
                    .frame(width: 10, height: 10)
                    .opacity(online ? 1 : (phase ? 0.35 : 1))
            }
            .frame(width: 14, height: 14)
            Text(label).wText(.title, color: online ? WColor.heading : WColor.secondary)
                .lineLimit(1).fixedSize()
            Toggle("", isOn: Binding(get: { online }, set: set)).labelsHidden().tint(WColor.success)
                .scaleEffect(1.15)
                .shadow(color: online ? WColor.success.opacity(phase ? 0.45 : 0.1) : WColor.primary.opacity(phase ? 0.35 : 0), radius: phase ? 8 : 2)
                .padding(.trailing, 4)
        }
        .fixedSize()
        .layoutPriority(1)
        .id(online) // restart the animation when the state flips
        .onAppear { start() }
        .onChange(of: online) { _, _ in phase = false; start() }
        .accessibilityElement(children: .combine)
    }

    func start() {
        DispatchQueue.main.async {
            withAnimation(online ? .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                                 : .easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { phase = true }
        }
    }
}

// MARK: Today's plan (calendar): one job after another, by time

/// A simple day calendar: time on the left, a line with dots, and each job as a compact card.
/// Every card can be tapped: a done job shows a small summary; any other job opens
/// "Go to vehicle" (the captain may do jobs in any order; the calendar keeps time order).
struct DayPlan: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var doneDetail: Job? = nil

    var jobs: [Job] {
        store.queue.sorted { Self.minutes($0.time) < Self.minutes($1.time) }
    }
    static func minutes(_ t: String) -> Int {
        let p = t.split(separator: ":").compactMap { Int($0) }
        return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0)
    }

    var body: some View {
        let done = store.queue.filter { $0.status == .done }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t("Today’s plan", "आज का प्लान", "ఈరోజు ప్లాన్")).wText(.section, weight: .semibold, size: 21)
                    Text(Fmt.day(Date()) + " · " + store.t("\(done) of \(store.queue.count) done", "\(store.queue.count) में से \(done) पूरे", "\(store.queue.count) లో \(done) పూర్తి"))
                        .wText(.caption)
                }
                Spacer()
                WIconView(icon: .calendar, size: 18, color: WColor.primaryStrong)
                    .frame(width: 36, height: 36).background(WColor.primaryTint, in: Circle())
            }
            VStack(spacing: 0) {
                ForEach(Array(jobs.enumerated()), id: \.element.id) { i, j in
                    row(j, last: i == jobs.count - 1)
                }
            }
        }
        .sheet(item: $doneDetail) { j in DoneJobSheet(job: j) }
    }

    func row(_ j: Job, last: Bool) -> some View {
        let m = Self.minutes(j.time)
        let h = m / 60, mm = m % 60
        let clock = "\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", mm))"
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(clock).wText(.title, color: j.status == .done ? WColor.secondary : WColor.heading, size: 17).wMoney()
                Text(h < 12 ? "AM" : "PM").wText(.small, color: WColor.secondary)
            }
            .frame(width: 46, alignment: .trailing)
            .padding(.top, 12)
            VStack(spacing: 0) {
                dot(j.status).padding(.top, 12)
                if !last {
                    Rectangle().fill(j.status == .done ? WColor.success : WColor.border)
                        .frame(width: 3).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 26)
            card(j).padding(.bottom, last ? 0 : 10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder func dot(_ st: JobStatus) -> some View {
        switch st {
        case .done:
            WIconView(icon: .check, size: 11, color: WColor.onSuccess, weight: .bold)
                .frame(width: 24, height: 24).background(WColor.success, in: Circle())
        case .now:
            Circle().fill(WColor.primary).frame(width: 24, height: 24)
                .overlay(Circle().fill(.white).frame(width: 9, height: 9))
                .overlay(Circle().strokeBorder(WColor.primary.opacity(0.25), lineWidth: 5).frame(width: 34, height: 34))
        case .next:
            Circle().strokeBorder(WColor.muted, lineWidth: 2.5).frame(width: 24, height: 24).background(Circle().fill(.white))
        }
    }

    /// Compact card: society + pay on top, then vehicle, plate and spot. Whole card is tappable.
    func card(_ j: Job) -> some View {
        let now = j.status == .now, done = j.status == .done
        return Button { open(j) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    WIconView(icon: .location, size: 13, color: done ? WColor.muted : WColor.primaryStrong)
                    Text(j.society).wText(.title, color: done ? WColor.secondary : WColor.heading, size: 16).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Fmt.rupees(j.pay)).wText(.title, color: done ? WColor.secondary : WColor.heading, size: 16).wMoney()
                }
                HStack(spacing: 8) {
                    Image(systemName: j.isBike ? "scooter" : "car.side.fill").font(.system(size: 13))
                        .foregroundStyle(done ? WColor.muted : WColor.secondary)
                    Text(j.plate).font(WFont.of(.label, weight: .semibold, size: 13)).tracking(1)
                        .foregroundStyle(done ? WColor.secondary : WColor.heading)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(done ? WColor.border : WColor.heading, lineWidth: 1.2))
                    Text("\(j.tower) · \(j.floor)").wText(.caption, size: 13.5).lineLimit(1)
                    Spacer(minLength: 0)
                    if done {
                        Text(store.t("Done", "पूरा", "పూర్తి")).wText(.small, color: WColor.onSuccess, weight: .semibold)
                    } else {
                        WIconView(icon: .chevron, size: 11, color: now ? WColor.primaryStrong : WColor.muted)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(now ? WColor.primaryTint : (done ? WColor.canvas : .white), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(now ? WColor.primary : WColor.border, lineWidth: now ? 2 : 1))
            .opacity(done ? 0.8 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(WPressStyle())
        .accessibilityHint(done ? "Shows a summary" : "Opens the job")
    }

    func open(_ j: Job) {
        switch j.status {
        case .done: doneDetail = j
        case .now: router.push(.goToVehicle)
        case .next:
            // Captain chose to do this one first: it becomes the current job.
            store.startJob(j.id)
            router.push(.goToVehicle)
        }
    }
}

/// Small pop-up for a finished job.
struct DoneJobSheet: View {
    @Environment(CaptainStore.self) var store
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                WIconView(icon: .check, size: 18, color: WColor.onSuccess, weight: .bold)
                    .frame(width: 44, height: 44).background(WColor.success, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t("Completed", "पूरा हुआ", "పూర్తయింది")).wText(.section, weight: .semibold)
                    Text(job.time + " · " + job.society).wText(.caption)
                }
                Spacer()
                Text(Fmt.rupees(job.pay)).wText(.section, weight: .semibold).wMoney()
            }
            HStack(spacing: 10) {
                WPlate(text: job.plate)
                Text(job.spot).wText(.caption)
            }
            HStack(spacing: 8) {
                WPhotoPlaceholder(icon: job.isBike ? .bike : .car, tag: store.t("Before", "पहले", "ముందు")).frame(height: 76)
                WPhotoPlaceholder(icon: .sparkle, tag: store.t("After", "बाद", "తర్వాత"), tagTone: .ok).frame(height: 76)
            }
            WBadge(text: store.t("Waiting for owner’s OK · paid tonight", "मालिक की मंज़ूरी का इंतज़ार · आज रात भुगतान", "యజమాని ఆమోదం కోసం · ఈ రాత్రి చెల్లింపు"), tone: .wait, icon: .clock)
        }
        .padding(20)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
    }
}

/// Slim, edge-to-edge strip shown only while online: a live green dot and one line.
struct LiveBanner: View {
    let text: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(WColor.success.opacity(0.35)).frame(width: 9, height: 9)
                    .scaleEffect(pulse ? 2.4 : 1).opacity(pulse ? 0 : 1)
                Circle().fill(WColor.success).frame(width: 9, height: 9)
            }
            .frame(width: 16, height: 16)
            Text(text).wText(.label, color: WColor.onSuccess, size: 14).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WSpace.gutterCaptain)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(WColor.successTint)
        .overlay(alignment: .top) { Rectangle().fill(WColor.success.opacity(0.35)).frame(height: 1) }
        .onAppear { withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true } }
        .accessibilityElement(children: .combine)
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

// MARK: W22 New job alert: a stack of offers (W22b batched, W22h Hindi, W22t Telugu, W22m many)

/// Every job that rings gets its own 30-second timer. New jobs arriving while the alert is open
/// slide in behind the top card (with a sound and a buzz). Reject (or swipe left) sends the top
/// card to the back of the stack; Accept adds it to today's jobs on Home and shows the next one.
/// When a timer runs out, that job goes to someone else.
struct JobAlertScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var batched = false

    static let seconds: Double = 30

    struct Offer: Identifiable, Equatable {
        let job: Job
        let arrived: Date
        var id: String { job.id }
        static func == (a: Offer, b: Offer) -> Bool { a.id == b.id }
    }

    @State private var offers: [Offer] = []
    @State private var now = Date()
    @State private var drag: CGFloat = 0
    @State private var newPill = false
    @State private var started = false
    @State private var handled = false
    @State private var acceptedHere = 0
    @State private var flyRight = false

    private func left(_ o: Offer) -> Double { max(0, Self.seconds - now.timeIntervalSince(o.arrived)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let top = offers.first {
                progress(left(top) / Self.seconds).padding(.top, 12).padding(.bottom, 16)
            }
            ZStack(alignment: .top) {
                ForEach(Array(offers.enumerated()).reversed(), id: \.element.id) { i, o in
                    if i < 3 { card(o, index: i) }
                }
                if newPill {
                    Text(store.t("+1 new job", "+1 नया काम", "+1 కొత్త పని"))
                        .wText(.label, color: WColor.primaryStrong)
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                        .offset(y: -16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            if offers.count > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw").font(.system(size: 14))
                    Text(store.t("Swipe left to see the next job", "अगला काम देखने के लिए बाएँ स्वाइप करें", "తదుపరి పని చూడటానికి ఎడమకు స్వైప్ చేయండి"))
                        .wText(.caption, color: .white.opacity(0.9))
                }
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.top, CGFloat(min(offers.count, 3) - 1) * 12 + 18)
            }
            Spacer(minLength: 12)
            if acceptedHere > 0 {
                HStack(spacing: 8) {
                    WIconView(icon: .checkCircle, size: 16, color: .white)
                    Text(store.t("\(acceptedHere) accepted · on your Home", "\(acceptedHere) स्वीकार · होम पर", "\(acceptedHere) అంగీకరించారు · హోమ్‌లో"))
                        .wText(.label, color: .white)
                }
                .frame(maxWidth: .infinity).padding(.bottom, 12)
                .transition(.opacity)
            }
            WorkAreaChip(onDark: true).padding(.bottom, 12)
            // Reject on the left, Accept (primary) on the right.
            HStack(spacing: 12) {
                Button { reject() } label: {
                    HStack(spacing: 8) {
                        WIconView(icon: .close, size: 18, color: .white, weight: .semibold)
                        Text(store.t("Reject", "मना करें", "తిరస్కరించు")).wText(.section, color: .white, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .overlay(RoundedRectangle(cornerRadius: 36).strokeBorder(.white.opacity(0.85), lineWidth: 2))
                    .contentShape(RoundedRectangle(cornerRadius: 36))
                }
                .buttonStyle(WPressStyle())
                .frame(maxWidth: 150)
                .disabled(offers.isEmpty)
                WButton(store.t("Accept", "स्वीकार करें", "అంగీకరించండి"), icon: .check, kind: .success, size: .accept) {
                    if let top = offers.first { accept(top) }
                }
                .disabled(offers.isEmpty)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, WSpace.gutterCaptain)
        .background(WColor.primary.ignoresSafeArea())
        .animation(.spring(duration: 0.4), value: offers)
        .task { await run() }
    }

    var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { leave() } label: {
                WIconView(icon: .close, size: 16, color: .white, weight: .semibold)
                    .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.t("Close", "बंद करें", "మూసివేయండి"))
            Text(offers.count > 1 ? store.t("New jobs", "नए काम", "కొత్త పనులు") : store.t("New job", "नया काम", "కొత్త పని"))
                .wText(.screen, color: .white, size: 23)
            if offers.count > 1 {
                Text("1 / \(offers.count)").wText(.label, color: WColor.primaryStrong)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(.white, in: Capsule())
                    .contentTransition(.numericText())
            }
            Spacer()
            if let top = offers.first {
                Text("0:\(String(format: "%02d", Int(left(top).rounded(.up))))")
                    .wText(.screen, color: .white, size: 23).wMoney()
                    .contentTransition(.numericText())
            }
        }
        .padding(.top, 14)
    }

    func progress(_ f: Double) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35))
                Capsule().fill(f < 0.25 ? Color(hex: 0xFFD27A) : .white).frame(width: g.size.width * f)
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder func card(_ o: Offer, index i: Int) -> some View {
        let j = o.job
        let isTop = i == 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                WIconBox(icon: j.isBike ? .bike : .car, size: 72, radius: 16, iconSize: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.t("Your pay", "आपकी कमाई", "మీ సంపాదన")).wText(.body)
                    Text(Fmt.rupees(j.pay)).wText(.bigMoney).wMoney()
                }
                Spacer(minLength: 0)
                if !isTop {
                    Text("0:\(String(format: "%02d", Int(left(o).rounded(.up))))").wText(.label, color: WColor.secondary).wMoney()
                }
            }
            HStack(spacing: 8) {
                fact(.location, j.distance, store.t("away", "दूर", "దూరం"))
                fact(.layers, j.floor, store.t("Floor", "फ्लोर", "ఫ్లోర్"))
                fact(.clock, j.window, store.t("Today", "आज", "ఈరోజు"))
            }
            // Where the job is: society first, then the full address.
            HStack(alignment: .top, spacing: 10) {
                WIconView(icon: .location, size: 18, color: WColor.primaryStrong).padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(j.society).wText(.title, size: 17.5)
                    Text(j.fullAddress).wText(.caption, size: 14).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(WColor.canvas, in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 10) {
                WPlate(text: j.plate)
                Text(j.type).wText(.caption)
            }
            BookingChip(job: j)
            if batched && isTop && j.id == offers.last?.id && offers.count == 1 {
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
        .shadow(color: .black.opacity(isTop ? 0.12 : 0.06), radius: 12, y: 4)
        // Cards behind peek out below the top one.
        .scaleEffect(1 - CGFloat(i) * 0.05, anchor: .bottom)
        .offset(y: CGFloat(i) * 14)
        .opacity(i == 0 ? 1 : (i == 1 ? 0.85 : 0.6))
        .offset(x: isTop ? drag : 0)
        .rotationEffect(.degrees(isTop ? Double(drag / 22) : 0), anchor: .bottom)
        .overlay(alignment: .topTrailing) {
            if isTop && drag < -30 {
                Text(store.t("LATER", "बाद में", "తర్వాత")).wText(.label, color: WColor.destructive, weight: .bold)
                    .padding(.horizontal, 12).frame(height: 30)
                    .overlay(Capsule().strokeBorder(WColor.destructive, lineWidth: 2))
                    .rotationEffect(.degrees(12))
                    .padding(18)
                    .opacity(min(1, Double(-drag - 30) / 60))
            }
        }
        .gesture(DragGesture(minimumDistance: 12)
            .onChanged { v in if isTop { drag = min(40, v.translation.width) } }
            .onEnded { v in
                guard isTop else { return }
                if v.translation.width < -110 || v.predictedEndTranslation.width < -220 {
                    withAnimation(.easeIn(duration: 0.22)) { drag = -600 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { drag = 0; reject() }
                } else {
                    withAnimation(.spring(duration: 0.3)) { drag = 0 }
                }
            }, including: isTop ? .all : .subviews)
        .transition(.asymmetric(insertion: .offset(y: 60).combined(with: .opacity),
                                removal: flyRight ? .move(edge: .trailing).combined(with: .opacity) : .opacity.combined(with: .scale(scale: 0.9))))
        .zIndex(Double(10 - i))
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: store.t("Reject", "मना करें", "తిరస్కరించు")) { reject() }
    }

    func fact(_ icon: WIcon, _ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WIconView(icon: icon, size: 20, color: WColor.primaryStrong)
            Text(big).wText(.section, weight: .semibold).lineLimit(1).minimumScaleFactor(0.8)
            Text(small).wText(.caption, color: WColor.heading)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Behaviour

    func run() async {
        guard !started else { return }
        started = true
        // Only jobs that match "Where I work".
        let pool0 = CaptainStore.offerPool.filter { store.wantsJob($0) }
        guard let first = pool0.first else {
            handled = true
            store.toast = store.t("No jobs in your area right now", "अभी आपके इलाके में काम नहीं", "ఇప్పుడు మీ ప్రాంతంలో పనులు లేవు")
            router.pop()
            return
        }
        offers = [Offer(job: first, arrived: Date())]
        Nudge.newJob()
        // Demo: more jobs ring while this one is open.
        let arrivals: [Double] = [6, 13]
        var pool = pool0.dropFirst().prefix(store.extraOffers).makeIterator()
        var nextArrival = 0
        let start = Date()
        while !handled {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled || handled { return }
            now = Date()
            if nextArrival < arrivals.count, now.timeIntervalSince(start) >= arrivals[nextArrival] {
                nextArrival += 1
                if let j = pool.next() { arrive(j) }
            }
            // Jobs whose 30 seconds ran out go to someone else.
            for o in offers where left(o) <= 0 { remove(o, skipped: false) }
        }
    }

    func arrive(_ j: Job) {
        offers.append(Offer(job: j, arrived: Date()))
        store.notify(.newJob, job: j, deliver: false)
        Nudge.newJob()
        withAnimation(.spring(duration: 0.3)) { newPill = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { newPill = false } }
    }

    /// Reject: the top card goes to the back of the stack (its timer keeps running).
    /// With only one card left, Reject closes the alert.
    func reject() {
        guard !handled, !offers.isEmpty else { return }
        guard offers.count > 1 else { leave(); return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(duration: 0.4)) { offers.append(offers.removeFirst()) }
    }

    func leave() {
        guard !handled else { return }
        handled = true
        router.home()
    }

    func remove(_ o: Offer, skipped: Bool) {
        guard !handled, offers.contains(o) else { return }
        offers.removeAll { $0 == o }
        if !skipped { store.notify(.jobTaken, job: o.job, deliver: false) }
        guard offers.isEmpty else { return }
        handled = true
        if acceptedHere > 0 || skipped { router.home() } else { router.replace([.jobMissed]) }
    }

    /// Accept: the job moves to Home (today's jobs) and the next offer shows.
    func accept(_ o: Offer) {
        guard !handled else { return }
        guard store.signedUp else {
            // First job: a quick KYC before accepting.
            handled = true
            store.kycFromJob = true
            router.replace([.steps(problem: false)])
            return
        }
        store.acceptOffer(o.job)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        flyRight = true
        withAnimation(.spring(duration: 0.4)) {
            offers.removeAll { $0 == o }
            acceptedHere += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { flyRight = false }
        if offers.isEmpty {
            handled = true
            store.toast = store.t("Added to your jobs", "आपके कामों में जोड़ा गया", "మీ పనుల్లో చేర్చబడింది")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.home() }
        }
    }
}

/// Sound + vibration for a new job, so it's noticed even with the phone in a pocket.
enum Nudge {
    @MainActor static func newJob() {
        AudioServicesPlaySystemSound(1007)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
                                Text(j.society).wText(.title, size: 16)
                                Text(j.spot).wText(.caption)
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
    @State private var showPhotos = false

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
                        text: store.t("Tap I’m at the vehicle now, or tell us in Help. Otherwise the job is cancelled and a penalty applies.",
                                      "अभी ‘मैं गाड़ी के पास हूँ’ दबाएं या मदद में बताएं। नहीं तो काम रद्द होगा और जुर्माना लगेगा।",
                                      "ఇప్పుడే ‘నేను వాహనం దగ్గర ఉన్నాను’ నొక్కండి లేదా సహాయంలో చెప్పండి. లేదంటే పని రద్దు, జరిమానా."),
                        actionTitle: store.t("Get help", "मदद लें", "సహాయం పొందండి")) { router.push(.helpFlow(.job)) }
                    .padding(.top, 10)
            } else if store.jobLate {
                WBanner(tone: .wait, icon: .clock, title: store.t("You’re late.", "आप लेट हैं।", "మీరు ఆలస్యం."),
                        text: store.t("Reach now. −₹1 for every late minute.", "अभी पहुँचें। हर लेट मिनट पर −₹1।", "ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1."))
                    .padding(.top, 10)
            }
            VStack(alignment: .leading, spacing: 14) {
                // Address + plate on the left, the owner's vehicle photo on the right.
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 8) {
                            WIconView(icon: .location, size: 17, color: WColor.primaryStrong).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(j.society).wText(.title, size: 18)
                                Text(j.fullAddress).wText(.caption, size: 13.5).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        WPlate(text: j.plate)
                    }
                    Spacer(minLength: 0)
                    Button { showPhotos = true } label: {
                        VehiclePhotoView(side: 0, isBike: j.isBike, compact: true)
                            .frame(width: 112, height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .bottom) {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 10, weight: .semibold))
                                    Text("4").font(WFont.of(.small, weight: .semibold, size: 11))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).frame(height: 22)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(8)
                            }
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 24, height: 24).background(.black.opacity(0.45), in: Circle())
                                    .padding(6)
                            }
                    }
                    .buttonStyle(WPressStyle())
                    .accessibilityLabel(store.t("Vehicle photos", "गाड़ी की फ़ोटो", "వాహనం ఫోటోలు"))
                }
                BookingChip(job: j)
                HStack(spacing: 8) {
                    place(.building, j.tower, store.t("Building", "बिल्डिंग", "భవనం"))
                    place(.layers, j.floor, store.t("Floor", "फ्लोर", "ఫ్లోర్"))
                    place(.parking, j.slot.isEmpty ? "—" : j.slot, store.t("Slot", "स्लॉट", "స్లాట్"))
                }
            }
            .wCard(padding: 16)
            .padding(.top, 10)
            Button { router.push(.gateProblem) } label: {
                HStack(spacing: 12) {
                    WIconView(icon: .door, size: 22, color: WColor.heading)
                    Text(store.t("Gate pass", "गेट पास", "గేట్ పాస్")).wText(.title)
                    Spacer()
                    WBadge(text: store.t("Ready", "तैयार", "సిద్ధం"), tone: .ok, icon: .check)
                    WIconView(icon: .chevron, size: 12, color: WColor.secondary)
                }
                .wOutlined(padding: 14, radius: 16)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        } footer: {
            VStack(spacing: 0) {
                WFooter {
                    WButton(store.t("I’m at the vehicle", "मैं गाड़ी के पास हूँ", "నేను వాహనం దగ్గర ఉన్నాను"), size: .captain) {
                        store.captainArrived()
                        store.resetJob()
                        store.ownerNoteHeard = false
                        // The owner's voice note plays first (must listen once).
                        router.push(.ownerNote)
                    }
                }
                HStack {
                    WLink(store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను"), type: .body) { router.push(.gateProblem) }
                    Spacer()
                    WLink(store.t("Can’t find vehicle", "गाड़ी नहीं मिल रही", "వాహనం కనబడట్లేదు"), type: .body) { router.push(.cantFind) }
                }
                .padding(.horizontal, WSpace.gutterCaptain).padding(.bottom, 8)
                .background(.white)
            }
        }
        .onAppear { startNoShowIfNeeded() }
        .fullScreenCover(isPresented: $showPhotos) { VehiclePhotosViewer(isBike: j.isBike, plate: j.plate) }
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

// MARK: W28 Can't find vehicle

struct CantFindScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Can’t find vehicle", "गाड़ी नहीं मिल रही", "వాహనం కనబడట్లేదు"))
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
