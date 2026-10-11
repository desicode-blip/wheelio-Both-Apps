import Foundation
import Observation

/// Captain app language. Captains pick it on the first screen (W01).
enum Lang: String, CaseIterable { case hi, te, en }

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
}

enum JobStatus: Hashable { case now, next, done }

enum KycStep: Int, CaseIterable { case aadhaar, photo, bank, training, quiz }
enum StepState { case todo, done, problem }

/// Captain app state with sample data from the designs (Raju, TS 09 EA 4521).
/// BACKEND: when Supabase is connected these methods call the captain API
/// (backend/API-CONTRACT.md); screens don't change.
@MainActor
@Observable
final class CaptainStore {
    var lang: Lang = .hi
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

    static let sampleQueue: [Job] = [
        Job(id: "j1", plate: "TS 09 EA 4521", type: "Hatchback", isBike: false, pay: 116, tower: "Tower 3", floor: "B2", slot: "41", window: "8–10", time: "8:30", status: .now),
        Job(id: "j2", plate: "TS 09 HB 0731", type: "Scooter", isBike: true, pay: 54, tower: "Tower 3", floor: "B1", slot: "", window: "8–10", time: "9:00", status: .next),
        Job(id: "j3", plate: "TS 08 GK 2210", type: "Sedan", isBike: false, pay: 140, tower: "Tower 1", floor: "B1", slot: "", window: "6–8", time: "7:40", status: .done),
        Job(id: "j4", plate: "AP 28 BQ 9911", type: "Scooter", isBike: true, pay: 54, tower: "Tower 1", floor: "Open", slot: "", window: "6–8", time: "7:05", status: .done),
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

    func finishJob() {
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
