import Foundation
import Observation

/// Captain app language. Captains pick it on the first screen (W01).
enum Lang: String, CaseIterable { case en, hi, te }

struct Job: Identifiable, Hashable {
    let id: String
    let plate: String
    let type: String          // "Hatchback"
    let isBike: Bool
    let pay: Int
    let tower: String
    let floor: String
    let slot: String
    let window: String        // "8–10"
    let time: String          // "8:30" (queue)
    var distance: String = "600 m"
    var status: JobStatus = .next
    var reachBy: String = "8:40 AM"
    var finishBy: String = "8:55 AM"
    var owner: String = "Ananya"
    var society: String = "My Home Avatar"
    var wash: WashType = .wetOutside
    var area: String = "Narsingi"

    /// "Tower 3 · Floor B2 · Slot 41"
    var spot: String {
        [tower, "Floor \(floor)", slot.isEmpty ? nil : "Slot \(slot)"].compactMap { $0 }.joined(separator: " · ")
    }
    /// Full address for the job card.
    var fullAddress: String { "\(spot), \(society), \(area), Hyderabad" }
    /// Distance in km from the "600 m" / "1.2 km" label.
    var km: Double {
        let n = Double(distance.filter { "0123456789.".contains($0) }) ?? 0
        return distance.contains("km") ? n : n / 1000
    }
}

/// Gated societies the captain can choose to work in (sample data).
struct Society: Identifiable, Hashable {
    let name: String
    let area: String
    let km: Double
    var id: String { name }

    static let all: [Society] = [
        Society(name: "My Home Avatar", area: "Narsingi", km: 0.6),
        Society(name: "Lanco Hills", area: "Manikonda", km: 2.1),
        Society(name: "Aparna Sarovar Zenith", area: "Nallagandla", km: 3.2),
        Society(name: "Prestige High Fields", area: "Gachibowli", km: 4.5),
        Society(name: "SMR Vinay Iconia", area: "Kondapur", km: 6.8),
    ]
    /// Demo: where the captain's phone is right now.
    static let current = all[0]
    static let places = ["Narsingi", "Manikonda", "Nallagandla", "Gachibowli", "Kondapur", "Kokapet", "Madhapur", "Financial District"]
}

/// What the owner booked (mirrors the customer app's wash choices).
enum WashType: Hashable {
    case dryDusting           // bike/car: dusting with a dry cloth, no water
    case wetOutside           // water wash outside
    case wetOutsideDryInside  // water wash outside + dry clean inside (cars)
    var water: Bool { self != .dryDusting }
    var inside: Bool { self == .wetOutsideDryInside }
}

/// Which jobs the captain wants to be offered.
enum WorkMode: String, CaseIterable { case all, radius, societies, place }

enum JobStatus: Hashable { case now, next, done }

enum KycStep: Int, CaseIterable { case aadhaar, photo, bank, training, quiz }
enum StepState { case todo, done, problem }

/// Captain app state with sample data from the designs (Raju, TS 09 EA 4521).
/// BACKEND: when Supabase is connected these methods call the captain API
/// (backend/API-CONTRACT.md); screens don't change.
@MainActor
@Observable
final class CaptainStore {
    var lang: Lang = .en
    var phone = "9876543210"
    var name = "Raju Yadav"
    var firstName: String { String(name.split(separator: " ").first ?? "Raju") }
    var upi = "raju.yadav@ybl"
    var rating = 4.8
    /// KYC done and approved: can accept jobs.
    var signedUp = false
    /// Past the welcome page: browsing the app as a guest.
    var exploring = false
    /// Name and number verified with a code (light sign-up).
    var registered = false
    /// Go online right after the light sign-up finishes.
    var onlineAfterSignUp = false
    /// KYC was started by tapping Accept on a job.
    var kycFromJob = false
    /// The "save your spot" nudge was shown once.
    var nudgeShown = false

    /// Where the captain is: browsing, signed up (no KYC yet), or ready to take jobs.
    var canGoOnline: Bool { registered }
    var canAccept: Bool { signedUp }

    /// Light sign-up finished (name + number + code).
    func finishRegistration() {
        registered = true
        exploring = true
        if notifications.isEmpty { seedNotifications() }
        if onlineAfterSignUp { online = true }
        onlineAfterSignUp = false
        toast = t("Welcome, \(firstName)!", "स्वागत है, \(firstName)!", "స్వాగతం, \(firstName)!")
    }

    /// KYC approved: jobs can be accepted now.
    func finishKyc() {
        signedUp = true
        registered = true
        exploring = true
        kycFromJob = false
        levelDay = 1
        jobsToday = 0
        jobLimit = 2
        earnedToday = 0
        approvedToday = 0
        waitingToday = 0
    }

    func logOut() {
        signedUp = false
        registered = false
        exploring = false
        online = false
        notifications = []
    }

    var steps: [KycStep: StepState] = [:]
    var videosWatched = 1

    var online = false
    var levelDay = 2
    var jobsToday = 6
    var jobLimit = 8
    var earnedToday = 1040
    var approvedToday = 820
    var waitingToday = 220

    // Demo switches (Screens gallery)
    var lowSignal = false
    var batchedAlert = false
    var lateWash = false
    var darkPhoto = false
    var aiFlag = true

    // Profile
    var profilePhoto: Data? = nil
    var pendingPhone = ""
    var pendingUPI = ""

    // Notifications (WNotifications.swift)
    var notifications: [WNotif] = []
    var notificationsOn = true
    var notifPrefs = WNotifPrefs()
    var systemPermission: WSystemPermission = .unknown
    var liveBanner: WNotif? = nil
    var toast: String? = nil
    var appIsActive = true

    // No-show (accepted but didn't reach / update the job)
    var noShowDemo = false
    var jobLate = false
    var slotEnded = false
    var noShowCancelled = false
    var noShowPlate = ""
    var noShowTask: Task<Void, Never>? = nil

    var queue: [Job] = CaptainStore.sampleQueue
    var current: Job { queue.first { $0.status == .now } ?? CaptainStore.sampleQueue[0] }

    /// Photos taken for the current job (before / after), 4 sides each.
    var beforeDone: Set<Int> = []
    var afterDone: Set<Int> = []

    static let sides = ["Front", "Back", "Left", "Right"]

    /// Other jobs that can ring while an alert is already open (demo).
    static let offerPool: [Job] = [
        Job(id: "o1", plate: "TS 08 HK 1207", type: "Hatchback", isBike: false, pay: 116, tower: "Tower 3", floor: "B2", slot: "27", window: "8–10", time: "8:40", owner: "Ravi"),
        Job(id: "o2", plate: "TS 07 FK 3390", type: "SUV", isBike: false, pay: 140, tower: "Tower 2", floor: "Open", slot: "12", window: "8–10", time: "8:45", distance: "2.1 km", owner: "Kiran", society: "Lanco Hills", wash: .wetOutsideDryInside, area: "Manikonda"),
        Job(id: "o3", plate: "TS 10 MB 6614", type: "Scooter", isBike: true, pay: 54, tower: "Tower 5", floor: "B1", slot: "", window: "8–10", time: "9:10", distance: "3.2 km", owner: "Sneha", society: "Aparna Sarovar Zenith", wash: .dryDusting, area: "Nallagandla"),
    ]

    // Where I work (Me → Where I work, and from the job alert)
    var workMode: WorkMode = .all
    var radiusKm = 3
    var chosenSocieties: Set<String> = []
    var workPlace = "Narsingi"

    func wantsJob(_ j: Job) -> Bool {
        switch workMode {
        case .all: return true
        case .radius: return j.km <= Double(radiusKm)
        case .societies: return chosenSocieties.isEmpty || chosenSocieties.contains(j.society)
        case .place: return j.area == workPlace
        }
    }

    var workSummary: String {
        switch workMode {
        case .all: return t("All jobs", "सभी काम", "అన్ని పనులు")
        case .radius: return t("Within \(radiusKm) km", "\(radiusKm) km के अंदर", "\(radiusKm) కి.మీ లోపు")
        case .societies:
            let list = Society.all.map(\.name).filter { chosenSocieties.contains($0) }
            guard let first = list.first else { return t("All jobs", "सभी काम", "అన్ని పనులు") }
            return list.count > 1 ? "\(first) +\(list.count - 1)" : first
        case .place: return workPlace
        }
    }

    /// How many more jobs ring while the alert is open (demo; 0 = single job).
    var extraOffers = 2
    /// Set when the captain taps edit next to the number on the code screen.
    var editPhoneRequested = false

    // MARK: Plan clock (demo)
    /// BACKEND: use the real clock. For the demo the day starts at 9:29:20 AM, so the current job
    /// is ~30 min from the end of its window and the next job's window opens in ~40 s.
    let planRealStart = Date()
    var planSkip: TimeInterval = 0
    var planNow: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600 + 29 * 60 + 20)
            .addingTimeInterval(Date().timeIntervalSince(planRealStart) + planSkip)
    }
    /// Plan alerts already sent ("open-j2", "soon-j1", "late-j1").
    var planAlerts: Set<String> = []
    /// The owner's voice note was played for the current job (then a replay pill stays on screen).
    var ownerNoteHeard = false

    /// Accept a job from the alert stack: it joins today's jobs (now if nothing is
    /// in progress, otherwise next in line) and shows on Home.
    func acceptOffer(_ j: Job) {
        guard !queue.contains(where: { $0.id == j.id }) else { return }
        var nj = j
        nj.status = queue.contains(where: { $0.status == .now }) ? .next : .now
        let insertAt = queue.lastIndex(where: { $0.status != .done }).map { $0 + 1 } ?? 0
        queue.insert(nj, at: insertAt)
        acceptedToday += 1
    }
    var acceptedToday = 0
    var upNext: [Job] { queue.filter { $0.status != .done } }

    static let sampleQueue: [Job] = [
        Job(id: "j1", plate: "TS 09 EA 4521", type: "Hatchback", isBike: false, pay: 116, tower: "Tower 3", floor: "B2", slot: "41", window: "8–10", time: "8:30", status: .now),
        Job(id: "j2", plate: "TS 09 HB 0731", type: "Scooter", isBike: true, pay: 54, tower: "Tower 3", floor: "B1", slot: "", window: "9:30–11:30", time: "9:30", status: .next, wash: .wetOutside),
        Job(id: "j3", plate: "TS 08 GK 2210", type: "Sedan", isBike: false, pay: 140, tower: "Tower 1", floor: "B1", slot: "", window: "6–8", time: "7:40", status: .done, society: "Lanco Hills", area: "Manikonda"),
        Job(id: "j4", plate: "AP 28 BQ 9911", type: "Scooter", isBike: true, pay: 54, tower: "Tower 1", floor: "Open", slot: "", window: "6–8", time: "7:05", status: .done, society: "Lanco Hills", wash: .dryDusting, area: "Manikonda"),
    ]

    /// Inline translation: English, Hindi, Telugu.
    func t(_ en: String, _ hi: String, _ te: String) -> String {
        switch lang {
        case .en: return en
        case .hi: return hi
        case .te: return te
        }
    }

    var langName: String {
        switch lang {
        case .hi: return "हिन्दी"
        case .te: return "తెలుగు"
        case .en: return "English"
        }
    }

    var nextStep: KycStep? { KycStep.allCases.first { steps[$0] != .done } }
    var stepsDone: Int { steps.values.filter { $0 == .done }.count }
    /// KYC as the captain sees it: Aadhaar, photo, bank, onboarding (videos + quiz).
    var kycStagesDone: Int {
        [steps[.aadhaar], steps[.photo], steps[.bank]].filter { $0 == .done }.count
            + (steps[.training] == .done && steps[.quiz] == .done ? 1 : 0)
    }

    func complete(_ s: KycStep) { steps[s] = .done }

    func resetJob() {
        beforeDone = []
        afterDone = []
    }

    /// The captain picked a different job to do first: it becomes the current one.
    func startJob(_ id: String) {
        guard let i = queue.firstIndex(where: { $0.id == id }), queue[i].status == .next else { return }
        if let n = queue.firstIndex(where: { $0.status == .now }) { queue[n].status = .next }
        queue[i].status = .now
    }

    func finishJob() {
        ownerNoteHeard = false
        if let i = queue.firstIndex(where: { $0.status == .now }) {
            queue[i].status = .done
            jobsToday += 1
            earnedToday += queue[i].pay
            waitingToday += queue[i].pay
            if let n = queue.firstIndex(where: { $0.status == .next }) { queue[n].status = .now }
        }
        resetJob()
    }

    /// BACKEND: send a code to the new number / verify it.
    func requestPhoneChange(_ p: String) async { try? await Task.sleep(nanoseconds: 700_000_000); pendingPhone = p }
    func confirmPhoneChange(_ code: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard code == "123456" else { return false }
        phone = pendingPhone
        notify(.phoneChanged, deliver: false)
        return true
    }

    /// BACKEND: payout UPI changes need a code to the registered phone first.
    func requestUPIChange(_ u: String) async { try? await Task.sleep(nanoseconds: 700_000_000); pendingUPI = u.lowercased() }
    func confirmUPIChange(_ code: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard code == "123456" else { return false }
        upi = pendingUPI
        notify(.upiChanged, deliver: false)
        return true
    }

    func resetDemo() {
        captainArrived()
        extraOffers = 2
        acceptedToday = 0
        workMode = .all
        chosenSocieties = []
        kycFromJob = false
        onlineAfterSignUp = false
        noShowCancelled = false
        noShowDemo = false
        notificationsOn = true
        liveBanner = nil
        toast = nil
        lowSignal = false
        batchedAlert = false
        lateWash = false
        darkPhoto = false
        aiFlag = true
        queue = Self.sampleQueue
        resetJob()
        online = false
        jobsToday = 6
        jobLimit = 8
        earnedToday = 1040
        waitingToday = 220
        levelDay = 2
    }
}
