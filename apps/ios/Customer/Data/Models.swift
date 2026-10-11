import Foundation

// Domain models. Field names mirror backend/supabase/migrations so the
// Supabase client can map rows directly when the backend is connected.

enum VehicleKind: String, CaseIterable, Hashable { case bike, hatchback, sedan, suv }

/// Kind of wash, chosen right after the vehicle. Same price for every option.
enum WashKind: String, CaseIterable, Hashable {
    case dryDusting, wetOutside, wetOutsideDryInside

    func name(bike: Bool) -> String {
        switch self {
        case .dryDusting: return bike ? "Dusting" : "Dry wash (dusting)"
        case .wetOutside: return bike ? "Wet wash" : "Wet wash, outside"
        case .wetOutsideDryInside: return "Wet outside + dry clean inside"
        }
    }

    func detail(bike: Bool) -> String {
        switch self {
        case .dryDusting: return "Dust wiped off with a dry cloth. No water."
        case .wetOutside: return bike ? "Water and cloth, then wiped dry." : "Body, glass and wheels. Water and cloth."
        case .wetOutsideDryInside: return "Wet wash outside, seats and mats dusted inside."
        }
    }

    var shortName: String {
        switch self {
        case .dryDusting: return "Dusting"
        case .wetOutside: return "Wet wash"
        case .wetOutsideDryInside: return "Wet + inside"
        }
    }

    var icon: WIcon {
        switch self {
        case .dryDusting: return .wipe
        case .wetOutside: return .drop
        case .wetOutsideDryInside: return .sparkle
        }
    }

    /// Interior cleaning isn't offered in any society yet.
    var available: Bool { self != .wetOutsideDryInside }

    static func options(for kind: VehicleKind?) -> [WashKind] {
        kind == .bike ? [.dryDusting, .wetOutside] : [.dryDusting, .wetOutside, .wetOutsideDryInside]
    }
}

struct VehicleType: Hashable, Identifiable {
    let kind: VehicleKind
    let name: String
    let minutes: Int
    let price: Int
    var id: VehicleKind { kind }

    var shortName: String {
        switch kind {
        case .bike: return "Scooter"
        case .hatchback: return "Hatchback"
        case .sedan: return "Sedan"
        case .suv: return "SUV"
        }
    }

    var icon: WIcon {
        switch kind {
        case .bike: return .bike
        case .suv: return .suv
        default: return .car
        }
    }

    static let all: [VehicleType] = [
        VehicleType(kind: .bike, name: "Bike or scooter", minutes: 15, price: 69),
        VehicleType(kind: .hatchback, name: "Hatchback", minutes: 20, price: 149),
        VehicleType(kind: .sedan, name: "Sedan or compact SUV", minutes: 20, price: 179),
        VehicleType(kind: .suv, name: "SUV or MUV", minutes: 25, price: 219),
    ]
}

struct Society: Hashable, Identifiable {
    let id: String
    let name: String
    let area: String
    let city: String
    var pincode: String = ""
}

/// Where the vehicle is parked (roadmap F04).
struct Place: Hashable {
    var society: Society
    var tower: String = ""
    /// Mandatory before booking (B3, B2, B1, Ground, Open).
    var floor: String? = nil
    var slot: String = ""

    var title: String { tower.isEmpty ? society.name : "\(society.name), \(tower)" }
    var addressLine: String { "\(society.area), \(society.city)\(society.pincode.isEmpty ? "" : " \(society.pincode)")" }

    /// "B2, slot 41"
    var parkingShort: String {
        let f = floor ?? ""
        if slot.isEmpty { return f }
        return f.isEmpty ? "slot \(slot)" : "\(f), slot \(slot)"
    }
}

struct Vehicle: Hashable, Identifiable {
    let id: String
    let plate: String
    let type: VehicleType
    var place: Place?
}

/// Customer's identification photos (roadmap F02). Not wash evidence.
enum PhotoAngle: String, CaseIterable, Hashable {
    case front, back, left, right
    var label: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .left: return "Left side"
        case .right: return "Right side"
        }
    }
}

enum UploadState { case uploading, done, failed }

/// Note for the captain (roadmap F05): text, voice or video.
struct EntryNote: Hashable {
    var text: String = ""
    var voiceSeconds: Int? = nil
    var videoSeconds: Int? = nil

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty && voiceSeconds == nil && videoSeconds == nil }

    var summary: String {
        if let v = voiceSeconds { return "Voice note · \(Fmt.clock(v))" }
        if let v = videoSeconds { return "Video · \(Fmt.clock(v))" }
        let t = text.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "None" : t
    }
}

/// A wash window on a given day (roadmap F07).
struct TimeSlot: Hashable {
    let date: Date
    let startHour: Int
    let endHour: Int
    var available: Bool = true

    var label: String { Fmt.window(startHour, endHour) }
    var dayLabel: String { Fmt.day(date) }
    /// "Today, 8 – 10 AM"
    var full: String { "\(dayLabel), \(label)" }
    var end: Date { Calendar.current.date(bySettingHour: endHour % 24, minute: 0, second: 0, of: date) ?? date }
    var start: Date { Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: date) ?? date }
}

struct Customer: Hashable {
    let id: String
    var phone: String
    var name: String = ""
    var freeWashes: Int = 0
    var notificationsOn: Bool = false
    /// Saved the first time we need to send a refund (UPI only for now). Editable in Profile.
    var refundUPI: String? = nil

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? "" }
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.isEmpty { return "?" }
        if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
        return (String(parts.first!.prefix(1)) + String(parts.last!.prefix(1))).uppercased()
    }
}

struct Captain: Hashable {
    let id: String
    /// First name only is shown to customers.
    let name: String
    let rating: Double
    let washes: Int
    let initials: String
}

/// Order lifecycle (roadmap F11).
enum OrderStatus: Hashable {
    case pendingPayment, paymentPending, searching, onTheWay, washing, photosReady
    case approved, autoApproved, disputed, disputeUpheld, disputeRejected, cancelled, noCaptain
    /// Captain accepted but never turned up or updated the wash: full refund at 11:59 PM, captain penalised.
    case captainNoShow

    var isActive: Bool { [.searching, .onTheWay, .washing, .photosReady].contains(self) }
    var isUpcoming: Bool { isActive || self == .paymentPending }

    /// Index into the 4 customer-visible steps.
    var stepIndex: Int {
        switch self {
        case .searching: return 0
        case .onTheWay: return 1
        case .washing: return 2
        case .photosReady: return 3
        default: return 4
        }
    }
}

struct PaymentMethod: Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
}

enum PaymentOutcome { case success, failed, pending }

struct Refund: Hashable {
    let amount: Int
    var startedAt: Date
    var method: String
    let bankRef: String
    var credited: Bool = false
    /// Automatic cancellations refund to a UPI ID the customer gives us.
    var needsUPI: Bool = false
    var upi: String? = nil
    /// True until the customer has told us where to send the money.
    var awaitingUPI: Bool { needsUPI && upi == nil }
}

enum ProblemKind: CaseIterable, Hashable {
    case notClean, damage, wrongVehicle, noShow

    var title: String {
        switch self {
        case .notClean: return "Not clean enough"
        case .damage: return "Something got damaged"
        case .wrongVehicle: return "Wrong vehicle washed"
        case .noShow: return "Captain didn’t come"
        }
    }

    var subtitle: String {
        switch self {
        case .notClean: return "Spots, dust or streaks left"
        case .damage: return "Scratch, dent or broken part"
        case .wrongVehicle: return "Not my car or bike"
        case .noShow: return "But it says done"
        }
    }

    var icon: WIcon {
        switch self {
        case .notClean: return .drop
        case .damage: return .scratch
        case .wrongVehicle: return .car
        case .noShow: return .close
        }
    }
}

enum DisputeOutcome: Hashable { case underReview, upheld, rejected, damagePriority }

struct Dispute: Hashable {
    let ref: String
    let kind: ProblemKind
    let createdAt: Date
    var note: String = ""
    var outcome: DisputeOutcome = .underReview
    var decisionNote: String = ""
    var creditsAwarded: Int = 0
}

struct Order: Hashable, Identifiable {
    let id: String
    /// Human reference, e.g. WH-20914.
    let ref: String
    let vehicle: Vehicle
    let place: Place
    var slot: TimeSlot
    let price: Int
    var status: OrderStatus
    let createdAt: Date
    var note: EntryNote = EntryNote()
    var captain: Captain? = nil
    var arrivesBy: Date? = nil
    var runningLateMinutes: Int? = nil
    var startedAt: Date? = nil
    var finishedAt: Date? = nil
    var autoApproveAt: Date? = nil
    var entryPassReceived: Bool = false
    var captainCantFind: Bool = false
    var rating: Int? = nil
    var paidWith: PaymentMethod? = nil
    var refund: Refund? = nil
    var dispute: Dispute? = nil
    var usedFreeWash: Bool = false
    /// The customer skipped their own photos at booking. Claims are still checked
    /// against the captain's before/after photos, but we don't promise an outcome.
    var customerSkippedPhotos: Bool = false
    /// Slot window passed and the captain hasn't updated the wash: we're checking with him.
    var noShowChecking: Bool = false
    /// Kind of wash booked (nil for older bookings: treated as wet wash).
    var wash: WashKind? = nil

    /// Same vehicle + same place + same wash = one "Book again" entry.
    var placeKey: String { "\(place.society.id)|\(place.tower)|\(place.floor ?? "")|\(place.slot)" }
    var washKind: WashKind { wash ?? .wetOutside }

    /// Report allowed until this time (approval + dispute window).
    var reportUntil: Date? { finishedAt?.addingTimeInterval(26 * 3600) }
    var vehicleLine: String { "\(vehicle.plate) · \(vehicle.type.shortName)" }
}
