import SwiftUI

/// Screens gallery (demo mode only). Opens every designed screen and state
/// (C01–C55) with the right sample data, and holds the switches that force
/// edge cases in the live flow.
struct GalleryScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    struct Entry: Identifiable {
        let id: String
        let title: String
        let prep: @MainActor (AppStore) -> Void
        let route: Route?
        var tab: Int? = nil
    }

    var sections: [(String, [Entry])] {
        [
            ("01 · Book a wash", [
                Entry(id: "C01", title: "Splash", prep: { _ in }, route: nil, tab: -1),
                Entry(id: "C02", title: "Welcome", prep: { $0.signOut() }, route: .welcome),
                Entry(id: "C05", title: "Vehicle type", prep: { $0.draftBasics() }, route: .vehicleType(large: false)),
                Entry(id: "C05w", title: "Wash type – car", prep: { $0.draftBasics(); $0.draft.wash = nil }, route: .washType),
                Entry(id: "C05wb", title: "Wash type – bike", prep: { $0.draftBasics(); $0.draft.type = VehicleType.all[0]; $0.draft.wash = nil }, route: .washType),
                Entry(id: "C06", title: "Vehicle number", prep: { $0.draftBasics() }, route: .vehicleNumber),
                Entry(id: "C07", title: "Vehicle photos – empty", prep: { $0.draftBasics() }, route: .photos),
                Entry(id: "C07b", title: "Vehicle photos – one failed", prep: { s in
                    s.draftBasics(); s.draft.photos[.front] = .done; s.draft.photos[.back] = .failed
                }, route: .photos),
                Entry(id: "C07c", title: "Vehicle photos – all done", prep: { s in s.draftFull(); s.draft.place = nil }, route: .photos),
                Entry(id: "C08", title: "Camera – guided angle", prep: { $0.draftBasics() }, route: .camera(.front, denied: false)),
                Entry(id: "C08b", title: "Camera access needed", prep: { _ in }, route: .camera(.front, denied: true)),
                Entry(id: "C09", title: "Confirm location", prep: { s in s.draftFull(); s.draft.place = nil }, route: .location(off: false)),
                Entry(id: "C09b", title: "Location is off", prep: { _ in }, route: .location(off: true)),
                Entry(id: "C09c", title: "Search address", prep: { $0.draftFull() }, route: .addressSearch),
                Entry(id: "C10", title: "Floor and slot", prep: { $0.draftFull() }, route: .floorSlot),
                Entry(id: "C11", title: "Message for the captain – nothing yet", prep: { $0.draftFull(); $0.draft.note = EntryNote() }, route: .entryNotes),
                Entry(id: "C11v", title: "Message – voice note + text", prep: { $0.draftFull(); $0.draft.note = EntryNote(text: "White car next to the pillar", voiceSeconds: 12) }, route: .entryNotes),
                Entry(id: "C11d", title: "Message – video recorded", prep: { $0.draftFull(); $0.draft.note = EntryNote(videoSeconds: 15) }, route: .entryNotes),
                Entry(id: "C12", title: "Pick a time", prep: { $0.draftFull() }, route: .timeSlot),
                Entry(id: "C12b", title: "No captains free today", prep: { s in s.draftFull(); s.demo.noCaptainsToday = true }, route: .timeSlot),
                Entry(id: "C13", title: "Check and pay", prep: { $0.draftFull() }, route: .review),
                Entry(id: "C14", title: "Log in with phone", prep: { s in s.signOut(); s.draftFull() }, route: .login(error: false)),
                Entry(id: "C14b", title: "Phone number – invalid", prep: { $0.signOut() }, route: .login(error: true)),
                Entry(id: "C15", title: "Enter code", prep: { $0.pendingPhone = AppStore.samplePhone }, route: .otp(.entering)),
                Entry(id: "C15b", title: "Code – wrong", prep: { $0.pendingPhone = AppStore.samplePhone }, route: .otp(.wrong)),
                Entry(id: "C15c", title: "Code – expired", prep: { $0.pendingPhone = AppStore.samplePhone }, route: .otp(.expired)),
                Entry(id: "C16", title: "Your name", prep: { $0.signInAsSample() }, route: .name),
                Entry(id: "C17", title: "Payment method sheet", prep: { s in s.signInAsSample(); s.draftFull() }, route: .review),
                Entry(id: "C18", title: "Payment processing", prep: { s in s.signInAsSample(); s.draftFull() }, route: .paying(.processing)),
                Entry(id: "C18b", title: "Payment failed", prep: { s in s.signInAsSample(); s.draftFull() }, route: .paying(.failed)),
                Entry(id: "C18c", title: "Payment pending", prep: { s in s.signInAsSample(); s.draftFull(); s.sampleOrder(.paymentPending) }, route: .paying(.pending)),
                Entry(id: "C19", title: "Booked – send entry pass", prep: { s in s.signInAsSample(); s.sampleOrder(.searching) }, route: .booked),
                Entry(id: "C19b", title: "WhatsApp bot (reference)", prep: { s in s.signInAsSample(); s.sampleOrder(.searching) }, route: .whatsApp),
            ]),
            ("02 · Live order, approve, cancel", [
                Entry(id: "C20", title: "Finding a captain", prep: { s in s.signInAsSample(); s.sampleOrder(.searching) }, route: .live),
                Entry(id: "C21", title: "No captain found – add UPI for refund", prep: { s in s.signInAsSample(); s.customer?.refundUPI = nil; s.sampleOrder(.noCaptain) }, route: .live),
                Entry(id: "C21u", title: "Refund UPI ID", prep: { s in s.signInAsSample(); s.customer?.refundUPI = nil; s.sampleOrder(.noCaptain) }, route: .refundUPI("current")),
                Entry(id: "C24x", title: "Captain no-show – checking", prep: { s in s.signInAsSample(); s.markNoShowChecking() }, route: .live),
                Entry(id: "C24y", title: "Captain no-show – refunded", prep: { s in s.signInAsSample(); s.customer?.refundUPI = nil; s.sampleOrder(.captainNoShow) }, route: .live),
                Entry(id: "C22", title: "Captain on the way", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay) }, route: .live),
                Entry(id: "C22b", title: "Entry pass missing", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay, passMissing: true) }, route: .live),
                Entry(id: "C24", title: "Captain running late", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay, late: true) }, route: .live),
                Entry(id: "C30", title: "Captain can’t find vehicle", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay, cantFind: true) }, route: .live),
                Entry(id: "C23", title: "Washing in progress", prep: { s in s.signInAsSample(); s.sampleOrder(.washing) }, route: .live),
                Entry(id: "C25", title: "Wash done – check photos", prep: { s in s.signInAsSample(); s.sampleOrder(.photosReady) }, route: .live),
                Entry(id: "C26", title: "Photo compare", prep: { s in s.signInAsSample(); s.sampleOrder(.photosReady) }, route: .photoCompare),
                Entry(id: "C27", title: "Rate the captain", prep: { s in s.signInAsSample(); s.sampleOrder(.approved) }, route: .rate),
                Entry(id: "C28", title: "Approved automatically", prep: { s in s.signInAsSample(); s.sampleOrder(.autoApproved) }, route: .live),
                Entry(id: "C29", title: "Cancel sheet (open from C20)", prep: { s in s.signInAsSample(); s.sampleOrder(.searching) }, route: .live),
                Entry(id: "C29c", title: "Cancel after accept (open from C22)", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay) }, route: .live),
                Entry(id: "C29b", title: "Booking cancelled", prep: { s in s.signInAsSample(); s.sampleOrder(.cancelled) }, route: .live),
            ]),
            ("03 · Problems, disputes, refunds", [
                Entry(id: "C31", title: "Report a problem", prep: { s in s.signInAsSample(); s.sampleOrder(.photosReady) }, route: .reportProblem),
                Entry(id: "C31s", title: "Report a problem – photos skipped", prep: { s in s.signInAsSample(); s.sampleOrder(.photosReady, skippedPhotos: true) }, route: .reportProblem),
                Entry(id: "C32", title: "Show us the problem", prep: { s in s.signInAsSample(); s.sampleOrder(.photosReady) }, route: .problemPhotos(.notClean)),
                Entry(id: "C33", title: "Report sent – under review", prep: { s in s.signInAsSample(); s.sampleOrder(.disputed, dispute: .underReview) }, route: .disputeStatus),
                Entry(id: "C34", title: "Dispute upheld", prep: { s in s.signInAsSample(); s.sampleOrder(.disputeUpheld, dispute: .upheld) }, route: .disputeStatus),
                Entry(id: "C35", title: "Dispute rejected", prep: { s in s.signInAsSample(); s.sampleOrder(.disputeRejected, dispute: .rejected) }, route: .disputeStatus),
                Entry(id: "C36", title: "Damage report", prep: { s in s.signInAsSample(); s.sampleOrder(.disputed, dispute: .damagePriority, damage: true) }, route: .disputeStatus),
                Entry(id: "C37", title: "Refund status", prep: { s in s.signInAsSample(); s.sampleOrder(.cancelled) }, route: .refund),
            ]),
            ("04 · Home, bookings, account, system", [
                Entry(id: "C40", title: "Home – first time (now: straight to vehicle)", prep: { s in s.signInAsSample(); s.demo.emptyHistory = true }, route: nil, tab: 0),
                Entry(id: "C40h", title: "Home – first time (hidden design)", prep: { s in s.signInAsSample(); s.demo.emptyHistory = true; s.showFirstWashHome = true }, route: nil, tab: 0),
                Entry(id: "C41", title: "Home – active booking", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay) }, route: nil, tab: 0),
                Entry(id: "C42", title: "Home – free washes", prep: { $0.signInAsSample(freeWashes: 2) }, route: nil, tab: 0),
                Entry(id: "C43", title: "Bookings – upcoming", prep: { s in s.signInAsSample(); s.sampleOrder(.onTheWay) }, route: nil, tab: 1),
                Entry(id: "C43b", title: "Bookings – empty", prep: { s in s.signInAsSample(); s.demo.emptyHistory = true }, route: nil, tab: 1),
                Entry(id: "C43c", title: "Bookings – past", prep: { $0.signInAsSample() }, route: nil, tab: 1),
                Entry(id: "C44", title: "Booking detail", prep: { $0.signInAsSample() }, route: .bookingDetail("ord_past1")),
                Entry(id: "C45", title: "Book again", prep: { $0.signInAsSample() }, route: .repeatBooking("veh_car")),
                Entry(id: "C46", title: "Your vehicles", prep: { $0.signInAsSample() }, route: nil, tab: 2),
                Entry(id: "C47", title: "Profile", prep: { $0.signInAsSample(freeWashes: 2) }, route: nil, tab: 3),
                Entry(id: "C48", title: "Help", prep: { _ in }, route: .help),
                Entry(id: "N1", title: "Notifications", prep: { $0.signInAsSample() }, route: .notifications),
                Entry(id: "N2", title: "Notification settings", prep: { $0.signInAsSample() }, route: .notificationSettings),
                Entry(id: "C49", title: "Notifications ask", prep: { s in s.signInAsSample(); s.sampleOrder(.searching) }, route: .notifyAsk),
                Entry(id: "C50", title: "Offline", prep: { _ in }, route: .offline),
                Entry(id: "C51", title: "Server error", prep: { _ in }, route: .serverError),
                Entry(id: "C52", title: "200% text", prep: { $0.draftBasics() }, route: .vehicleType(large: true)),
                Entry(id: "C53", title: "Delete account (Profile → Delete)", prep: { $0.signInAsSample(freeWashes: 2) }, route: nil, tab: 3),
                Entry(id: "C54", title: "Session expired", prep: { $0.signInAsSample() }, route: .sessionExpired),
            ]),
        ]
    }

    var body: some View {
        @Bindable var store = store
        WScreen {
            WAppBar(title: "Screens", subtitle: "Demo mode · sample data", trailing: nil, onLeading: { router.pop() })
                .padding(.horizontal, 14)
        } content: {
            Text("Switches for the live flow").wText(.label).padding(.top, 10).padding(.bottom, 6)
            VStack(spacing: 0) {
                Toggle("Payment fails", isOn: Binding(get: { store.demo.payment == .failed }, set: { store.demo.payment = $0 ? .failed : .success }))
                Toggle("Payment stays pending", isOn: Binding(get: { store.demo.payment == .pending }, set: { store.demo.payment = $0 ? .pending : .success }))
                Toggle("No captain found", isOn: $store.demo.noCaptainFound)
                Toggle("Captain runs late", isOn: $store.demo.captainRunsLate)
                Toggle("Captain doesn’t show up", isOn: $store.demo.captainNoShow)
                Toggle("Captain can’t find vehicle", isOn: $store.demo.captainCantFind)
                Toggle("Entry pass never arrives", isOn: $store.demo.entryPassNeverArrives)
                Toggle("Back photo fails once", isOn: $store.demo.failBackPhotoOnce)
                Toggle("Dispute gets rejected", isOn: $store.demo.disputeRejected)
            }
            .font(WFont.of(.body, size: 15))
            .tint(WColor.primary)
            .padding(.bottom, 8)
            WButton("Reset demo", kind: .tonal) { store.resetDemo() }.padding(.bottom, 10)
            ForEach(sections, id: \.0) { section in
                Text(section.0).wText(.section, weight: .semibold).padding(.top, 22).padding(.bottom, 4)
                ForEach(section.1) { e in
                    Button { open(e) } label: {
                        HStack(spacing: 12) {
                            Text(e.id).wText(.label, color: WColor.primaryStrong).frame(width: 46, alignment: .leading)
                            Text(e.title).wText(.rowTitle)
                            Spacer()
                            WIconView(icon: .chevron, size: 12, color: WColor.secondary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    WDivider()
                }
            }
        }
    }

    func open(_ e: Entry) {
        store.resetDemo()
        e.prep(store)
        if e.tab == -1 {
            router.popToRoot()
            router.showSplash = true
            return
        }
        if let t = e.tab {
            store.hasSeenWelcome = true
            router.tab = t
            router.popToRoot()
            return
        }
        if let r = e.route {
            if r == .welcome {
                store.hasSeenWelcome = false
                router.popToRoot()
                return
            }
            router.replace(with: [r])
            if e.id == "C17" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { router.showPaySheet = true }
            }
        }
    }
}
