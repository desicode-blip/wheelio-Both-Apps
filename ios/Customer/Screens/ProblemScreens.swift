import SwiftUI

// MARK: C31 Report a problem

struct ReportProblemScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var kind: ProblemKind = .notClean

    var body: some View {
        WScreen {
            BookingHeader(step: 1, label: "What happened", title: "Report a problem", fraction: 0.5)
                .environment(\.stepTotal, 2)
        } content: {
            WTitleBlock(title: "What went wrong?", subtitle: "Payment stays on hold while we check.")
            if store.currentOrder?.customerSkippedPhotos == true {
                // We still compare the captain's before/after photos; we just can't promise an outcome.
                WBanner(tone: .wait, icon: .camera, title: "You skipped the photos at booking.",
                        text: "So we can’t promise a fix, but we’ll still look into it and get back to you.")
                    .padding(.bottom, 16)
            }
            VStack(spacing: 12) {
                ForEach(ProblemKind.allCases, id: \.self) { k in
                    WSelectionTile(icon: k.icon, title: k.title, subtitle: k.subtitle, selected: kind == k, radio: true) { kind = k }
                }
            }
        } footer: {
            WFooterBar(onCall: callSupport) {
                WButton("Next") { router.push(.problemPhotos(kind)) }
            }
        }
    }
}

private struct StepTotalKey: EnvironmentKey { static let defaultValue = 5 }
extension EnvironmentValues {
    /// Total steps shown in BookingHeader ("Step 1 of 2").
    var stepTotal: Int {
        get { self[StepTotalKey.self] }
        set { self[StepTotalKey.self] = newValue }
    }
}

// MARK: C32 Show us the problem

struct ProblemPhotosScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let kind: ProblemKind
    @State var note = "Water streaks on the bonnet and the left mirror wasn’t wiped."
    @State var photos = 2
    @State var sending = false

    var body: some View {
        WScreen {
            BookingHeader(step: 2, label: "Show us", title: "Report a problem", fraction: 1)
                .environment(\.stepTotal, 2)
        } content: {
            WTitleBlock(title: "Show us the problem", subtitle: "Take photos from the same angles as the captain’s. We compare all three.")
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    if i < photos {
                        WPhotoSlot(label: i == 0 ? "Front" : "Close-up", state: .done, height: 94, icon: i == 0 ? .car : .zoom)
                    } else {
                        WPhotoSlot(label: "Add", state: .empty, height: 94) { photos += 1 }
                    }
                }
            }
            .padding(.bottom, 18)
            WTextArea(text: $note, placeholder: "Tell us what you see", height: 96)
        } footer: {
            WFooterBar(onCall: callSupport) {
                WButton("Send report", enabled: photos > 0, loading: sending) {
                    guard let id = store.currentOrderId else { return }
                    sending = true
                    Task {
                        try? await store.reportProblem(id, kind: kind, note: note)
                        sending = false
                        router.replace(with: [.disputeStatus])
                    }
                }
            }
        }
    }
}

// MARK: C33 under review · C34 upheld · C35 rejected · C36 damage

struct DisputeStatusScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        let o = store.currentOrder
        let d = o?.dispute
        switch d?.outcome ?? .underReview {
        case .underReview: underReview(o, d)
        case .upheld: upheld(o, d)
        case .rejected: rejected(o, d)
        case .damagePriority: damage(o, d)
        }
    }

    func header(_ title: String) -> some View {
        WAppBar(title: title, onLeading: { router.popToRoot() }, onTrailing: { router.push(.help) })
            .padding(.horizontal, 14).padding(.top, 4)
    }

    func underReview(_ o: Order?, _ d: Dispute?) -> some View {
        WScreen {
            header("Report sent")
        } content: {
            HStack(spacing: 12) {
                WBadge(text: "Under review", tone: .wait, icon: .eye)
                Text("Ref #\(d?.ref ?? "WH-20914")").wText(.caption)
            }
            .padding(.top, 14)
            WTitleBlock(title: "We’re checking the photos",
                        subtitle: "\(Fmt.rupees(o?.price ?? 149)) stays on hold. You’ll hear from us within 24 hours.", topPadding: 16)
            WStatusSteps(steps: [
                .init(title: "Report received", detail: Fmt.time(d?.createdAt ?? Date())),
                .init(title: "Comparing photos", detail: "Your photos vs the captain’s before and after"),
                .init(title: "Decision", detail: "By 9:00 AM tomorrow"),
            ], current: 1, spacing: 22)
        } footer: {
            WFooterBar(onCall: callSupport) { WButton("Done") { router.popToRoot() } }
        }
    }

    func upheld(_ o: Order?, _ d: Dispute?) -> some View {
        WScreen {
            header("Report #\(d?.ref ?? "WH-20914")")
        } content: {
            VStack(spacing: 0) {
                WStateCircle(icon: .gift, tone: .ok).padding(.top, 20).padding(.bottom, 24)
                Text("You’re right, sorry").wText(.screen)
                Text(d?.decisionNote ?? "").wText(.body).multilineTextAlignment(.center).padding(.top, 10).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            WKeyValueCard(rows: [
                ("Refund", "\(Fmt.rupees(o?.refund?.amount ?? o?.price ?? 149)) to your UPI"),
                ("Bonus", "\(d?.creditsAwarded ?? 2) free washes added"),
            ])
        } footer: {
            WFooterBar(onCall: callSupport) {
                WButton("Book free wash") {
                    if let o { store.startRepeat(o.vehicle); store.draft.useFreeWash = true }
                    router.replace(with: [.photos])
                }
            }
        }
    }

    func rejected(_ o: Order?, _ d: Dispute?) -> some View {
        WScreen {
            header("Report #\(d?.ref ?? "WH-20914")")
        } content: {
            WTitleBlock(title: "The wash looks complete",
                        subtitle: "We compared your photos with the captain’s. The marks were there before the wash.", topPadding: 14)
            HStack(spacing: 8) {
                WPhotoPlaceholder(icon: .car, tag: "Before").frame(height: 90)
                WPhotoPlaceholder(icon: .sparkle, tag: "After", tagTone: .ok).frame(height: 90)
                WPhotoPlaceholder(icon: .image).frame(height: 90).overlay(alignment: .bottom) {
                    Text("Yours").wText(.small).padding(.bottom, 14)
                }
            }
            .padding(.bottom, 16)
            WBanner(tone: .info, icon: .info, text: d?.decisionNote ?? "")
            Text("\(Fmt.rupees(o?.price ?? 149)) has been released to the captain.").wText(.caption).padding(.top, 16)
        } footer: {
            WStackedFooter {
                WButton("Okay") { router.popToRoot() }
                WButton("Talk to a person", kind: .text) { callSupport() }
            }
        }
    }

    func damage(_ o: Order?, _ d: Dispute?) -> some View {
        WScreen {
            header("Damage report")
        } content: {
            HStack(spacing: 12) {
                WBadge(text: "Priority", tone: .wait, icon: .eye)
                Text("Ref #\(d?.ref ?? "WH-20915")").wText(.caption)
            }
            .padding(.top, 14)
            WTitleBlock(title: "We’ll call you within 1 hour",
                        subtitle: "A real person from our team will go through this with you.", topPadding: 16)
            VStack(spacing: 0) {
                WListRow(icon: .shield, title: "\(o?.captain?.name ?? "Raju") is paused from new jobs", chevron: false)
                WDivider()
                WListRow(icon: .doc, title: "Evidence pack ready", subtitle: "Time-stamped photos, location and call log", chevron: false)
                WDivider()
                WListRow(icon: .rupee, title: "We help with the claim", subtitle: "Small damage paid from our protection fund", chevron: false)
            }
            .wOutlined(padding: 16)
        } footer: {
            WFooterBar(onCall: callSupport) {
                WButton("Download evidence pack", icon: .upload, kind: .outline) {}
            }
        }
    }
}

// MARK: C37 Refund status

struct RefundScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        let o = store.currentOrder
        let r = o?.refund
        WScreen {
            WAppBar(title: "Refund", onLeading: { router.pop() }, onTrailing: { router.push(.help) })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            Text("Refund amount").wText(.label).padding(.top, 18)
            Text(Fmt.rupees(r?.amount ?? 149)).wText(.bigMoney).wMoney().padding(.top, 2)
            HStack(spacing: 8) {
                WIconView(icon: .rupee, size: 12, color: WColor.onSuccess)
                Text(r?.credited == true ? "Refund done" : "Refund started").wText(.label, color: WColor.onSuccess)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading).frame(height: 30)
            .background(WColor.successTint, in: Capsule())
            .padding(.top, 10).padding(.bottom, 22)
            if r?.awaitingUPI == true {
                WBanner(tone: .wait, icon: .rupee, title: "We need your UPI ID.",
                        text: "Refunds go to UPI only for now. Add yours and we’ll send it right away.",
                        actionTitle: "Add UPI ID") { if let id = o?.id { router.push(.refundUPI(id)) } }
                    .padding(.bottom, 22)
            }
            WStatusSteps(steps: [
                .init(title: "Refund started", detail: "\(Fmt.date(r?.startedAt ?? Date())) · \(Fmt.time(r?.startedAt ?? Date()))"),
                .init(title: "With your bank", detail: "Usually 2 to 3 working days"),
                .init(title: "In your account", detail: r?.method ?? "Google Pay · ananya@okhdfc"),
            ], current: r?.credited == true ? 3 : (r?.awaitingUPI == true ? 0 : 1), spacing: 22)
            Text("Bank reference: \(r?.bankRef ?? "RZP8812093"). Not received by \(Fmt.date(Date().addingTimeInterval(4 * 86400)))? Call us.")
                .wText(.caption).padding(.top, 28)
        } footer: {
            WFooterBar(onCall: callSupport) { WButton("Done") { router.pop() } }
        }
    }
}
