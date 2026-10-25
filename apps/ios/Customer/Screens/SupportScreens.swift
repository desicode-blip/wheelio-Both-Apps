import SwiftUI
import PhotosUI

// MARK: Profile photo

/// Tap the profile circle to pick a photo. Long-press to remove it.
struct ProfilePhotoPicker: View {
    @Environment(AppStore.self) var store
    let initials: String
    var size: CGFloat = 56
    @State private var item: PhotosPickerItem? = nil

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                if let d = store.profilePhoto, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: size, height: size).clipShape(Circle())
                } else {
                    WAvatar(initials: initials, size: size)
                }
                WIconView(icon: .camera, size: 10, color: .white)
                    .frame(width: 22, height: 22)
                    .background(WColor.primary, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.profilePhoto == nil ? "Add a profile photo" : "Change profile photo")
        .contextMenu {
            if store.profilePhoto != nil {
                Button("Remove photo", role: .destructive) { store.profilePhoto = nil }
            }
        }
        .onChange(of: item) { _, new in
            guard let new else { return }
            Task { @MainActor in
                if let data = try? await new.loadTransferable(type: Data.self) { store.profilePhoto = data }
                item = nil
            }
        }
    }
}

// MARK: Change phone number

struct ChangePhoneScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    enum Stage { case number, code, done }
    @State private var stage: Stage = .number
    @State private var phone = ""
    @State private var code = ""
    @State private var wrong = false
    @State private var loading = false

    private var current: String { store.customer?.phone ?? "" }
    private var digits: String { String(Validators.digitsOnly(phone).prefix(10)) }
    private var canSend: Bool { Validators.isValidMobile(phone) && digits != current }

    var body: some View {
        WScreen {
            WAppBar(title: "Phone number", trailing: nil, onLeading: { router.pop() })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            switch stage {
            case .number:
                WTitleBlock(title: "Change your number",
                            subtitle: "Now: \(Fmt.phone(current)). We’ll send a code to the new number to check it’s yours.",
                            topPadding: 14)
                WPhoneField(number: $phone)
                if digits == current && !current.isEmpty {
                    Text("That’s your current number.").wText(.caption).padding(.top, 8)
                }
            case .code:
                Text("Enter the code").wText(.screen).padding(.top, 14)
                Text("Sent to \(Fmt.phone(digits)). Your number changes only after this.")
                    .wText(.body).padding(.top, 6).padding(.bottom, 22)
                WOtpField(code: $code, error: wrong, boxSize: 46)
                    .onChange(of: code) { _, new in
                        if wrong && new.count < 6 { wrong = false }
                        if new.count == 6 { verify() }
                    }
                if wrong {
                    Text("That code doesn’t match. Try again.").wText(.caption, color: WColor.destructive).padding(.top, 14)
                }
                Text("Demo code: 123456").wText(.caption, color: WColor.muted).padding(.top, 30)
            case .done:
                WFullState(icon: .check, tone: .ok, title: "Number updated",
                           message: "We’ll use \(Fmt.phone(store.customer?.phone ?? digits)) from now on.",
                           primary: "Done", onPrimary: { router.pop() })
                    .padding(.top, 40)
            }
        } footer: {
            if stage != .done {
                WFooterBar(showCall: false) {
                    if stage == .number {
                        WButton("Send code", enabled: canSend, loading: loading) { send() }
                    } else {
                        WButton("Verify and change", enabled: code.count == 6, loading: loading) { verify() }
                    }
                }
            }
        }
    }

    private func send() {
        guard canSend else { return }
        loading = true
        Task {
            try? await store.requestPhoneChange(digits)
            loading = false
            code = ""; wrong = false
            stage = .code
        }
    }

    private func verify() {
        guard !loading, code.count == 6 else { return }
        loading = true
        Task {
            let ok = (try? await store.confirmPhoneChange(code)) ?? false
            loading = false
            if ok { stage = .done } else { wrong = true }
        }
    }
}

// MARK: Help and support

enum HelpTopic: String, Hashable, CaseIterable {
    case notClean, late, booking, payment, other

    var title: String {
        switch self {
        case .notClean: return "Wash wasn’t done well"
        case .late: return "Captain is late or didn’t come"
        case .booking: return "Change or cancel a booking"
        case .payment: return "Payment or refund"
        case .other: return "Something else"
        }
    }

    var icon: WIcon {
        switch self {
        case .notClean: return .sparkle
        case .late: return .clock
        case .booking: return .calendar
        case .payment: return .rupee
        case .other: return .chat
        }
    }
}

/// C48 Help: pick what's going on. Everything goes to the captain first;
/// only emergencies reach the WashKrew team.
struct HelpScreen: View {
    @Environment(Router.self) var router
    @State private var open: Int? = nil

    let faqs = [
        ("When is my money taken?", "Your bank holds the amount when you book. It goes to the captain only after you approve the after-photos, or automatically at midnight if you don’t respond."),
        ("What if the captain doesn’t come?", "If no captain accepts, or the wash doesn’t start in your window, you get a full refund to your UPI in 2 to 3 working days."),
        ("Can I cancel?", "Yes. Before a captain accepts, you get the full amount back. After that a small trip fee goes to the captain."),
    ]

    var body: some View {
        WScreen {
            WAppBar(title: "Help", trailing: nil, onLeading: { router.pop() }).padding(.horizontal, 14).padding(.top, 4)
        } content: {
            WTitleBlock(title: "How can we help?", subtitle: "Pick what’s going on.", topPadding: 14)
            VStack(spacing: 10) {
                ForEach(HelpTopic.allCases, id: \.self) { t in
                    WSelectionTile(icon: t.icon, title: t.title) { router.push(.helpCaptain(t)) }
                }
                WSelectionTile(icon: .warning, title: "Emergency",
                               subtitle: "Damage, an accident or a safety worry", iconTone: .error) {
                    router.push(.helpEmergency)
                }
            }
            Text("Common questions").wText(.label).padding(.top, 26).padding(.bottom, 4)
            ForEach(Array(faqs.enumerated()), id: \.offset) { i, f in
                Button { withAnimation { open = open == i ? nil : i } } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(f.0).wText(.rowTitle)
                            Spacer()
                            WIconView(icon: .chevron, size: 13, color: WColor.secondary).rotationEffect(.degrees(open == i ? 90 : 0))
                        }
                        if open == i { Text(f.1).wText(.body) }
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                WDivider()
            }
        }
    }
}

/// Sort it out with your latest captain. "Still not sorted?" only leads to us for emergencies.
struct HelpCaptainScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let topic: HelpTopic
    @State private var stillNotSorted = false
    @State private var pinged = false

    var body: some View {
        let o = store.latestCaptainOrder
        let name = o?.captain?.name ?? "your captain"
        WScreen(canvas: true) {
            WAppBar(title: "Help", trailing: nil, onLeading: { router.pop() }).padding(.horizontal, 14).padding(.top, 4)
        } content: {
            if let o, let w = o.captain {
                WTitleBlock(title: "Let’s sort it with \(w.name)",
                            subtitle: "\(topic.title). Your captain can fix most things fastest, often the same day.",
                            topPadding: 14)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        WAvatar(initials: w.initials, size: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).wText(.title, weight: .semibold, size: 17)
                            Text("\(o.vehicle.plate) · \(Fmt.day(o.slot.date))").wText(.caption)
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        WButton("Call \(w.name)", icon: .phone) { Support.call() }
                        WButton("WhatsApp", icon: .whatsapp, kind: .outline) {}
                    }
                }
                .wCard(padding: 16)
                if pinged {
                    WBanner(tone: .ok, icon: .check, text: "We’ve asked \(w.name) to get back to you about this.")
                        .padding(.top, 16)
                }
                if stillNotSorted && !pinged {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Is this an emergency?").wText(.title)
                        Text("Damage to your vehicle, an accident, or a safety worry.").wText(.body)
                        WButton("Yes, it’s an emergency", kind: .danger) { router.push(.helpEmergency) }
                        WButton("No, ask \(w.name) again", kind: .outline) { withAnimation { pinged = true } }
                    }
                    .wCard(padding: 16)
                    .padding(.top, 16)
                }
            } else {
                WTitleBlock(title: "Your captain is your first stop",
                            subtitle: "Once you’ve booked a wash, you can reach your captain here and sort things out directly.",
                            topPadding: 14)
                WButton("Book a wash") {
                    store.startNewBooking()
                    router.replace(with: [.vehicleType(large: false)])
                }
                .padding(.top, 8)
            }
        } footer: {
            if o != nil && !stillNotSorted && !pinged {
                WStackedFooter {
                    WButton("Still not sorted?", kind: .text) { withAnimation { stillNotSorted = true } }
                }
            }
        }
        .accessibilityLabel("Help with \(name)")
    }
}

/// Only emergencies are connected to the WashKrew team.
struct EmergencyHelpScreen: View {
    @Environment(Router.self) var router

    var body: some View {
        WScreen {
            WAppBar(title: "Emergency", trailing: nil, onLeading: { router.pop() }).padding(.horizontal, 14).padding(.top, 4)
        } content: {
            WStateCircle(icon: .warning, tone: .error, size: 64).padding(.top, 20)
            Text("We’re here for emergencies").wText(.screen).padding(.top, 18)
            Text("Damage to your vehicle, an accident, or a safety worry. A real person picks up.")
                .wText(.body).padding(.top, 6)
            Text(Support.hours).wText(.caption).padding(.top, 14)
        } footer: {
            WStackedFooter {
                WButton("Call us now", icon: .phone, kind: .danger) { Support.call() }
                WButton("WhatsApp us", kind: .text) {}
            }
        }
    }
}

// MARK: Refund UPI ID

/// Asked only when a refund needs somewhere to go (automatic cancellations).
/// Saved to the profile for next time; with no order it edits the saved ID.
struct RefundUPIScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let orderId: String?
    @State private var upi = ""
    @State private var showError = false
    @State private var saving = false

    private var order: Order? {
        guard let orderId else { return nil }
        return store.order(orderId == "current" ? (store.currentOrderId ?? "") : orderId)
    }
    private var valid: Bool { Validators.isValidUPI(upi) }

    var body: some View {
        let amount = Fmt.rupees(order?.refund?.amount ?? order?.price ?? 0)
        WScreen {
            WAppBar(title: order == nil ? "Refund UPI ID" : "Your refund", trailing: nil, onLeading: { router.pop() })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            if order != nil {
                WTitleBlock(title: "Where should we send your \(amount)?",
                            subtitle: "Refunds go to UPI only for now. Type the UPI ID you use in Google Pay, PhonePe or Paytm.",
                            topPadding: 14)
            } else {
                WTitleBlock(title: "Refund UPI ID",
                            subtitle: "If we ever need to refund you, the money goes here.",
                            topPadding: 14)
            }
            WTextField(label: "UPI ID", text: $upi, placeholder: "name@okhdfc",
                       helper: "Looks like name@bank or 9876543210@ybl",
                       error: showError && !valid ? "That doesn’t look like a UPI ID. Check for the @ part." : nil,
                       keyboard: .emailAddress, capitalization: .never, focusOnAppear: true, onSubmit: save)
                .onChange(of: upi) { _, _ in showError = false }
            HStack(alignment: .top, spacing: 10) {
                WIconView(icon: .shield, size: 14, color: WColor.secondary)
                Text("We save it to your profile so you don’t have to type it again. You can change it anytime in Profile.")
                    .wText(.caption)
            }
            .padding(.top, 18)
        } footer: {
            WFooterBar(showCall: false) {
                WButton(order != nil ? "Send \(amount) here" : "Save", enabled: !upi.isEmpty, loading: saving) { save() }
            }
        }
        .onAppear { if upi.isEmpty { upi = store.customer?.refundUPI ?? "" } }
    }

    private func save() {
        guard valid else { showError = true; return }
        saving = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            store.saveRefundUPI(upi)
            saving = false
            if let o = order {
                store.currentOrderId = o.id
                store.toast = "Refund on its way to \(store.customer?.refundUPI ?? upi)"
                router.pop()
                router.push(.refund)
            } else {
                store.toast = "UPI ID saved"
                router.pop()
            }
        }
    }
}
