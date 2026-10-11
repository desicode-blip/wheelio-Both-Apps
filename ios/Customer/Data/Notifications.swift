import Foundation
import SwiftUI
import UserNotifications
import AudioToolbox
import UIKit

// MARK: Model

/// What a notification is about. Each kind belongs to a category the customer can switch off
/// (except account and security messages, which always come through).
enum NotificationCategory: String, CaseIterable, Hashable {
    case bookings, payments, offers, account

    var title: String {
        switch self {
        case .bookings: return "Booking updates"
        case .payments: return "Payments and refunds"
        case .offers: return "Offers and tips"
        case .account: return "Account and security"
        }
    }

    var detail: String {
        switch self {
        case .bookings: return "Captain accepted, on the way, photos ready"
        case .payments: return "Refunds and payment problems"
        case .offers: return "Free washes and discounts"
        case .account: return "Sign-ins and number changes. Always on."
        }
    }

    var filterTitle: String {
        switch self {
        case .bookings: return "Bookings"
        case .payments: return "Payments"
        case .offers: return "Offers"
        case .account: return "Account"
        }
    }
}

enum NotificationKind: String, Hashable, CaseIterable {
    case bookingConfirmed, gatePassNeeded, captainAssigned, captainRunningLate, captainCantFind
    case washStarted, photosReady, approveReminder, autoApproved, noCaptain, bookingCancelled
    case washStatusCheck, noShowRefund
    case disputeDecision, refundCredited, paymentPending, freeWash, offer, phoneChanged, welcome

    var category: NotificationCategory {
        switch self {
        case .refundCredited, .paymentPending: return .payments
        case .freeWash, .offer: return .offers
        case .phoneChanged, .welcome: return .account
        default: return .bookings
        }
    }

    var icon: WIcon {
        switch self {
        case .bookingConfirmed: return .check
        case .gatePassNeeded: return .door
        case .captainAssigned: return .location
        case .captainRunningLate: return .clock
        case .captainCantFind: return .warning
        case .washStarted: return .drop
        case .photosReady: return .camera
        case .approveReminder: return .clock
        case .autoApproved: return .sparkle
        case .noCaptain, .bookingCancelled: return .close
        case .washStatusCheck: return .search
        case .noShowRefund: return .rupee
        case .disputeDecision: return .flag
        case .refundCredited: return .rupee
        case .paymentPending: return .warning
        case .freeWash: return .gift
        case .offer: return .megaphone
        case .phoneChanged: return .lock
        case .welcome: return .bell
        }
    }

    var tone: WTone {
        switch self {
        case .captainCantFind, .paymentPending, .phoneChanged: return .error
        case .captainRunningLate, .approveReminder, .gatePassNeeded, .washStatusCheck: return .wait
        case .noShowRefund: return .ok
        case .photosReady, .autoApproved, .refundCredited, .freeWash, .bookingConfirmed: return .ok
        default: return .info
        }
    }

    /// Order states this notification still makes sense in. When the order has moved on,
    /// opening it shows the latest state instead, with a short note.
    var liveStatuses: [OrderStatus]? {
        switch self {
        case .bookingConfirmed: return [.searching]
        case .captainAssigned, .captainRunningLate, .captainCantFind, .washStatusCheck: return [.onTheWay]
        case .washStarted: return [.washing]
        case .photosReady, .approveReminder: return [.photosReady]
        default: return nil
        }
    }
}

struct AppNotification: Identifiable, Hashable {
    let id: String
    let kind: NotificationKind
    let title: String
    let body: String
    let date: Date
    var orderId: String? = nil
    /// Offers only: after this the offer can't be used.
    var expiresAt: Date? = nil
    var read = false
}

enum AlertStyle: String, CaseIterable, Hashable {
    case soundAndBanner, bannerOnly

    var title: String {
        switch self {
        case .soundAndBanner: return "Sound and banner"
        case .bannerOnly: return "Banner only, no sound"
        }
    }
}

struct NotificationPrefs: Hashable {
    var style: AlertStyle = .soundAndBanner
    /// Temporary mute: no banners or sounds until this time. Updates still land in the list.
    var mutedUntil: Date? = nil
    var categories: Set<NotificationCategory> = Set(NotificationCategory.allCases)
    /// 10 PM – 7 AM: banners arrive silently.
    var quietHours = false

    func isMuted(now: Date = Date()) -> Bool { (mutedUntil ?? .distantPast) > now }

    static func inQuietHours(_ now: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: now)
        return h >= 22 || h < 7
    }
}

/// iPhone-level permission for notifications.
enum SystemPermission { case unknown, allowed, denied }

// MARK: Store

extension AppStore {
    var unreadCount: Int { notifications.filter { !$0.read }.count }
    var notificationsOn: Bool { customer?.notificationsOn ?? false }

    /// Adds a notification to the list and, if the settings allow, shows it as a banner
    /// (in the app) or a system notification (when the app is in the background).
    func notify(_ kind: NotificationKind, title: String, body: String, orderId: String? = nil,
                expiresAt: Date? = nil, date: Date = Date(), deliver: Bool = true) {
        guard customer != nil else { return }
        // Same update for the same order within a minute: keep one.
        if let last = notifications.first(where: { $0.kind == kind && $0.orderId == orderId }),
           date.timeIntervalSince(last.date) < 60, date >= last.date { return }
        let n = AppNotification(id: UUID().uuidString, kind: kind, title: title, body: body, date: date,
                                orderId: orderId, expiresAt: expiresAt)
        notifications.insert(n, at: 0)
        notifications.sort { $0.date > $1.date }
        if deliver { present(n) }
    }

    /// Decide how (or whether) a new notification interrupts the customer.
    private func present(_ n: AppNotification) {
        guard notificationsOn,
              n.kind.category == .account || notificationPrefs.categories.contains(n.kind.category),
              !notificationPrefs.isMuted() else { return }
        let silent = notificationPrefs.style == .bannerOnly || (notificationPrefs.quietHours && NotificationPrefs.inQuietHours())
        if appIsActive {
            // Already looking at this booking: the screen updates itself, no banner needed.
            if viewingOrderId != nil && viewingOrderId == n.orderId { return }
            withAnimation(.spring(duration: 0.35)) { liveBanner = n }
            if !silent { AudioServicesPlaySystemSound(1007) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if systemPermission != .denied {
            let c = UNMutableNotificationContent()
            c.title = n.title
            c.body = n.body
            c.sound = silent ? nil : .default
            c.userInfo = ["id": n.id]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: n.id, content: c, trigger: nil))
        }
    }

    func markRead(_ id: String) {
        if let i = notifications.firstIndex(where: { $0.id == id }) { notifications[i].read = true }
    }

    func markUnread(_ id: String) {
        if let i = notifications.firstIndex(where: { $0.id == id }) { notifications[i].read = false }
    }

    func markAllRead() { for i in notifications.indices { notifications[i].read = true } }

    func deleteNotification(_ id: String) { notifications.removeAll { $0.id == id } }

    func clearNotifications() { notifications.removeAll() }

    /// Master switch. Turning on asks iPhone for permission the first time.
    func setNotifications(_ on: Bool) {
        customer?.notificationsOn = on
        if on { requestSystemPermission() }
    }

    func requestSystemPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in self.systemPermission = granted ? .allowed : .denied }
        }
    }

    func refreshSystemPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let p: SystemPermission
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: p = .allowed
            case .denied: p = .denied
            default: p = .unknown
            }
            Task { @MainActor in self.systemPermission = p }
        }
    }

    func mute(for interval: TimeInterval?) {
        notificationPrefs.mutedUntil = interval.map { Date().addingTimeInterval($0) }
    }

    /// Mute until 8 AM tomorrow.
    func muteUntilMorning() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        notificationPrefs.mutedUntil = cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)
    }

    /// Emits notifications for meaningful changes to an order (called from `update`).
    func notifyChanges(from old: Order, to o: Order) {
        let name = o.captain?.name ?? "Your captain"
        let price = Fmt.rupees(o.price)
        if old.status != o.status {
            switch o.status {
            case .searching:
                notify(.bookingConfirmed, title: "Booking confirmed",
                       body: "\(o.vehicle.plate) · \(o.slot.full). We’re finding a captain.", orderId: o.id)
                if !o.entryPassReceived {
                    notify(.gatePassNeeded, title: "Share your gate pass",
                           body: "Reply on WhatsApp with your MyGate or society pass so the captain can get in.", orderId: o.id,
                           date: Date().addingTimeInterval(1))
                }
            case .onTheWay:
                notify(.captainAssigned, title: "\(name) is on the way",
                       body: "Arriving by \(Fmt.time(o.arrivesBy ?? Date())) for \(o.vehicle.plate).", orderId: o.id)
            case .washing:
                notify(.washStarted, title: "Washing has started",
                       body: "\(name) started at \(Fmt.time(o.startedAt ?? Date())). Photos when he’s done.", orderId: o.id)
            case .photosReady:
                notify(.photosReady, title: "Check the wash",
                       body: "Photos are ready. Approve to release \(price) to \(name), or tell us if something’s wrong.", orderId: o.id)
            case .autoApproved:
                notify(.autoApproved, title: "Wash approved automatically",
                       body: "\(price) went to \(name). You can still report a problem until midnight tomorrow.", orderId: o.id)
            case .noCaptain:
                notify(.noCaptain, title: "No captain could take your wash",
                       body: o.refund?.awaitingUPI == true
                        ? "We’ve cancelled it. Tell us your UPI ID and we’ll send your \(price) back."
                        : "We’ve cancelled it. Your \(price) is on its way to \(o.refund?.upi ?? "your UPI").", orderId: o.id)
            case .captainNoShow:
                notify(.noShowRefund, title: "Full refund for your missed wash",
                       body: o.refund?.awaitingUPI == true
                        ? "\(name) didn’t turn up. Add your UPI ID and \(price) reaches you by 11:59 PM."
                        : "\(name) didn’t turn up. \(price) goes to \(o.refund?.upi ?? "your UPI") by 11:59 PM. We’ve taken action with the captain.",
                       orderId: o.id)
            case .cancelled:
                notify(.bookingCancelled, title: "Booking cancelled",
                       body: "Your refund of \(Fmt.rupees(o.refund?.amount ?? o.price)) has started.", orderId: o.id)
            case .disputeUpheld, .disputeRejected:
                notify(.disputeDecision, title: "We’ve checked your report",
                       body: "Tap to see the decision for \(o.vehicle.plate).", orderId: o.id)
            case .paymentPending:
                notify(.paymentPending, title: "Payment not confirmed yet",
                       body: "If money left your account, it comes back within 3 days.", orderId: o.id)
            default: break
            }
        }
        if old.runningLateMinutes == nil, let m = o.runningLateMinutes {
            notify(.captainRunningLate, title: "Your wash is running late",
                   body: "\(name) is about \(m) min behind. We’ll keep you posted.", orderId: o.id)
        }
        if !old.noShowChecking && o.noShowChecking {
            notify(.washStatusCheck, title: "We’re checking on your wash",
                   body: "Your slot has ended and \(name) hasn’t updated the wash. We’re checking with him and will update you.",
                   orderId: o.id)
        }
        if !old.captainCantFind && o.captainCantFind {
            notify(.captainCantFind, title: "\(name) can’t find your vehicle",
                   body: "He’s at \(o.place.parkingShort). Tell him where it is.", orderId: o.id)
        }
        if old.refund?.credited != true, o.refund?.credited == true {
            notify(.refundCredited, title: "Refund credited",
                   body: "\(Fmt.rupees(o.refund?.amount ?? o.price)) reached \(o.refund?.method ?? "your UPI").", orderId: o.id)
        }
    }

    /// Sample inbox for the demo customer: one of each kind, including edge cases
    /// (a booking that no longer exists, an expired offer, a step that has moved on).
    func seedSampleNotifications() {
        let now = Date()
        let h: (Double) -> Date = { now.addingTimeInterval(-$0 * 3600) }
        let car = Self.car.plate
        var list: [AppNotification] = [
            AppNotification(id: "n_offer", kind: .offer, title: "Weekend shine, ₹20 off",
                            body: "On wet washes this Saturday and Sunday.", date: h(0.4),
                            expiresAt: now.addingTimeInterval(3 * 24 * 3600)),
            AppNotification(id: "n_free", kind: .freeWash, title: "You’ve got a free wash",
                            body: "Thanks for the report last week. It’s applied at checkout.", date: h(5)),
            AppNotification(id: "n_photos_old", kind: .photosReady, title: "Check the wash",
                            body: "Photos are ready for \(car). Approve to release ₹149 to Raju.", date: h(26), orderId: "ord_past1", read: true),
            AppNotification(id: "n_assigned_old", kind: .captainAssigned, title: "Raju is on the way",
                            body: "Arriving by 8:40 AM for \(car).", date: h(27), orderId: "ord_past1", read: true),
            AppNotification(id: "n_refund", kind: .refundCredited, title: "Refund credited",
                            body: "₹149 reached Google Pay · ananya@okhdfc.", date: h(70), orderId: "ord_past2"),
            AppNotification(id: "n_gone", kind: .bookingConfirmed, title: "Booking confirmed",
                            body: "TS 09 AB 1234 · Mon, 8 – 10 AM.", date: h(140), orderId: "ord_removed", read: true),
            AppNotification(id: "n_offer_old", kind: .offer, title: "Diwali double shine",
                            body: "Two washes for the price of one.", date: h(240),
                            expiresAt: now.addingTimeInterval(-5 * 24 * 3600), read: true),
            AppNotification(id: "n_phone", kind: .phoneChanged, title: "Your phone number was changed",
                            body: "If this wasn’t you, contact us right away.", date: h(300), read: true),
            AppNotification(id: "n_welcome", kind: .welcome, title: "Welcome to \(Brand.name)",
                            body: "Book a wash, see the photos, then pay. That’s it.", date: h(600), read: true),
        ]
        list.sort { $0.date > $1.date }
        notifications = list
    }
}

/// Shared tap behaviour for a notification (list row, banner).
@MainActor
enum NotificationOpener {
    enum Outcome { case opened, info(String) }

    static func open(_ n: AppNotification, store: AppStore, router: Router) -> Outcome {
        store.markRead(n.id)
        withAnimation { store.liveBanner = nil }
        switch n.kind {
        case .offer:
            if let e = n.expiresAt, e < Date() { return .info("This offer has ended.") }
            store.startNewBooking()
            router.push(.vehicleType(large: false))
            return .opened
        case .freeWash:
            if (store.customer?.freeWashes ?? 0) == 0 && !store.orders.isEmpty {
                // Demo customer may not have the credit loaded; still let them book.
            }
            store.startNewBooking()
            router.push(.vehicleType(large: false))
            return .opened
        case .phoneChanged:
            router.popToRoot(); router.tab = 3
            return .opened
        case .welcome:
            return .opened
        default: break
        }
        guard let id = n.orderId, let o = store.order(id) else {
            return .info("This booking isn’t available anymore. It may have been removed.")
        }
        store.currentOrderId = id
        switch n.kind {
        case .noCaptain, .noShowRefund:
            if o.refund?.awaitingUPI == true { router.push(.refundUPI(id)) }
            else if o.refund != nil { router.push(.refund) } else { router.push(.live) }
        case .refundCredited, .bookingCancelled:
            if o.refund != nil { router.push(.refund) } else { router.push(.live) }
        case .disputeDecision:
            router.push(.disputeStatus)
        case .gatePassNeeded:
            if o.entryPassReceived || !o.status.isActive {
                store.toast = "Gate pass already received. Here’s the latest."
                router.push(.live)
            } else {
                router.push(.whatsApp)
            }
        case .paymentPending:
            if o.status == .paymentPending { router.push(.paying(.pending)) }
            else { store.toast = "Good news: the payment went through."; router.push(.live) }
        default:
            if let s = n.kind.liveStatuses, !s.contains(o.status) {
                store.toast = "Things have moved on. Here’s the latest."
            }
            router.push(.live)
        }
        return .opened
    }
}
