import Foundation
import Observation

/// Switches that force edge cases so every designed state can be reached
/// without a real backend. Set from the in-app Screens gallery.
struct DemoScenario {
    var payment: PaymentOutcome = .success
    var noCaptainFound = false
    var captainRunsLate = false
    /// Captain accepts but never turns up: late → checking → full refund at 11:59 PM.
    var captainNoShow = false
    var captainCantFind = false
    var entryPassNeverArrives = false
    var noCaptainsToday = false
    var failBackPhotoOnce = false
    var disputeRejected = false
    var offline = false
    var emptyHistory = false
    /// Seconds between live order steps. Short so a demo takes under a minute.
    var stepSeconds: Double = 5
}

/// The booking being built, one small decision per screen
/// (vehicle → plate → photos → place → floor → notes → time → pay).
struct BookingDraft {
    var type: VehicleType? = nil
    var wash: WashKind? = nil
    var plate: String = ""
    var photos: [PhotoAngle: UploadState] = [:]
    var videoSeconds: Int? = nil
    var place: Place? = nil
    var note = EntryNote()
    var slot: TimeSlot? = nil
    var useFreeWash = false
    var isRepeat = false

    var photosDone: Int { photos.values.filter { $0 == .done }.count }
    var photosComplete: Bool { PhotoAngle.allCases.allSatisfy { photos[$0] == .done } }
    var hasFailedPhoto: Bool { photos.values.contains(.failed) }
    var price: Int { useFreeWash ? 0 : (type?.price ?? 0) }
}

/// App state plus an in-memory backend with the sample people and places from
/// the designs (Ananya, Raju, My Home Avatar Tower 3, TS 09 EA 4521).
///
/// Demo login: any valid mobile number, code 123456. Code 000000 = expired.
/// When Supabase is connected, the methods marked BACKEND call the server
/// (see backend/API-CONTRACT.md); screens don't change.
@MainActor
@Observable
final class AppStore {
    static let demoOtp = "123456"
    static let expiredOtp = "000000"
    static let samplePhone = "9848011223"

    // Sample data
    static let societies = [
        Society(id: "soc_avatar", name: "My Home Avatar", area: "Narsingi", city: "Hyderabad", pincode: "500089"),
        Society(id: "soc_avali", name: "My Home Avali", area: "Gachibowli", city: "Hyderabad", pincode: "500032"),
        Society(id: "soc_avishkaar", name: "My Home Avishkaar", area: "Kokapet", city: "Hyderabad", pincode: "500075"),
    ]
    static let raju = Captain(id: "wsh_raju", name: "Raju", rating: 4.8, washes: 212, initials: "RY")
    static let homePlace = Place(society: societies[0], tower: "Tower 3", floor: "B2", slot: "41")
    static let car = Vehicle(id: "veh_car", plate: "TS 09 EA 4521", type: VehicleType.all[1], place: homePlace)
    static let scooter = Vehicle(id: "veh_scooter", plate: "TS 09 HB 0731", type: VehicleType.all[0],
                                 place: Place(society: societies[0], tower: "Tower 3", floor: "B1", slot: ""))
    static let gpay = PaymentMethod(id: "gpay", title: "Google Pay", detail: "ananya@okhdfc")

    var demo = DemoScenario()
    var customer: Customer? = nil
    var vehicles: [Vehicle] = []
    var orders: [Order] = []

    // Notifications (see Notifications.swift)
    var notifications: [AppNotification] = []
    var notificationPrefs = NotificationPrefs()
    var systemPermission: SystemPermission = .unknown
    /// Banner currently shown at the top of the app.
    var liveBanner: AppNotification? = nil
    /// Short note shown at the bottom (e.g. "Things have moved on").
    var toast: String? = nil
    var appIsActive = true
    /// Order whose live screen is open (no banner needed for it).
    var viewingOrderId: String? = nil
    var draft = BookingDraft()
    var currentOrderId: String? = nil
    var pendingPhone = ""
    /// Chosen on the login screen: "I've booked before" (phone + code only) or "I'm new here" (phone + code + name).
    var returningCustomer = false
    var payMethodId = "gpay"
    var hasSeenWelcome = false
    /// Hidden design switch (DesignFlags.firstWashHome); the Screens gallery can turn it on.
    var showFirstWashHome = DesignFlags.firstWashHome

    private var otpTries = 0
    private var refCounter = 20914
    private var backPhotoFailed = false
    private var lifecycleTasks: [String: Task<Void, Never>] = [:]

    init() { seedPastOrders() }

    var isLoggedIn: Bool { customer != nil }
    var currentOrder: Order? { orders.first { $0.id == currentOrderId } }
    var activeOrder: Order? { orders.first { $0.status.isActive } }
    var upcomingOrders: [Order] { demo.emptyHistory ? [] : orders.filter { $0.status.isUpcoming }.sorted { $0.slot.start < $1.slot.start } }
    var pastOrders: [Order] {
        demo.emptyHistory ? [] : orders.filter { !$0.status.isUpcoming && $0.status != .pendingPayment }.sorted { $0.slot.start > $1.slot.start }
    }
    var myVehicles: [Vehicle] { demo.emptyHistory ? [] : vehicles }

    func order(_ id: String) -> Order? { orders.first { $0.id == id } }

    private func update(_ id: String, _ change: (inout Order) -> Void) {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { return }
        let old = orders[i]
        change(&orders[i])
        notifyChanges(from: old, to: orders[i])
    }

    private func nextRef() -> String { defer { refCounter += 1 }; return "WH-\(refCounter)" }

    private func latency(_ ms: UInt64 = 450) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
        if demo.offline { throw AppError.offline }
    }

    private func seedPastOrders() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func past(_ id: String, _ daysAgo: Int, _ v: Vehicle, _ status: OrderStatus, refund: Refund? = nil, rating: Int? = nil,
                  place: Place? = nil, wash: WashKind = .wetOutside) -> Order {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: today)!
            var o = Order(id: id, ref: "WH-\(20871 - daysAgo)", vehicle: v, place: place ?? v.place ?? Self.homePlace,
                         slot: TimeSlot(date: day, startHour: 8, endHour: 10), price: v.type.price, status: status,
                         createdAt: day, captain: status == .cancelled ? nil : Self.raju,
                         startedAt: day.addingTimeInterval(8 * 3600 + 32 * 60), finishedAt: day.addingTimeInterval(8 * 3600 + 54 * 60),
                         entryPassReceived: true, rating: rating, paidWith: Self.gpay, refund: refund)
            o.wash = wash
            return o
        }
        let d2 = cal.date(byAdding: .day, value: -10, to: today)!
        orders = [
            past("ord_past1", 7, Self.car, .approved, rating: 4),
            past("ord_past2", 10, Self.car, .noCaptain,
                 refund: Refund(amount: 149, startedAt: d2, method: "Google Pay · ananya@okhdfc", bankRef: "RZP8812001", credited: true)),
            past("ord_past3", 13, Self.scooter, .cancelled),
            // Same car, booked at another society (parents' place): shows as its own entry, place highlighted.
            past("ord_past4", 16, Self.car, .approved, rating: 5,
                 place: Place(society: Self.societies[1], tower: "Tower 1", floor: "B1", slot: "12")),
            // Same car and place, but a dry wash: its own entry, wash highlighted.
            past("ord_past5", 21, Self.car, .approved, rating: 4, wash: .dryDusting),
        ]
    }

    // MARK: Auth (BACKEND: auth.signInWithOtp / verifyOtp)

    func requestOtp(_ phone: String) async throws {
        try await latency(700)
        pendingPhone = phone
        otpTries = 0
    }

    enum OtpResult { case ok(isNew: Bool), wrong(triesLeft: Int), expired, tooManyTries }

    func verifyOtp(_ code: String) async throws -> OtpResult {
        try await latency(600)
        if code == Self.expiredOtp { return .expired }
        if code != Self.demoOtp {
            otpTries += 1
            let left = 3 - otpTries
            return left <= 0 ? .tooManyTries : .wrong(triesLeft: left)
        }
        // Demo: anyone who says they've booked before is found as the sample customer.
        let known = pendingPhone == Self.samplePhone || returningCustomer
        customer = Customer(id: "cus_\(pendingPhone)", phone: pendingPhone, name: known ? "Ananya Rao" : "", notificationsOn: known)
        if known && vehicles.isEmpty { vehicles = [Self.car, Self.scooter] }
        if known { seedSampleNotifications() } else {
            notifications = []
            notify(.welcome, title: "Welcome to \(Brand.name)", body: "Book a wash, see the photos, then pay. That’s it.", deliver: false)
        }
        return .ok(isNew: !known)
    }

    /// Gallery shortcut: log in as the sample customer.
    func signInAsSample(freeWashes: Int = 0) {
        customer = Customer(id: "cus_ananya", phone: Self.samplePhone, name: "Ananya Rao", freeWashes: freeWashes, notificationsOn: true)
        if vehicles.isEmpty { vehicles = [Self.car, Self.scooter] }
        if notifications.isEmpty { seedSampleNotifications() }
    }

    func signOut() {
        customer = nil
        vehicles = []
        notifications = []
        liveBanner = nil
    }

    func updateName(_ name: String) async throws {
        try await latency()
        customer?.name = name.trimmingCharacters(in: .whitespaces)
    }


    /// Profile photo picked from the library (kept on the phone for now).
    var profilePhoto: Data? = nil

    // MARK: Change phone number (OTP to the new number first)

    var pendingNewPhone = ""

    /// BACKEND: send OTP to the new number.
    func requestPhoneChange(_ phone: String) async throws {
        try await latency(700)
        pendingNewPhone = phone
    }

    /// BACKEND: verify OTP, then update the account's phone.
    func confirmPhoneChange(_ code: String) async throws -> Bool {
        try await latency(600)
        guard code == Self.demoOtp else { return false }
        customer?.phone = pendingNewPhone
        pendingNewPhone = ""
        return true
    }

    /// The captain from the running wash, else from the most recent wash.
    var latestCaptainOrder: Order? {
        if let a = activeOrder, a.captain != nil { return a }
        return pastOrders.first { $0.captain != nil }
    }

    /// Returns false while a wash is in progress.
    func deleteAccount() async throws -> Bool {
        try await latency()
        if orders.contains(where: { $0.status == .washing }) { return false }
        customer = nil
        vehicles = []
        orders = []
        notifications = []
        notificationPrefs = NotificationPrefs()
        return true
    }

    // MARK: Catalogue

    func searchSocieties(_ q: String) -> [Society] {
        let q = q.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return Self.societies }
        return Self.societies.filter { "\($0.name) \($0.area)".lowercased().contains(q) }
    }

    func timeSlots(for day: Date) -> [TimeSlot] {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let hour = cal.component(.hour, from: Date())
        let windows = [(6, 8), (8, 10), (10, 12), (12, 14), (14, 16), (16, 18)]
        return windows.map { s, e in
            // Demo: early windows today look full so the crossed-out state shows.
            let full = isToday && (demo.noCaptainsToday || s == 6 || (hour >= e - 1 && hour < 20))
            return TimeSlot(date: cal.startOfDay(for: day), startHour: s, endHour: e, available: !full)
        }
    }

    var paymentMethods: [PaymentMethod] {
        let upi = customer?.phone == Self.samplePhone ? "UPI · ananya@okhdfc" : "UPI"
        return [
            PaymentMethod(id: "gpay", title: "Google Pay", detail: upi),
            PaymentMethod(id: "phonepe", title: "PhonePe", detail: "UPI"),
            PaymentMethod(id: "upi_id", title: "Other UPI app", detail: "Enter UPI ID"),
            PaymentMethod(id: "card", title: "Card", detail: "Debit or credit"),
        ]
    }

    // MARK: Booking

    /// BACKEND: storage upload. Fails the back photo once when the demo switch is on.
    func uploadPhoto(_ angle: PhotoAngle) async {
        draft.photos[angle] = .uploading
        try? await Task.sleep(nanoseconds: 700_000_000)
        if demo.failBackPhotoOnce && angle == .back && !backPhotoFailed {
            backPhotoFailed = true
            draft.photos[angle] = .failed
        } else {
            draft.photos[angle] = .done
        }
    }

    func startRepeat(_ v: Vehicle, place: Place? = nil, wash: WashKind? = nil) {
        draft = BookingDraft(type: v.type, wash: wash, plate: v.plate, place: place ?? v.place, isRepeat: true)
    }

    func startNewBooking() { draft = BookingDraft() }

    /// BACKEND: rpc create_order, then Razorpay checkout.
    func createOrderAndPay() async throws -> PaymentOutcome {
        guard let type = draft.type, let place = draft.place, let slot = draft.slot else { throw AppError.server }
        try await latency(2200)
        let plate = draft.plate
        let vehicle = vehicles.first { $0.plate == plate } ?? {
            let v = Vehicle(id: "veh_\(UUID().uuidString.prefix(6))", plate: plate, type: type, place: place)
            self.vehicles.append(v)
            return v
        }()
        let method = paymentMethods.first { $0.id == payMethodId } ?? Self.gpay
        let order = Order(id: "ord_\(UUID().uuidString.prefix(8))", ref: nextRef(), vehicle: vehicle, place: place, slot: slot,
                          price: draft.price, status: .pendingPayment, createdAt: Date(), note: draft.note,
                          paidWith: method, usedFreeWash: draft.useFreeWash,
                          customerSkippedPhotos: !draft.photosComplete, wash: draft.wash)
        orders.append(order)
        currentOrderId = order.id
        switch demo.payment {
        case .failed:
            orders.removeAll { $0.id == order.id }
            return .failed
        case .pending:
            update(order.id) { $0.status = .paymentPending }
            return .pending
        case .success:
            if draft.useFreeWash { customer?.freeWashes -= 1 }
            startLifecycle(order.id)
            return .success
        }
    }

    func checkPendingPayment() async throws -> PaymentOutcome {
        try await latency(1200)
        demo.payment = .success
        if let id = currentOrderId { startLifecycle(id) }
        return .success
    }

    private func sleepSteps(_ n: Double) async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(demo.stepSeconds * n * 1_000_000_000))
        return !Task.isCancelled
    }

    private func startLifecycle(_ id: String) {
        update(id) { $0.status = .searching }
        lifecycleTasks[id]?.cancel()
        lifecycleTasks[id] = Task { [weak self] in
            guard let self else { return }
            guard await self.sleepSteps(1) else { return }
            if self.demo.noCaptainFound {
                self.update(id) { o in o.status = .noCaptain; o.refund = self.autoRefund(o) }
                return
            }
            self.update(id) { o in
                o.status = .onTheWay
                o.captain = Self.raju
                o.arrivesBy = max(Date().addingTimeInterval(25 * 60), o.slot.start.addingTimeInterval(40 * 60))
            }
            guard await self.sleepSteps(1) else { return }
            if !self.demo.entryPassNeverArrives { self.update(id) { $0.entryPassReceived = true } }
            if self.demo.captainNoShow {
                // 1. Running late  2. Slot window passed, checking  3. 11:59 PM: full refund, captain penalised.
                self.update(id) { $0.runningLateMinutes = 15 }
                guard await self.sleepSteps(2) else { return }
                self.update(id) { $0.noShowChecking = true }
                guard await self.sleepSteps(2) else { return }
                self.update(id) { o in
                    o.status = .captainNoShow
                    o.refund = self.autoRefund(o)
                }
                return
            }
            if self.demo.captainRunsLate { self.update(id) { $0.runningLateMinutes = 15 } }
            guard await self.sleepSteps(1) else { return }
            if self.demo.captainCantFind {
                // Waits for the customer's answer; see answerCantFind.
                self.update(id) { $0.captainCantFind = true }
                return
            }
            await self.runWash(id)
        }
    }

    private func runWash(_ id: String) async {
        update(id) { o in o.status = .washing; o.startedAt = Date() }
        guard await sleepSteps(2) else { return }
        let done = Date()
        update(id) { o in
            o.status = .photosReady
            o.finishedAt = done
            o.autoApproveAt = BusinessRules.autoApproveTime(after: done)
        }
    }

    func answerCantFind(_ answer: String) {
        guard let id = currentOrderId else { return }
        if answer == "not_here" {
            Task { try? await cancel(id) }
            return
        }
        update(id) { $0.captainCantFind = false }
        lifecycleTasks[id] = Task { [weak self] in
            guard let self, await self.sleepSteps(1) else { return }
            await self.runWash(id)
        }
    }

    /// Refund for an automatic cancellation (no captain / captain no-show). Goes to the
    /// customer's UPI ID; if we don't have one yet, we ask for it.
    func autoRefund(_ o: Order) -> Refund {
        let upi = customer?.refundUPI
        return Refund(amount: o.price, startedAt: Date(), method: upi.map { "UPI · \($0)" } ?? "Waiting for your UPI ID",
                      bankRef: "RZP\(8812000 + Int.random(in: 0...99999))", needsUPI: true, upi: upi)
    }

    /// Saves the refund UPI ID to the profile and sends any refunds that were waiting for it.
    func saveRefundUPI(_ raw: String) {
        let upi = raw.trimmingCharacters(in: .whitespaces).lowercased()
        customer?.refundUPI = upi
        for i in orders.indices where orders[i].refund?.awaitingUPI == true {
            orders[i].refund?.upi = upi
            orders[i].refund?.method = "UPI · \(upi)"
            orders[i].refund?.startedAt = Date()
        }
    }

    private func refundFor(_ o: Order, amount: Int? = nil) -> Refund {
        Refund(amount: amount ?? o.price, startedAt: Date(),
               method: o.paidWith.map { "\($0.title) · \($0.detail.replacingOccurrences(of: "UPI · ", with: ""))" } ?? "UPI",
               bankRef: "RZP\(8812000 + Int.random(in: 0...99999))")
    }

    /// BACKEND: rpc cancel_order. After a captain accepts, [CANCELLATION FEE] applies (not decided, so 0).
    func cancel(_ id: String) async throws {
        try await latency(800)
        lifecycleTasks[id]?.cancel()
        update(id) { o in
            let fee = o.status == .onTheWay ? (BusinessRules.cancellationFee ?? 0) : 0
            o.refund = self.refundFor(o, amount: o.price - fee)
            o.status = .cancelled
            o.captainCantFind = false
        }
    }

    /// BACKEND: rpc approve_order (releases the held money to the captain).
    func approve(_ id: String) async throws {
        try await latency(600)
        lifecycleTasks[id]?.cancel()
        update(id) { $0.status = .approved }
    }

    func forceAutoApprove(_ id: String) { update(id) { $0.status = .autoApproved } }

    func rate(_ id: String, stars: Int, tags: [String]) async throws {
        try await latency(400)
        update(id) { $0.rating = stars }
    }

    /// BACKEND: rpc report_problem.
    func reportProblem(_ id: String, kind: ProblemKind, note: String) async throws {
        try await latency(900)
        lifecycleTasks[id]?.cancel()
        let dispute = Dispute(ref: nextRef(), kind: kind, createdAt: Date(), note: note,
                              outcome: kind == .damage ? .damagePriority : .underReview)
        update(id) { o in o.status = .disputed; o.dispute = dispute }
        guard kind != .damage else { return }
        lifecycleTasks[id] = Task { [weak self] in
            guard let self, await self.sleepSteps(2) else { return }
            if self.demo.disputeRejected {
                self.update(id) { o in
                    o.status = .disputeRejected
                    o.dispute?.outcome = .rejected
                    o.dispute?.decisionNote = "The scratch near the left door is visible in the 8:33 AM before-photo."
                }
            } else {
                self.customer?.freeWashes += 2
                self.update(id) { o in
                    o.status = .disputeUpheld
                    o.refund = self.refundFor(o)
                    o.dispute?.outcome = .upheld
                    o.dispute?.decisionNote = "The after-photos show streaks on the bonnet. Raju won’t be paid for this wash."
                    o.dispute?.creditsAwarded = 2
                }
            }
        }
    }

    // MARK: Gallery helpers

    /// An order in a given state, built from sample data, made current.
    /// Gallery: captain accepted, ran late, slot has passed and we're checking with him.
    func markNoShowChecking() {
        let o = sampleOrder(.onTheWay, late: true)
        if let i = orders.firstIndex(where: { $0.id == o.id }) { orders[i].noShowChecking = true }
    }

    @discardableResult
    func sampleOrder(_ status: OrderStatus, passMissing: Bool = false, late: Bool = false, cantFind: Bool = false,
                     dispute: DisputeOutcome? = nil, damage: Bool = false, skippedPhotos: Bool = false) -> Order {
        let now = Date()
        var o = Order(id: "ord_sample_\(UUID().uuidString.prefix(6))", ref: "WH-20914", vehicle: Self.car, place: Self.homePlace,
                      slot: TimeSlot(date: Calendar.current.startOfDay(for: now), startHour: 8, endHour: 10),
                      price: 149, status: status, createdAt: now, note: EntryNote(voiceSeconds: 12),
                      captain: status == .searching ? nil : Self.raju, arrivesBy: now.addingTimeInterval(25 * 60),
                      runningLateMinutes: late ? 15 : nil, startedAt: now.addingTimeInterval(-22 * 60),
                      finishedAt: now.addingTimeInterval(-60), autoApproveAt: BusinessRules.autoApproveTime(after: now),
                      entryPassReceived: !passMissing, captainCantFind: cantFind, paidWith: Self.gpay,
                      customerSkippedPhotos: skippedPhotos)
        if [.noCaptain, .captainNoShow].contains(status) {
            o.refund = autoRefund(o)
        } else if [.cancelled, .disputeUpheld].contains(status) {
            o.refund = Refund(amount: 149, startedAt: now, method: "Google Pay · ananya@okhdfc", bankRef: "RZP8812093")
        }
        if let dispute {
            o.dispute = Dispute(ref: damage ? "WH-20915" : "WH-20914", kind: damage ? .damage : .notClean, createdAt: now,
                                note: "Water streaks on the bonnet and the left mirror wasn’t wiped.", outcome: dispute,
                                decisionNote: dispute == .upheld ? "The after-photos show streaks on the bonnet. Raju won’t be paid for this wash."
                                    : "The scratch near the left door is visible in the 8:33 AM before-photo.",
                                creditsAwarded: dispute == .upheld ? 2 : 0)
        }
        orders.removeAll { $0.id.hasPrefix("ord_sample_") }
        orders.append(o)
        currentOrderId = o.id
        return o
    }

    func draftBasics() {
        draft = BookingDraft(type: VehicleType.all[1], plate: "TS 09 EA 4521")
    }

    func draftFull() {
        draftBasics()
        for a in PhotoAngle.allCases { draft.photos[a] = .done }
        draft.videoSeconds = 14
        draft.place = Self.homePlace
        draft.note = EntryNote(voiceSeconds: 12)
        draft.slot = TimeSlot(date: Calendar.current.startOfDay(for: Date()), startHour: 8, endHour: 10)
    }

    func resetDemo() {
        showFirstWashHome = DesignFlags.firstWashHome
        for t in lifecycleTasks.values { t.cancel() }
        lifecycleTasks = [:]
        demo = DemoScenario()
        backPhotoFailed = false
        orders.removeAll { $0.id.hasPrefix("ord_sample_") }
    }
}

enum AppError: Error { case offline, server }

/// Business values not decided yet (design read-me "Placeholders").
/// While nil the UI shows the placeholder text from the designs.
enum BusinessRules {
    static let cancellationFee: Int? = nil
    static let waitFee: Int? = nil
    static let approvalHours = 2

    /// Washes auto-approve at 12 midnight on the day they finish (the captain payout run).
    static func autoApproveTime(after finished: Date) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: finished)) ?? finished.addingTimeInterval(2 * 3600)
    }
    static let disputeHours = 24

    static var cancellationFeeText: String { cancellationFee.map(String.init) ?? "[CANCELLATION FEE]" }
    static var refundAmountText: String { "[REFUND AMOUNT]" }
}
