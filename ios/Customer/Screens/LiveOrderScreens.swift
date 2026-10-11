import SwiftUI

/// Order header: "Today, 8 – 10 AM" over "TS 09 EA 4521 · Hatchback".
struct OrderHeader: View {
    @Environment(Router.self) var router
    let order: Order
    var onBack: (() -> Void)? = nil

    var body: some View {
        WAppBar(title: order.slot.full, subtitle: order.vehicleLine,
                onLeading: { if let onBack { onBack() } else { router.popToRoot() } },
                onTrailing: { router.push(.help) })
            .padding(.horizontal, 14)
            .padding(.top, 4)
    }
}

/// Captain card: avatar, name, rating, call button, status badge and time.
struct CaptainCard: View {
    let order: Order
    var badge: WBadge
    var timeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                WAvatar(initials: order.captain?.initials ?? "RY", size: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.captain?.name ?? "Raju").wText(.title, weight: .semibold, size: 17)
                    HStack(spacing: 4) {
                        WIconView(icon: .starFill, size: 11, color: WColor.star)
                        Text(String(format: "%.1f · %d washes", order.captain?.rating ?? 4.8, order.captain?.washes ?? 212)).wText(.caption)
                    }
                }
                Spacer()
                WIconButton(icon: .phone, style: .tint, label: "Call \(order.captain?.name ?? "captain")") { Support.call() }
            }
            HStack {
                badge
                Spacer()
                Text(timeText).wText(.caption, color: WColor.heading, weight: .medium)
            }
        }
        .wCard(padding: 16)
    }
}

private let liveSteps = [
    WStatusSteps.Step(title: "Booked"),
    WStatusSteps.Step(title: "Captain on the way"),
    WStatusSteps.Step(title: "Washing"),
    WStatusSteps.Step(title: "Check photos"),
]

// MARK: Live order (C20, C21, C22, C22b, C23, C24, C25, C28, C29b, C30)

struct LiveOrderScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var showCancel = false

    var body: some View {
        Group {
            if let o = store.currentOrder {
                content(o)
            } else {
                WScreen { PlainHeader() } content: {
                    WFullState(icon: .calendar, title: "No active booking", primary: "Go home", onPrimary: { router.popToRoot() })
                }
            }
        }
        .wSheet(isPresented: $showCancel, height: store.currentOrder?.status == .onTheWay ? 360 : 420) {
            CancelSheet(onDone: { showCancel = false })
        }
        .onChange(of: store.currentOrder?.status) { _, new in
            if new == .approved, store.currentOrder?.rating == nil { router.replace(with: [.rate]) }
        }
    }

    @ViewBuilder
    func content(_ o: Order) -> some View {
        switch o.status {
        case .searching, .paymentPending, .pendingPayment:
            searching(o)
        case .noCaptain:
            autoCancelled(o, icon: .search, title: "No captain could take your wash",
                          why: "We couldn’t find a free captain, so we’ve cancelled the booking.")
        case .captainNoShow:
            autoCancelled(o, icon: .clock, title: "\(o.captain?.name ?? "Your captain") didn’t turn up",
                          why: "The wash wasn’t done in your slot. We’re sorry. You get the full amount back by 11:59 PM tonight, and we’ve taken action with the captain.")
        case .onTheWay:
            if o.captainCantFind { cantFind(o) } else { onTheWay(o) }
        case .washing:
            washing(o)
        case .photosReady:
            CheckWashView(order: o)
        case .cancelled:
            WScreen(scrolls: false) { PlainHeader() } content: {
                WFullState(icon: .check, tone: .ok, title: "Booking cancelled",
                           message: "\(Fmt.rupees(o.refund?.amount ?? o.price)) is on its way back to your UPI. It usually takes 2 to 3 working days.",
                           primary: "Book another time", secondary: "Track refund",
                           onPrimary: { store.startRepeat(o.vehicle); router.replace(with: [.timeSlot]) },
                           onSecondary: { router.push(.refund) })
            }
        case .autoApproved:
            WScreen(scrolls: false) { PlainHeader() } content: {
                WFullState(icon: .clock, title: "Approved automatically",
                           message: "We didn’t hear from you by midnight, so the wash was approved and \(Fmt.rupees(o.price)) went to \(o.captain?.name ?? "Raju"). Something wrong? You can still report it until midnight tomorrow.",
                           primary: "Rate \(o.captain?.name ?? "Raju")", secondary: "Report a problem",
                           onPrimary: { router.push(.rate) }, onSecondary: { router.push(.reportProblem) })
            }
        case .approved:
            WScreen(scrolls: false) { PlainHeader() } content: {
                WFullState(icon: .sparkle, tone: .ok, title: "Wash approved",
                           message: "\(Fmt.rupees(o.price)) released to \(o.captain?.name ?? "Raju").", primary: "Go home",
                           onPrimary: { router.popToRoot() })
            }
        case .disputed, .disputeUpheld, .disputeRejected:
            DisputeStatusScreen()
        }
    }

    /// No captain / captain no-show: cancelled automatically, full refund to the customer's UPI.
    func autoCancelled(_ o: Order, icon: WIcon, title: String, why: String) -> some View {
        let r = o.refund
        let waiting = r?.awaitingUPI ?? true
        return WScreen(scrolls: false) { PlainHeader(leading: .left) } content: {
            VStack(alignment: .leading, spacing: 0) {
                WStateCircle(icon: icon, tone: .wait, size: 72).padding(.top, 10)
                Text(title).wText(.screen).padding(.top, 18)
                Text(why).wText(.body).padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Full refund").wText(.label)
                        Spacer()
                        Text(Fmt.rupees(r?.amount ?? o.price)).wText(.valueStrong).wMoney()
                    }
                    if waiting {
                        Text("Tell us your UPI ID and we’ll send it there.").wText(.caption)
                    } else {
                        Text("Going to \(r?.upi ?? "your UPI"). Usually within 2 to 3 working days.").wText(.caption)
                    }
                }
                .wCard(padding: 16)
                .padding(.top, 20)
            }
        } footer: {
            WStackedFooter {
                if waiting {
                    WButton("Add UPI ID for refund", icon: .rupee) { router.push(.refundUPI(o.id)) }
                    WButton("Book another time", kind: .text) { store.startRepeat(o.vehicle); router.replace(with: [.timeSlot]) }
                } else {
                    WButton("Book another time") { store.startRepeat(o.vehicle); router.replace(with: [.timeSlot]) }
                    WButton("See refund", kind: .text) { router.push(.refund) }
                }
            }
        }
    }

    // C20 Finding a captain
    func searching(_ o: Order) -> some View {
        WScreen(canvas: true) {
            OrderHeader(order: o)
        } content: {
            VStack(spacing: 0) {
                SearchPulse().padding(.bottom, 22)
                Text("Finding a captain…").wText(.section, weight: .semibold)
                Text("Usually under 5 minutes. You can leave this screen; we’ll notify you.")
                    .wText(.body).multilineTextAlignment(.center).padding(.top, 8).padding(.bottom, 14)
                WBadge(text: "\(Fmt.rupees(o.price)) held safely", tone: .mute, icon: .shield)
            }
            .frame(maxWidth: .infinity)
            .wCard(padding: 22)
            .padding(.top, 14).padding(.bottom, 28)
            WStatusSteps(steps: liveSteps, current: 0)
        } footer: {
            WStackedFooter {
                WButton("Keep me posted") { router.popToRoot() }
                WButton("Cancel booking", kind: .text) { showCancel = true }
            }
        }
    }

    // C22 on the way, C22b pass missing, C24 running late
    func onTheWay(_ o: Order) -> some View {
        let late = o.runningLateMinutes != nil
        let arrives = o.arrivesBy ?? Date()
        return WScreen(canvas: true) {
            OrderHeader(order: o)
        } content: {
            if late {
                CaptainCard(order: o, badge: o.noShowChecking ? WBadge(text: "Checking", tone: .wait, icon: .search)
                                                              : WBadge(text: "Running late", tone: .wait, icon: .clock),
                           timeText: "Now arriving \(Fmt.time(arrives.addingTimeInterval(Double(o.runningLateMinutes ?? 0) * 60 + 30 * 60)))")
                    .padding(.top, 14)
                if o.noShowChecking {
                    WBanner(tone: .wait, icon: .search, title: "We’re checking on your wash.",
                            text: "Your slot ended at \(Fmt.time(o.slot.end)) and \(o.captain?.name ?? "Raju") hasn’t updated it. If the wash doesn’t happen, you get a full refund by 11:59 PM tonight.")
                        .padding(.top, 16)
                } else {
                    WBanner(tone: .wait, icon: .clock,
                            text: "\(o.captain?.name ?? "Raju") is running about \(o.runningLateMinutes ?? 15) minutes late. If the wash doesn’t happen in your slot (till \(Fmt.time(o.slot.end))), we’ll check with him. No wash means a full refund.")
                        .padding(.top, 16)
                }
            } else {
                CaptainCard(order: o, badge: WBadge(text: "Accepted", tone: .info, icon: .check),
                           timeText: "Arrives by \(Fmt.time(arrives))")
                    .padding(.top, 14)
                if o.entryPassReceived {
                    HStack(spacing: 12) {
                        WIconView(icon: .check, size: 15, color: WColor.onSuccess, weight: .semibold)
                        Text("Entry pass received. \(o.captain?.name ?? "Raju") can get in.").wText(.caption, color: WColor.onSuccess, size: 14)
                        Spacer()
                    }
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(WColor.successTint, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 16)
                } else {
                    WBanner(tone: .wait, icon: .door, title: "We still need your gate pass.",
                            text: "Without it \(o.captain?.name ?? "Raju") may be stopped at the gate.", actionTitle: "Send now") {
                        router.push(.whatsApp)
                    }
                    .padding(.top, 16)
                }
            }
            WStatusSteps(steps: liveSteps, current: 1).padding(.top, 26)
        } footer: {
            WStackedFooter {
                if late {
                    WButton("Call \(o.captain?.name ?? "Raju")", icon: .phone, kind: .outline) { Support.call() }
                } else if o.entryPassReceived {
                    WButton("Message on WhatsApp", icon: .whatsapp, kind: .outline) { router.push(.whatsApp) }
                } else {
                    WButton("Send pass on WhatsApp", icon: .whatsapp) { router.push(.whatsApp) }
                }
                WButton("Cancel booking", kind: .text) { showCancel = true }
            }
        }
    }

    // C30 Captain can't find vehicle
    func cantFind(_ o: Order) -> some View {
        WScreen(canvas: true) {
            OrderHeader(order: o)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    WIconBox(icon: .warning, size: 44, tone: .wait, radius: 12)
                    Text("\(o.captain?.name ?? "Raju") can’t find your vehicle").wText(.title)
                }
                Text("He’s at \(o.place.floor ?? "B2") near slot \(o.place.slot.isEmpty ? "41" : o.place.slot) and doesn’t see \(o.vehicle.plate). Is it parked somewhere else today?")
                    .wText(.body)
            }
            .wCard(padding: 18)
            .padding(.top, 14).padding(.bottom, 18)
            VStack(spacing: 10) {
                answer(.layers, "It’s on a different floor") { store.answerCantFind("other_floor") }
                answer(.location, "I moved it outside") { store.answerCantFind("outside") }
                answer(.close, "It’s not here today") { store.answerCantFind("not_here") }
            }
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Call \(o.captain?.name ?? "Raju")", icon: .phone) { Support.call() }
            }
        }
    }

    func answer(_ icon: WIcon, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                WIconView(icon: icon, size: 15, color: WColor.heading)
                Text(title).wText(.bodyStrong, color: WColor.heading, weight: .medium)
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(WColor.border))
        }
        .buttonStyle(WPressStyle())
    }

    // C23 Washing
    func washing(_ o: Order) -> some View {
        WScreen(canvas: true) {
            OrderHeader(order: o)
        } content: {
            CaptainCard(order: o, badge: WBadge(text: "Cleaning", tone: .info, icon: .drop),
                       timeText: "Started \(Fmt.time(o.startedAt ?? Date()))")
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Before photos").wText(.title)
                    Spacer()
                    Text("4 of 4").wText(.caption)
                }
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in WPhotoPlaceholder().frame(height: 56) }
                }
            }
            .wOutlined(padding: 16)
            .padding(.top, 16)
            WStatusSteps(steps: liveSteps, current: 2).padding(.top, 24)
        } footer: {
            // Calling the captain lives in the card above; the footer moves the customer on.
            WStackedFooter {
                WButton("Book another wash", kind: .outline) {
                    store.startNewBooking()
                    router.replace(with: [.vehicleType(large: false)])
                }
                WButton("Go home", kind: .text) { router.tab = 0; router.popToRoot() }
            }
        }
    }
}

/// Pulsing search circle for "Finding a captain…".
struct SearchPulse: View {
    @State var on = false
    var body: some View {
        ZStack {
            Circle().fill(WColor.primaryTint).frame(width: 96, height: 96)
                .scaleEffect(on ? 1.08 : 0.94)
            WIconView(icon: .search, size: 34, color: WColor.primaryStrong, weight: .medium)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { on = true } }
    }
}

// MARK: C29 Cancel sheet (C29c after accept)

struct CancelSheet: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var onDone: () -> Void
    @State var reason: String? = nil
    @State var loading = false

    var body: some View {
        let o = store.currentOrder
        let accepted = o?.status == .onTheWay
        VStack(alignment: .leading, spacing: 14) {
            Text(accepted ? "\(o?.captain?.name ?? "Raju") is already on the way" : "Cancel this wash?")
                .wText(.section, weight: .semibold)
            if accepted {
                WBanner(tone: .wait, icon: .rupee,
                        text: "Cancelling now refunds ₹\(BusinessRules.refundAmountText). ₹\(BusinessRules.cancellationFeeText) goes to \(o?.captain?.name ?? "Raju") for the trip.")
            } else {
                WBanner(tone: .info, icon: .rupee, text: "No captain has accepted yet, so you get the full \(Fmt.rupees(o?.price ?? 149)) back.")
                Text("Why are you cancelling? (optional)").wText(.label)
                WFlow(spacing: 10) {
                    ForEach(["Changed plans", "Booked by mistake", "Taking too long", "Other"], id: \.self) { r in
                        WChip(title: r, selected: reason == r) { reason = r }
                    }
                }
            }
            WButton(accepted ? "Cancel anyway" : "Yes, cancel and refund", kind: .danger, loading: loading) {
                guard let id = o?.id else { return }
                loading = true
                Task {
                    try? await store.cancel(id)
                    loading = false
                    onDone()
                }
            }
            .padding(.top, 4)
            WButton("Keep booking", kind: .text) { onDone() }
        }
    }
}

// MARK: C25 Check the wash

struct CheckWashView: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let order: Order
    @State var approving = false

    var body: some View {
        let name = order.captain?.name ?? "Raju"
        WScreen {
            WAppBar(title: "Check the wash", subtitle: "\(name) finished at \(Fmt.time(order.finishedAt ?? Date()))",
                    onLeading: { router.popToRoot() }, onTrailing: { router.push(.help) })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            HStack(spacing: 12) {
                WIconBox(icon: .sparkle, size: 48, tone: .ok, radius: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Shine restored").wText(.section, weight: .semibold)
                    Text("Approve to release \(Fmt.rupees(order.price)) to \(name)").wText(.caption)
                }
            }
            .padding(.top, 14).padding(.bottom, 18)
            pair("Front")
            pair("Left side").padding(.top, 14)
            WLink("See all 4 angles") { router.push(.photoCompare) }.padding(.top, 16)
        } footer: {
            WStackedFooter {
                WButton("Approve", icon: .check, kind: .success, loading: approving) {
                    approving = true
                    Task {
                        try? await store.approve(order.id)
                        approving = false
                        router.replace(with: [.rate])
                    }
                }
                Text("Auto-approves at 12 midnight if you don’t respond")
                    .wText(.small, color: WColor.muted)
                    .padding(.top, 6)
                WButton("Something’s wrong", kind: .text) { router.push(.reportProblem) }
            }
        }
    }

    func pair(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).wText(.label, color: WColor.heading, weight: .medium)
            HStack(spacing: 10) {
                WPhotoPlaceholder(icon: .car, tag: "Before").frame(height: 110)
                WPhotoPlaceholder(icon: .sparkle, tag: "After", tagTone: .ok).frame(height: 110)
            }
            .onTapGesture { router.push(.photoCompare) }
        }
    }
}

// MARK: C26 Photo compare

struct PhotoCompareScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var page = 0
    @State var split: CGFloat = 0.5

    var body: some View {
        let o = store.currentOrder
        VStack(spacing: 0) {
            WAppBar(title: "\(PhotoAngle.allCases[page].label.replacingOccurrences(of: " side", with: "")) · \(page + 1) of 4",
                    leading: .close, trailing: nil, dark: true, onLeading: { router.pop() })
                .padding(.horizontal, 14)
            TabView(selection: $page) {
                ForEach(0..<4, id: \.self) { i in
                    compare.tag(i).padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            HStack(spacing: 6) {
                Button {} label: { WIconView(icon: .zoom, size: 18, color: .white).frame(width: 48, height: 48) }
                    .buttonStyle(.plain).accessibilityLabel("Zoom")
                Button { router.pop(); router.push(.reportProblem) } label: {
                    WIconView(icon: .flag, size: 18, color: .white).frame(width: 48, height: 48)
                }
                .buttonStyle(.plain).accessibilityLabel("Report a problem")
                WButton("Approve", icon: .check, kind: .success, fullWidth: false) {
                    guard let id = o?.id else { return }
                    Task {
                        try? await store.approve(id)
                        router.replace(with: [.rate])
                    }
                }
            }
            .padding(6)
            .background(WColor.inverse, in: Capsule())
            .padding(.vertical, 16)
        }
        .background(WColor.camera.ignoresSafeArea())
    }

    var compare: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x2A3A50))
                Rectangle().fill(Color(hex: 0x33445C)).frame(width: w * (1 - split))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 20, topTrailingRadius: 20))
                WIconView(icon: .car, size: 46, color: .white.opacity(0.55)).position(x: w * 0.25, y: geo.size.height / 2)
                WIconView(icon: .sparkle, size: 46, color: .white.opacity(0.9)).position(x: w * 0.75, y: geo.size.height / 2)
                Rectangle().fill(.white).frame(width: 2).position(x: w * split, y: geo.size.height / 2).frame(height: geo.size.height)
                ZStack {
                    Circle().fill(.white).frame(width: 44, height: 44)
                    WIconView(icon: .chevron, size: 12, color: WColor.heading)
                }
                .position(x: w * split, y: geo.size.height / 2)
                .gesture(DragGesture().onChanged { v in split = min(0.9, max(0.1, v.location.x / w)) })
                WBadge(text: "Before · 8:33 AM", tone: .mute, solid: true).padding(12)
                WBadge(text: "After · 8:53 AM", tone: .ok).padding(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.bottom, 36)
    }
}

// MARK: C27 Rate

struct RateScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var stars = 4
    @State var tags: Set<String> = ["Spotless", "On time"]

    var body: some View {
        let o = store.currentOrder
        let name = o?.captain?.name ?? "Raju"
        WScreen {
            WAppBar(leading: nil, trailing: .close, onTrailing: { router.popToRoot() }).padding(.horizontal, 14).padding(.top, 4)
        } content: {
            VStack(spacing: 0) {
                WAvatar(initials: o?.captain?.initials ?? "RY", size: 72).padding(.top, 20)
                Text("How did \(name) do?").wText(.screen).padding(.top, 18)
                Text("\(Fmt.rupees(o?.price ?? 149)) released to \(name). Thanks for approving.").wText(.body).padding(.top, 8)
                HStack(spacing: 14) {
                    ForEach(1...5, id: \.self) { i in
                        Button { stars = i } label: {
                            Image(systemName: i <= stars ? "star.fill" : "star")
                                .font(.system(size: 34))
                                .foregroundStyle(i <= stars ? WColor.star : WColor.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(i) stars")
                    }
                }
                .padding(.top, 26).padding(.bottom, 24)
                WFlow(spacing: 10) {
                    ForEach(["Spotless", "On time", "Polite", "Missed a spot", "Late"], id: \.self) { t in
                        WChip(title: t, selected: tags.contains(t)) {
                            if tags.contains(t) { tags.remove(t) } else { tags.insert(t) }
                        }
                    }
                }
                .frame(width: 320)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Submit") {
                    if let id = o?.id { Task { try? await store.rate(id, stars: stars, tags: Array(tags)) } }
                    router.popToRoot()
                }
            }
        }
    }
}
