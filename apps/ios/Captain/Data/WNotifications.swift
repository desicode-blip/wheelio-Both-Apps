import Foundation
import SwiftUI
import UserNotifications
import AudioToolbox
import UIKit

// MARK: Model

enum WNotifCategory: String, CaseIterable, Hashable {
    case jobs, money, level, account
}

enum WNotifKind: String, CaseIterable, Hashable {
    case newJob, jobTaken, ownerCancelled, gatePassReady, runningLate, slotEnded, noShowPenalty
    case washApproved, problemReported, payoutSent, upiChanged
    case levelUp, probation, blocked, phoneChanged

    var category: WNotifCategory {
        switch self {
        case .washApproved, .problemReported, .payoutSent, .upiChanged: return .money
        case .levelUp, .probation: return .level
        case .blocked, .phoneChanged: return .account
        default: return .jobs
        }
    }

    var icon: WIcon {
        switch self {
        case .newJob: return .bell
        case .jobTaken: return .clock
        case .ownerCancelled: return .close
        case .gatePassReady: return .door
        case .runningLate: return .clock
        case .slotEnded: return .warning
        case .noShowPenalty: return .ban
        case .washApproved: return .check
        case .problemReported: return .lock
        case .payoutSent: return .rupee
        case .upiChanged: return .rupee
        case .levelUp: return .star
        case .probation: return .calendar
        case .blocked: return .ban
        case .phoneChanged: return .lock
        }
    }

    var tone: WTone {
        switch self {
        case .slotEnded, .noShowPenalty, .blocked, .phoneChanged: return .error
        case .runningLate, .problemReported, .probation, .jobTaken: return .wait
        case .washApproved, .payoutSent, .levelUp, .gatePassReady: return .ok
        default: return .info
        }
    }
}

struct WNotif: Identifiable, Hashable {
    let id: String
    let kind: WNotifKind
    let date: Date
    var jobId: String? = nil
    var plate: String = ""
    var amount: Int = 0
    var read = false
}

struct WNotifPrefs: Hashable {
    var soundOn = true
    var mutedUntil: Date? = nil
    var quietHours = false
    var off: Set<WNotifCategory> = []

    func isMuted(now: Date = Date()) -> Bool { (mutedUntil ?? .distantPast) > now }
    static func inQuietHours(_ now: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: now)
        return h >= 22 || h < 7
    }
}

enum WSystemPermission { case unknown, allowed, denied }

// MARK: Copy (English · Hindi · Telugu)

extension CaptainStore {
    func title(_ n: WNotif) -> String {
        let rs = Fmt.rupees(n.amount)
        switch n.kind {
        case .newJob: return t("New job: \(rs)", "नया काम: \(rs)", "కొత్త పని: \(rs)")
        case .jobTaken: return t("Job went to someone else", "काम किसी और को मिल गया", "పని వేరొకరికి వెళ్ళింది")
        case .ownerCancelled: return t("Owner cancelled the job", "मालिक ने काम रद्द किया", "యజమాని పని రద్దు చేశారు")
        case .gatePassReady: return t("Gate pass is ready", "गेट पास तैयार है", "గేట్ పాస్ సిద్ధం")
        case .runningLate: return t("You’re late for \(n.plate)", "आप \(n.plate) के लिए लेट हैं", "\(n.plate) కి మీరు ఆలస్యం")
        case .slotEnded: return t("Slot is over. Update the job", "समय खत्म। काम अपडेट करें", "సమయం ముగిసింది. పని అప్‌డేట్ చేయండి")
        case .noShowPenalty: return t("Job cancelled: penalty applied", "काम रद्द: जुर्माना लगा", "పని రద్దు: జరిమానా విధించబడింది")
        case .washApproved: return t("Owner approved your wash", "मालिक ने धुलाई मंज़ूर की", "యజమాని మీ వాష్ ఆమోదించారు")
        case .problemReported: return t("Money on hold: \(rs)", "पैसे रोके गए: \(rs)", "డబ్బు నిలిపివేయబడింది: \(rs)")
        case .payoutSent: return t("\(rs) sent to your UPI", "\(rs) आपके UPI पर भेजे गए", "\(rs) మీ UPI కి పంపబడింది")
        case .upiChanged: return t("Payout UPI changed", "पेमेंट UPI बदला गया", "చెల్లింపు UPI మార్చబడింది")
        case .levelUp: return t("Day 2 done. Now 4 jobs a day", "दिन 2 पूरा। अब रोज़ 4 काम", "రోజు 2 పూర్తి. ఇప్పుడు రోజుకు 4 పనులు")
        case .probation: return t("1 more day at 4 jobs", "4 कामों पर 1 दिन और", "4 పనులతో ఇంకో రోజు")
        case .blocked: return t("You can’t take jobs now", "आप अभी काम नहीं ले सकते", "మీరు ఇప్పుడు పనులు తీసుకోలేరు")
        case .phoneChanged: return t("Your phone number was changed", "आपका फ़ोन नंबर बदला गया", "మీ ఫోన్ నంబర్ మార్చబడింది")
        }
    }

    func body(_ n: WNotif) -> String {
        let rs = Fmt.rupees(n.amount)
        switch n.kind {
        case .newJob: return "\(n.plate) · " + t("Tap to see", "देखने के लिए दबाएं", "చూడటానికి నొక్కండి")
        case .jobTaken: return t("Keep the app open. Next job comes soon.", "ऐप खुला रखें। अगला काम जल्दी आएगा।", "యాప్ తెరిచి ఉంచండి. తదుపరి పని త్వరలో వస్తుంది.")
        case .ownerCancelled: return t("You get ₹[CANCELLATION FEE] for the trip.", "सफ़र के ₹[CANCELLATION FEE] मिलेंगे।", "ప్రయాణానికి ₹[CANCELLATION FEE] వస్తుంది.")
        case .gatePassReady: return t("Show it at the gate for \(n.plate).", "\(n.plate) के लिए गेट पर दिखाएं।", "\(n.plate) కోసం గేట్ వద్ద చూపించండి.")
        case .runningLate: return t("Reach now. −₹1 for every late minute.", "अभी पहुँचें। हर लेट मिनट पर −₹1।", "ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1.")
        case .slotEnded: return t("Tap I’m at the car, or call support. Otherwise the job is cancelled.",
                                  "‘मैं गाड़ी के पास हूँ’ दबाएं या सपोर्ट को कॉल करें। नहीं तो काम रद्द होगा।",
                                  "‘నేను కారు దగ్గర ఉన్నాను’ నొక్కండి లేదా సపోర్ట్‌కి కాల్ చేయండి. లేదంటే పని రద్దవుతుంది.")
        case .noShowPenalty: return t("You didn’t reach \(n.plate) in time. Owner got a full refund.",
                                      "आप \(n.plate) तक समय पर नहीं पहुँचे। मालिक को पूरे पैसे वापस मिले।",
                                      "మీరు \(n.plate) కి సమయానికి చేరుకోలేదు. యజమానికి పూర్తి డబ్బు తిరిగి వచ్చింది.")
        case .washApproved: return t("\(rs) comes tonight before 12.", "\(rs) आज रात 12 से पहले आएंगे।", "\(rs) ఈ రాత్రి 12 లోపు వస్తుంది.")
        case .problemReported: return t("Owner reported a problem. We decide in 24 hours.", "मालिक ने समस्या बताई। 24 घंटे में फ़ैसला होगा।", "యజమాని సమస్య చెప్పారు. 24 గంటల్లో నిర్ణయం.")
        case .payoutSent: return t("For 9 jobs on Fri, 9 Oct.", "शुक्र, 9 अक्टू के 9 कामों के लिए।", "శుక్ర, 9 అక్టో 9 పనులకు.")
        case .upiChanged: return t("Money now goes to \(upi).", "अब पैसे \(upi) पर जाएंगे।", "ఇకపై డబ్బు \(upi) కి వెళ్తుంది.")
        case .levelUp: return t("Keep ratings at 4★ or more.", "रेटिंग 4★ या ज़्यादा रखें।", "రేటింగ్ 4★ లేదా ఎక్కువ ఉంచండి.")
        case .probation: return t("An owner gave 3★. Watch the 30-sec tip.", "एक मालिक ने 3★ दिए। 30 सेकंड की टिप देखें।", "ఒక యజమాని 3★ ఇచ్చారు. 30 సెకన్ల టిప్ చూడండి.")
        case .blocked: return t("Too many low ratings. You can ask us to check.", "बहुत सी कम रेटिंग। हमसे जाँच करवा सकते हैं।", "చాలా తక్కువ రేటింగ్‌లు. మమ్మల్ని తనిఖీ చేయమని అడగవచ్చు.")
        case .phoneChanged: return t("If this wasn’t you, call support now.", "अगर यह आपने नहीं किया, तो अभी सपोर्ट को कॉल करें।", "ఇది మీరు కాకపోతే, ఇప్పుడే సపోర్ట్‌కి కాల్ చేయండి.")
        }
    }

    func categoryTitle(_ c: WNotifCategory) -> String {
        switch c {
        case .jobs: return t("Jobs", "काम", "పనులు")
        case .money: return t("Money", "पैसे", "డబ్బు")
        case .level: return t("Level", "लेवल", "స్థాయి")
        case .account: return t("Account", "अकाउंट", "ఖాతా")
        }
    }

    func categoryDetail(_ c: WNotifCategory) -> String {
        switch c {
        case .jobs: return t("New jobs, gate pass, cancellations", "नए काम, गेट पास, रद्द काम", "కొత్త పనులు, గేట్ పాస్, రద్దులు")
        case .money: return t("Approvals, payouts, money on hold", "मंज़ूरी, पेमेंट, रोके गए पैसे", "ఆమోదాలు, చెల్లింపులు, నిలిపివేసిన డబ్బు")
        case .level: return t("Your level and job limit", "आपका लेवल और काम की सीमा", "మీ స్థాయి మరియు పనుల పరిమితి")
        case .account: return t("Blocks and number changes. Always on.", "ब्लॉक और नंबर बदलना। हमेशा चालू।", "బ్లాక్ మరియు నంబర్ మార్పులు. ఎప్పుడూ ఆన్.")
        }
    }
}

// MARK: Store actions

extension CaptainStore {
    var unreadCount: Int { notifications.filter { !$0.read }.count }

    /// Records a notification and, if settings allow, alerts the captain.
    /// New-job alerts always ring while Online (going Offline is how to stop them).
    func notify(_ kind: WNotifKind, job: Job? = nil, amount: Int? = nil, deliver: Bool = true) {
        let jobId = job?.id
        if let last = notifications.first(where: { $0.kind == kind && $0.jobId == jobId }),
           Date().timeIntervalSince(last.date) < 60 { return }
        let n = WNotif(id: UUID().uuidString, kind: kind, date: Date(), jobId: jobId,
                       plate: job?.plate ?? "", amount: amount ?? job?.pay ?? 0)
        notifications.insert(n, at: 0)
        guard deliver else { return }
        let ringsAnyway = kind == .newJob && online
        guard notificationsOn || ringsAnyway else { return }
        guard ringsAnyway || kind.category == .account || !notifPrefs.off.contains(kind.category) else { return }
        guard ringsAnyway || !notifPrefs.isMuted() else { return }
        let silent = !ringsAnyway && (!notifPrefs.soundOn || (notifPrefs.quietHours && WNotifPrefs.inQuietHours()))
        if appIsActive {
            withAnimation(.spring(duration: 0.35)) { liveBanner = n }
            if !silent { AudioServicesPlaySystemSound(1007) }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else if systemPermission != .denied {
            let c = UNMutableNotificationContent()
            c.title = title(n)
            c.body = body(n)
            c.sound = silent ? nil : .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: n.id, content: c, trigger: nil))
        }
    }

    func markRead(_ id: String) { if let i = notifications.firstIndex(where: { $0.id == id }) { notifications[i].read = true } }
    func markUnread(_ id: String) { if let i = notifications.firstIndex(where: { $0.id == id }) { notifications[i].read = false } }
    func markAllRead() { for i in notifications.indices { notifications[i].read = true } }

    func setNotifications(_ on: Bool) {
        notificationsOn = on
        if on {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                Task { @MainActor in self.systemPermission = ok ? .allowed : .denied }
            }
        }
    }

    func refreshSystemPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let p: WSystemPermission = s.authorizationStatus == .denied ? .denied
                : (s.authorizationStatus == .notDetermined ? .unknown : .allowed)
            Task { @MainActor in self.systemPermission = p }
        }
    }

    func mute(for seconds: TimeInterval?) { notifPrefs.mutedUntil = seconds.map { Date().addingTimeInterval($0) } }
    func muteUntilMorning() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        notifPrefs.mutedUntil = cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)
    }

    func seedNotifications() {
        let now = Date()
        let h: (Double) -> Date = { now.addingTimeInterval(-$0 * 3600) }
        let j = Self.sampleQueue[0]
        notifications = [
            WNotif(id: "w_gate", kind: .gatePassReady, date: h(0.2), jobId: j.id, plate: j.plate),
            WNotif(id: "w_approved", kind: .washApproved, date: h(1.5), jobId: "j3", plate: "TS 08 GK 2210", amount: 140),
            WNotif(id: "w_held", kind: .problemReported, date: h(3), jobId: "j_old", plate: "TS 09 EA 4521", amount: 116),
            WNotif(id: "w_oldjob", kind: .newJob, date: h(5), jobId: "j_gone", plate: "TS 07 CC 1188", amount: 116, read: true),
            WNotif(id: "w_payout", kind: .payoutSent, date: h(17), amount: 1262),
            WNotif(id: "w_level", kind: .levelUp, date: h(20), read: true),
            WNotif(id: "w_phone", kind: .phoneChanged, date: h(60), read: true),
        ]
    }

    // MARK: No-show (captain accepted but doesn't reach / update the job)

    /// Demo: late → slot over, update the job → job cancelled + penalty. Stops if the captain
    /// taps "I'm at the car" in time.
    func startNoShowDemo(onCancelled: @escaping @MainActor () -> Void) {
        guard noShowTask == nil, !noShowCancelled else { return }
        let job = current
        noShowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            jobLate = true
            notify(.runningLate, job: job)
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            slotEnded = true
            notify(.slotEnded, job: job)
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            guard !Task.isCancelled else { return }
            noShowCancelled = true
            noShowPlate = job.plate
            queue.removeAll { $0.id == job.id }
            if let n = queue.firstIndex(where: { $0.status == .next }) { queue[n].status = .now }
            notify(.noShowPenalty, job: job)
            noShowTask = nil
            onCancelled()
        }
    }

    /// The captain reached the car in time: no penalty.
    func captainArrived() {
        noShowTask?.cancel()
        noShowTask = nil
        jobLate = false
        slotEnded = false
    }
}

/// Where a tapped notification goes, with the "moved on" / "gone" edge cases.
@MainActor
enum WNotifOpener {
    static func open(_ n: WNotif, store: CaptainStore, router: WRouter) -> String? {
        store.markRead(n.id)
        withAnimation { store.liveBanner = nil }
        let isCurrent = n.jobId != nil && store.queue.contains { $0.id == n.jobId && $0.status == .now }
        switch n.kind {
        case .newJob:
            guard store.online, store.queue.contains(where: { $0.id == n.jobId && $0.status != .done }) else {
                return store.t("This job is no longer available.", "यह काम अब उपलब्ध नहीं है।", "ఈ పని ఇప్పుడు అందుబాటులో లేదు.")
            }
            router.push(.jobAlert(batched: false))
        case .jobTaken:
            return nil
        case .ownerCancelled:
            router.push(.ownerCancelled)
        case .gatePassReady, .runningLate, .slotEnded:
            guard isCurrent, !store.noShowCancelled || n.kind == .gatePassReady else {
                return store.t("This job has moved on.", "यह काम आगे बढ़ चुका है।", "ఈ పని ముందుకు వెళ్ళింది.")
            }
            router.push(.goToVehicle)
        case .noShowPenalty:
            router.push(.noShowCancelled)
        case .washApproved, .payoutSent:
            router.push(.payoutDetail)
        case .problemReported:
            router.push(.payoutHeld)
        case .levelUp:
            router.push(.level)
        case .probation:
            router.push(.probationExtended)
        case .blocked:
            router.push(.blocked)
        case .phoneChanged, .upiChanged:
            router.home(); router.tab = 3
        }
        return nil
    }
}

extension CaptainStore {
    func deleteNotification(_ id: String) { notifications.removeAll { $0.id == id } }
    func clearNotifications() { notifications.removeAll() }
}
