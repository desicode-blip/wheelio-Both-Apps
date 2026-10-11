import SwiftUI

// MARK: Tabs

struct MainTabs: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Group {
                switch router.tab {
                case 1: BookingsTab()
                case 2: VehiclesTab()
                case 3: ProfileTab()
                default: HomeTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            WBottomNav(items: [
                WNavItem(id: 0, title: "Home", icon: .home),
                WNavItem(id: 1, title: "Bookings", icon: .calendar, badge: store.activeOrder == nil ? 0 : 1),
                WNavItem(id: 2, title: "Vehicles", icon: .car),
                WNavItem(id: 3, title: "Profile", icon: .user),
            ], selection: $router.tab)
        }
        .background(WColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: C40 / C41 / C42 Home (C55 loading)

struct HomeTab: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BrandMark()
                    Spacer()
                    NotificationBell()
                }
                .padding(.top, 14)
                if loading {
                    skeleton
                } else {
                    loaded
                }
            }
            .padding(.horizontal, WSpace.gutter)
            .padding(.bottom, 24)
        }
        .background(WColor.canvas)
        .task {
            if loading {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation { loading = false }
            }
        }
    }

    @ViewBuilder var loaded: some View {
        let c = store.customer
        Text(c == nil || c!.firstName.isEmpty ? "Hi there" : "Hi \(c!.firstName)").wText(.screen).padding(.top, 18)
        let hasHistory = !store.pastOrders.isEmpty || store.activeOrder != nil
        if !hasHistory || c == nil {
            Text("Your wheels are waiting.").wText(.body).padding(.top, 4)
            firstWashCard.padding(.top, 24)
            howItWorks.padding(.top, 34)
        } else {
            if (c?.freeWashes ?? 0) > 0 {
                WBanner(tone: .ok, icon: .gift, title: "You have \(c!.freeWashes) free washes.", text: "They’re applied at checkout.",
                        actionTitle: "Use one") { book() }
                    .padding(.top, 20)
            }
            // Booking a wash is always the main action, even while another wash is running.
            VStack(alignment: .leading, spacing: 16) {
                Text("Book a wash").wText(.section, weight: .semibold)
                WButton("Book a wash") { book() }
            }
            .wCard(padding: 20)
            .padding(.top, 20)
            if let a = store.activeOrder {
                Text("In progress").wText(.section, weight: .semibold).padding(.top, 30).padding(.bottom, 14)
                activeCard(a)
            }
        }
        let entries = bookAgainEntries
        if c != nil && !entries.isEmpty {
            Text("Book again").wText(.section, weight: .semibold).padding(.top, 30).padding(.bottom, 14)
            VStack(spacing: 12) {
                ForEach(entries) { e in bookAgainCard(e) }
            }
        }
    }

    /// One entry per vehicle + place + wash, newest first. When the same vehicle has
    /// other entries, the part that's different (place or wash) is highlighted.
    struct BookAgainEntry: Identifiable {
        let order: Order
        var placeDiffers = false
        var washDiffers = false
        var id: String { order.id }
    }

    var bookAgainEntries: [BookAgainEntry] {
        var seen = Set<String>()
        var list: [BookAgainEntry] = []
        for o in store.pastOrders {
            let key = "\(o.vehicle.id)#\(o.placeKey)#\(o.washKind.rawValue)"
            if seen.insert(key).inserted { list.append(BookAgainEntry(order: o)) }
        }
        for i in list.indices {
            let me = list[i].order
            let siblings = list.filter { $0.order.vehicle.id == me.vehicle.id && $0.id != me.id }
            list[i].placeDiffers = siblings.contains { $0.order.placeKey != me.placeKey }
            list[i].washDiffers = siblings.contains { $0.order.washKind != me.washKind }
        }
        return list
    }

    func bookAgainCard(_ e: BookAgainEntry) -> some View {
        let o = e.order
        let bike = o.vehicle.type.kind == .bike
        return Button { router.push(.repeatBooking(o.id)) } label: {
            HStack(alignment: .top, spacing: 14) {
                WIconBox(icon: o.vehicle.type.icon, size: 48, radius: 12)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        WPlate(text: o.vehicle.plate)
                        Spacer(minLength: 8)
                        Text(Fmt.rupees(o.price)).wText(.valueStrong).wMoney()
                    }
                    HStack(spacing: 4) {
                        Text("\(o.vehicle.type.shortName) ·").wText(.caption)
                        highlight(o.washKind.name(bike: bike), on: e.washDiffers)
                    }
                    highlight("\(o.place.title) · \(o.place.parkingShort)", icon: .location, on: e.placeDiffers)
                    Text("Last booked \(Fmt.day(o.slot.date))").wText(.small, color: WColor.muted)
                }
                WIconView(icon: .chevron, size: 13, color: WColor.secondary).padding(.top, 10)
            }
            .wCard(padding: 16, radius: 16)
        }
        .buttonStyle(.plain)
    }

    /// Caption text; when `on`, tinted so the changed detail stands out.
    @ViewBuilder func highlight(_ text: String, icon: WIcon? = nil, on: Bool) -> some View {
        HStack(spacing: 4) {
            if let icon { WIconView(icon: icon, size: 11, color: on ? WColor.primaryStrong : WColor.secondary) }
            Text(text).wText(.caption, color: on ? WColor.primaryStrong : nil, weight: on ? .semibold : nil)
                .lineLimit(2)
        }
        .padding(.horizontal, on ? 8 : 0)
        .padding(.vertical, on ? 3 : 0)
        .background(on ? WColor.primaryTint : .clear, in: Capsule())
    }

    func book() {
        store.startNewBooking()
        router.push(.vehicleType(large: false))
    }

    var firstWashCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            WStateCircle(icon: .drop, size: 64).padding(.bottom, 22)
            Text("Book your first wash").wText(.section, weight: .semibold)
            Text("Car from ₹149, bike ₹69. Pay only after you see the photos.").wText(.body).padding(.top, 6).padding(.bottom, 20)
            WButton("Book a wash") { book() }
        }
        .wCard(padding: 20)
    }

    var howItWorks: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it works").wText(.section, weight: .semibold)
            ForEach(Array(["Tell us where it’s parked and pick a time",
                           "A verified captain cleans it, before and after photos",
                           "You approve the photos, then the captain is paid"].enumerated()), id: \.offset) { i, t in
                HStack(spacing: 14) {
                    Text("\(i + 1)").wText(.label, color: WColor.primaryStrong).frame(width: 32, height: 32)
                        .background(WColor.primaryTint, in: Circle())
                    Text(t).wText(.bodyStrong, size: 15.5)
                }
            }
        }
    }

    func activeCard(_ o: Order) -> some View {
        Button {
            store.currentOrderId = o.id
            router.push(.live)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(o.slot.dayLabel) · \(o.slot.label)").wText(.label, color: WColor.heading)
                    Spacer()
                    StatusBadge(status: o.status)
                }
                HStack(spacing: 12) {
                    WAvatar(initials: o.captain?.initials ?? "…", size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(activeTitle(o)).wText(.title, weight: .medium)
                        Text("\(o.vehicle.plate) · \(o.place.parkingShort)").wText(.caption)
                    }
                    Spacer()
                    WIconView(icon: .chevron, size: 13, color: WColor.secondary)
                }
                WProgress(step: o.status.stepIndex + 1, of: 4)
            }
            .wCard(padding: 16, radius: 16)
        }
        .buttonStyle(.plain)
    }

    func activeTitle(_ o: Order) -> String {
        let n = o.captain?.name ?? "Captain"
        switch o.status {
        case .searching: return "Finding a captain"
        case .onTheWay: return "\(n) is on the way"
        case .washing: return "\(n) is washing"
        case .photosReady: return "Check the photos"
        default: return "Booking"
        }
    }

    func bookAgainRow(icon: WIcon, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                WIconBox(icon: icon, size: 48, radius: 12)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).wText(.title, weight: .medium)
                    Text(sub).wText(.caption)
                }
                Spacer()
                WIconView(icon: .chevron, size: 13, color: WColor.secondary)
            }
            .wCard(padding: 16, radius: 16)
        }
        .buttonStyle(.plain)
    }

    /// C55 loading skeleton.
    var skeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 8).fill(WColor.disabled).frame(width: 160, height: 26).padding(.top, 18)
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 6).fill(WColor.disabled).frame(width: 120, height: 12)
                HStack(spacing: 12) {
                    Circle().fill(WColor.disabled).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6).fill(WColor.disabled).frame(width: 180, height: 12)
                        RoundedRectangle(cornerRadius: 6).fill(WColor.disabled).frame(width: 130, height: 10)
                    }
                }
            }
            .wCard(padding: 18)
            ForEach(0..<2, id: \.self) { _ in Color.clear.frame(height: 50).wCard(padding: 16) }
        }
        .redacted(reason: .placeholder)
    }
}

/// Status badge for an order (icon + word).
struct StatusBadge: View {
    let status: OrderStatus
    var body: some View {
        switch status {
        case .searching: WBadge(text: "Searching", tone: .mute, icon: .search)
        case .onTheWay: WBadge(text: "On the way", tone: .info, icon: .check)
        case .washing: WBadge(text: "Washing", tone: .info, icon: .drop)
        case .photosReady: WBadge(text: "Check photos", tone: .ok, icon: .image)
        case .approved, .autoApproved: WBadge(text: "Done", tone: .ok, icon: .sparkle)
        case .cancelled: WBadge(text: "Cancelled", tone: .error, icon: .close)
        case .noCaptain, .disputeUpheld, .captainNoShow: WBadge(text: "Refunded", tone: .ok, icon: .rupee)
        case .disputed: WBadge(text: "Under review", tone: .wait, icon: .eye)
        case .disputeRejected: WBadge(text: "Done", tone: .ok, icon: .sparkle)
        case .paymentPending: WBadge(text: "Payment pending", tone: .wait, icon: .clock)
        case .pendingPayment: WBadge(text: "Not paid", tone: .mute, icon: .clock)
        }
    }
}

// MARK: C43 Bookings (C43b empty, C43c past)

struct BookingsTab: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var tab = 0

    var body: some View {
        let list = tab == 0 ? store.upcomingOrders : store.pastOrders
        VStack(alignment: .leading, spacing: 0) {
            Text("Bookings").wText(.screen).padding(.top, 20).padding(.horizontal, WSpace.gutter)
            WTabs(options: ["Upcoming", "Past"], selection: $tab).padding(.top, 14).padding(.horizontal, WSpace.gutter)
            if list.isEmpty {
                WFullState(icon: .calendar, title: tab == 0 ? "Nothing booked" : "No past washes",
                           message: "Your wheels are waiting. Book a wash and we’ll find a captain nearby.",
                           primary: "Book a wash", onPrimary: {
                               store.startNewBooking()
                               router.push(.vehicleType(large: false))
                           })
                    .padding(.horizontal, 26)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(list) { o in row(o) }
                    }
                    .padding(.horizontal, WSpace.gutter)
                    .padding(.vertical, 18)
                }
            }
        }
        .background(WColor.canvas)
    }

    func row(_ o: Order) -> some View {
        Button {
            store.currentOrderId = o.id
            router.push(o.status.isUpcoming ? .live : .bookingDetail(o.id))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(o.status.isUpcoming ? "\(o.slot.dayLabel) · \(o.slot.label)" : Fmt.date(o.slot.date))
                        .wText(.label, color: WColor.heading)
                    Spacer()
                    StatusBadge(status: o.status)
                }
                HStack(spacing: 14) {
                    WIconBox(icon: o.vehicle.type.icon, size: 40, radius: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(o.vehicle.plate).wText(.title, weight: .regular, size: 16.5)
                        Text(subtitle(o)).wText(.caption)
                    }
                    Spacer()
                    WIconView(icon: .chevron, size: 13, color: WColor.secondary)
                }
            }
            .wOutlined(padding: 16, radius: 16)
        }
        .buttonStyle(.plain)
    }

    func subtitle(_ o: Order) -> String {
        let t = o.vehicle.type.shortName
        switch o.status {
        case .cancelled: return "\(t) · cancelled"
        case .noCaptain, .disputeUpheld, .captainNoShow: return "\(t) · \(Fmt.rupees(o.price)) refunded"
        case .approved, .autoApproved, .disputeRejected: return "\(t) · \(Fmt.rupees(o.price)) paid"
        default: return "\(t) · \(Fmt.rupees(o.price)) held"
        }
    }
}

// MARK: C44 Booking detail

struct BookingDetailScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let orderId: String

    var body: some View {
        if let o = store.order(orderId) {
            WScreen {
                WAppBar(title: Fmt.date(o.slot.date), subtitle: "Booking #\(o.ref)",
                        onLeading: { router.pop() }, onTrailing: { router.push(.help) })
                    .padding(.horizontal, 14).padding(.top, 4)
            } content: {
                HStack(spacing: 8) {
                    StatusBadge(status: o.status)
                    if o.status == .approved { WBadge(text: "\(Fmt.rupees(o.price)) paid", tone: .ok, icon: .check) }
                }
                .padding(.top, 14)
                if o.status != .cancelled {
                    Text("Photos").wText(.label).padding(.top, 20).padding(.bottom, 8)
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { i in
                            WPhotoPlaceholder(icon: i % 2 == 0 ? .car : .sparkle, tag: i % 2 == 0 ? "Before" : "After",
                                              tagTone: i % 2 == 0 ? .mute : .ok).frame(height: 70)
                        }
                    }
                }
                WKeyValueCard(rows: [
                    ("Vehicle", o.vehicle.plate),
                    ("Captain", o.captain.map { "\($0.name)\(o.rating.map { " · you rated \($0)" } ?? "")" } ?? "—"),
                    ("Time", "\(Fmt.time(o.startedAt ?? o.slot.start)) – \(Fmt.time(o.finishedAt ?? o.slot.start))"),
                    (o.refund != nil ? "Refunded" : "Paid", "\(Fmt.rupees(o.price)) · \(o.paidWith?.title ?? "UPI")"),
                ])
                .padding(.top, 20)
                VStack(spacing: 0) {
                    WListRow(icon: .receipt, title: "Download receipt")
                    WDivider()
                    if o.refund != nil {
                        WListRow(icon: .rupee, title: "Track refund") { router.push(.refund) }
                    } else {
                        WListRow(icon: .flag, title: "Report a problem",
                                 subtitle: "Until \(Fmt.time(o.reportUntil ?? Date())), \(Fmt.date(o.reportUntil ?? Date()))") {
                            router.push(.reportProblem)
                        }
                    }
                }
                .padding(.top, 16)
            } footer: {
                WFooterBar(onCall: callSupport) {
                    WButton("Book again", icon: .refresh) { router.push(.repeatBooking(o.id)) }
                }
            }
        }
    }
}

// MARK: C45 Book again

struct RepeatScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    /// An order id (repeat that exact booking) or a vehicle id.
    let vehicleId: String

    var body: some View {
        let from = store.order(vehicleId)
        let v0 = from?.vehicle ?? store.vehicles.first { $0.id == vehicleId } ?? AppStore.car
        let v = Vehicle(id: v0.id, plate: v0.plate, type: v0.type, place: from?.place ?? v0.place)
        let lastNote = store.orders.first { $0.vehicle.id == v.id && !$0.note.isEmpty }?.note ?? EntryNote(voiceSeconds: 12)
        WScreen {
            WAppBar(title: "Book again", onLeading: { router.pop() }, onTrailing: { router.push(.help) })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            WTitleBlock(title: "Same wash, new time", subtitle: "We kept your vehicle and parking details.", topPadding: 14)
            HStack(spacing: 14) {
                WIconBox(icon: v.type.icon, size: 48, radius: 12)
                VStack(alignment: .leading, spacing: 6) {
                    WPlate(text: v.plate)
                    Text("\(v.type.shortName) · \(v.place?.tower ?? "") · \(v.place?.parkingShort ?? "")").wText(.caption)
                }
            }
            .wCard(padding: 16, radius: 16)
            WKeyValueCard(rows: [
                ("Wash", (from?.washKind ?? .wetOutside).name(bike: v.type.kind == .bike)),
                ("Place", v.place?.title ?? ""),
                ("Parking", "\(v.place?.tower ?? "") · \(v.place?.parkingShort ?? "")"),
                ("Notes", lastNote.summary),
            ])
            .padding(.top, 16)
            Text("Still needed for this wash").wText(.label).padding(.top, 22).padding(.bottom, 4)
            WListRow(icon: .camera, title: "4 fresh photos", subtitle: "Every wash starts with new photos")
            WDivider()
            WListRow(icon: .door, title: "Gate pass", subtitle: "We’ll ask on WhatsApp after you pay", trailing: "Later", chevron: false)
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Take photos") {
                    store.startRepeat(v, place: v.place, wash: from?.wash)
                    store.draft.note = lastNote
                    router.push(.photos)
                }
            }
        }
    }
}

// MARK: C46 Vehicles

struct VehiclesTab: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your vehicles").wText(.screen).padding(.top, 20)
                Text("\(store.myVehicles.count) saved · tap one to book").wText(.caption).padding(.bottom, 6)
                ForEach(store.myVehicles) { v in
                    Button { router.push(.repeatBooking(v.id)) } label: {
                        HStack(spacing: 14) {
                            WIconBox(icon: v.type.icon, size: 48, radius: 12)
                            VStack(alignment: .leading, spacing: 6) {
                                WPlate(text: v.plate)
                                Text("\(v.type.shortName) · \(v.place?.tower ?? "") · \(v.place?.parkingShort ?? "")").wText(.caption)
                            }
                            Spacer()
                            WIconView(icon: .chevron, size: 13, color: WColor.secondary)
                        }
                        .wCard(padding: 16, radius: 16)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    store.startNewBooking()
                    router.push(.vehicleType(large: false))
                } label: {
                    HStack(spacing: 10) {
                        WIconView(icon: .plus, size: 16, color: WColor.primaryStrong, weight: .semibold)
                        Text("Add a vehicle").wText(.title, color: WColor.primaryStrong)
                    }
                    .frame(maxWidth: .infinity).frame(height: 62)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WColor.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WSpace.gutter)
        }
        .background(WColor.canvas)
    }
}

// MARK: C47 Profile (C53 delete account)

struct ProfileTab: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var showDelete = false
    @State var deleteBlocked = false
    @State var editName = false
    @State var newName = ""

    var body: some View {
        let c = store.customer
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let c {
                        HStack(spacing: 14) {
                            ProfilePhotoPicker(initials: c.initials)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.name.isEmpty ? "Your profile" : c.name).wText(.section, weight: .semibold)
                                Text(Fmt.phone(c.phone)).wText(.caption)
                            }
                        }
                        .padding(.top, 20)
                        if c.freeWashes > 0 {
                            HStack(spacing: 10) {
                                WIconView(icon: .gift, size: 15, color: WColor.onSuccess)
                                Text("\(c.freeWashes) free washes left").wText(.caption, color: WColor.onSuccess, weight: .medium)
                                Spacer()
                            }
                            .padding(.horizontal, 16).frame(height: 44)
                            .background(WColor.successTint, in: RoundedRectangle(cornerRadius: 12))
                        }
                        VStack(spacing: 0) {
                            WListRow(icon: .edit, title: "Edit name") { newName = c.name; editName = true }
                            WDivider(inset: 54)
                            WListRow(icon: .phone, title: "Phone number", subtitle: Fmt.phone(c.phone)) { router.push(.changePhone) }
                            WDivider(inset: 54)
                            if let upi = c.refundUPI {
                                // Only appears once we've needed a refund UPI ID.
                                WListRow(icon: .rupee, title: "Refund UPI ID", subtitle: upi) { router.push(.refundUPI(nil)) }
                                WDivider(inset: 54)
                            }
                            WListRow(icon: .home, title: "Saved places", subtitle: "My Home Avatar, Tower 3")
                            WDivider(inset: 54)
                            WListRow(icon: .bell, title: "Notifications", subtitle: notificationSummary) {
                                router.push(.notificationSettings)
                            }
                        }
                        .wCard(padding: 14, radius: 16)
                    } else {
                        Text("Profile").wText(.screen).padding(.top, 20)
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Log in to see your bookings and free washes.").wText(.body)
                            WButton("Log in") { router.push(.login(error: false)) }
                        }
                        .wCard(padding: 18)
                    }
                    VStack(spacing: 0) {
                        WListRow(icon: .help, title: "Help and support") { router.push(.help) }
                        WDivider(inset: 54)
                        WListRow(icon: .doc, title: "Terms and privacy")
                    }
                    .wCard(padding: 14, radius: 16)
                    if c != nil {
                        VStack(spacing: 0) {
                            WListRow(icon: .logout, title: "Log out") {
                                store.signOut()
                                store.hasSeenWelcome = true
                                router.tab = 0
                            }
                            WDivider(inset: 54)
                            WListRow(icon: .trash, title: "Delete account", tone: .error) { showDelete = true }
                        }
                        .wCard(padding: 14, radius: 16)
                    }
                }
                .padding(.horizontal, WSpace.gutter)
                .padding(.bottom, 24)
            }
            .background(WColor.canvas)
            if showDelete { deleteDialog }
        }
        .alert("Edit name", isPresented: $editName) {
            TextField("Your name", text: $newName)
            Button("Save") { Task { try? await store.updateName(newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    var notificationSummary: String {
        guard store.notificationsOn else { return "Off" }
        if store.systemPermission == .denied { return "Blocked in iPhone Settings" }
        if store.notificationPrefs.isMuted(), let u = store.notificationPrefs.mutedUntil { return "Muted until \(Fmt.time(u))" }
        return store.notificationPrefs.style == .bannerOnly ? "On, no sound" : "On"
    }

    var deleteDialog: some View {
        ZStack {
            WColor.scrim.ignoresSafeArea().onTapGesture { showDelete = false }
            VStack(alignment: .leading, spacing: 12) {
                WIconBox(icon: .trash, size: 52, tone: .error, radius: 26)
                Text("Delete your account?").wText(.section, weight: .semibold)
                Text(deleteBlocked ? "You can’t do this while a wash is in progress. Try again after it’s approved."
                     : "Your vehicles, bookings and \(store.customer?.freeWashes ?? 0) free washes go with it. You can’t do this while a wash is in progress.")
                    .wText(.body)
                WButton("Delete account", kind: .danger, enabled: !deleteBlocked) {
                    Task {
                        let ok = (try? await store.deleteAccount()) ?? false
                        if ok { showDelete = false; router.tab = 0 } else { deleteBlocked = true }
                    }
                }
                .padding(.top, 6)
                WButton("Keep my account", kind: .text) { showDelete = false; deleteBlocked = false }
            }
            .padding(24)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 26)
        }
    }
}

// MARK: C50 Offline · C51 Server error · C54 Session expired

struct OfflineScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var body: some View {
        WScreen(scrolls: false) {
            BookingHeader(step: 3, label: "Place", fraction: 0.6)
        } content: {
            WFullState(icon: .wifiOff, tone: .mute, title: "You’re offline",
                       message: "Check your internet. Anything you entered is saved on this phone.",
                       primary: "Retry", onPrimary: { store.demo.offline = false; router.pop() })
        }
    }
}

struct ServerErrorScreen: View {
    @Environment(Router.self) var router
    var body: some View {
        WScreen(scrolls: false) {
            PlainHeader()
        } content: {
            WFullState(icon: .warning, tone: .error, title: "Something went wrong on our side",
                       message: "It’s not you. Try again in a minute, or call us and we’ll sort it out.",
                       primary: "Try again", secondary: "Call support",
                       onPrimary: { router.pop() }, onSecondary: callSupport)
        }
    }
}

struct SessionExpiredScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var body: some View {
        WScreen(scrolls: false) {
            Color.clear.frame(height: 56)
        } content: {
            WFullState(icon: .lock, title: "Please log in again",
                       message: "For your safety we log you out after 30 days. Your bookings are safe.",
                       primary: "Log in", onPrimary: {
                           store.signOut()
                           router.replace(with: [.login(error: false)])
                       })
        }
    }
}
