import SwiftUI

/// Screens gallery (demo only): opens every captain screen W01–W50 with sample data.
struct WGalleryScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    struct E: Identifiable {
        let id: String
        let title: String
        var prep: @MainActor (CaptainStore) -> Void = { _ in }
        var routes: [WRoute] = []
        var tab: Int? = nil
        /// 0 new (language), 1 guest exploring, 2 signed up (no KYC), 3 ready for jobs.
        var stage = 3
    }

    static var all: [E] { sections.flatMap { $0.1 } }

    static var sections: [(String, [E])] {
        [
            ("06 · Welcome, sign-up, KYC", [
                E(id: "W01", title: "Choose language", stage: 0),
                E(id: "W00", title: "Welcome: earnings and benefits", routes: [.welcome], stage: 0),
                E(id: "W00g", title: "Home as a guest (exploring)", tab: 0, stage: 1),
                E(id: "W00m", title: "Me as a guest", tab: 3, stage: 1),
                E(id: "W00j", title: "Jobs as a guest (example day)", tab: 1, stage: 1),
                E(id: "W02", title: "Sign up: name and number", routes: [.signUp(login: false)], stage: 1),
                E(id: "W02l", title: "Log in: number only", routes: [.signUp(login: true)], stage: 1),
                E(id: "W03", title: "Enter the code", routes: [.otp(login: false)], stage: 1),
                E(id: "W03h", title: "Home after sign-up (KYC card)", tab: 0, stage: 2),
                E(id: "W16", title: "Accept a job → quick KYC", prep: { $0.steps = [:]; $0.kycFromJob = true }, routes: [.steps(problem: false)], stage: 2),
                E(id: "W16a", title: "Job rings for a new captain (accept → KYC)", routes: [.jobAlert(batched: false)], stage: 2),
                E(id: "W04", title: "4 steps (process overview)", prep: { $0.steps = [:] }, routes: [.steps(problem: false)], stage: 2),
                E(id: "W05", title: "Verify Aadhaar", routes: [.aadhaar(unclear: false)], stage: 2),
                E(id: "W05b", title: "Aadhaar photo not clear", routes: [.aadhaar(unclear: true)], stage: 2),
                E(id: "W06", title: "Your photo (selfie)", routes: [.selfie], stage: 2),
                E(id: "W07", title: "Get paid (UPI or bank)", routes: [.bank], stage: 2),
                E(id: "W08", title: "Training videos", prep: { $0.videosWatched = 1 }, routes: [.training], stage: 2),
                E(id: "W09", title: "Video player", routes: [.video(1)], stage: 2),
                E(id: "W10", title: "Quiz", routes: [.quiz], stage: 2),
                E(id: "W11", title: "Quiz passed", routes: [.quizResult(passed: true)], stage: 2),
                E(id: "W11b", title: "Quiz failed", routes: [.quizResult(passed: false)], stage: 2),
                E(id: "W12", title: "Rules", routes: [.rules], stage: 2),
                E(id: "W13", title: "Verification call", routes: [.underReview], stage: 2),
                E(id: "W14", title: "You’re in", routes: [.live], stage: 2),
                E(id: "W15", title: "1 thing to fix (selfie mismatch)", routes: [.steps(problem: true)], stage: 2),
            ]),
            ("07 · Home and jobs", [
                E(id: "W20", title: "Home – offline", prep: { $0.online = false; $0.jobsToday = 0; $0.jobLimit = 2 }, tab: 0),
                E(id: "W21", title: "Home – online (a job rings in 4 s)", prep: { $0.online = true }, tab: 0),
                E(id: "W50", title: "Home – low battery, no internet", prep: { $0.online = true; $0.lowSignal = true }, tab: 0),
                E(id: "W22", title: "New job alert", routes: [.jobAlert(batched: false)]),
                E(id: "W22b", title: "New job alert – batched", routes: [.jobAlert(batched: true)]),
                E(id: "W22h", title: "New job alert – Hindi", prep: { $0.lang = .hi }, routes: [.jobAlert(batched: false)]),
                E(id: "W22t", title: "New job alert – Telugu", prep: { $0.lang = .te }, routes: [.jobAlert(batched: false)]),
                E(id: "W23", title: "Job went to someone else", routes: [.jobMissed]),
                E(id: "W24", title: "Daily limit reached", prep: { $0.online = true; $0.jobsToday = 4; $0.jobLimit = 4; $0.earnedToday = 464 }, tab: 0),
                E(id: "W25", title: "Today’s jobs", tab: 1),
                E(id: "W26", title: "Go to vehicle", routes: [.goToVehicle]),
                E(id: "W27", title: "Can’t get in (gate pass)", routes: [.goToVehicle, .gateProblem]),
                E(id: "W28", title: "Can’t find car", routes: [.goToVehicle, .cantFind]),
                E(id: "W29", title: "Owner cancelled", routes: [.ownerCancelled]),
                E(id: "W26n", title: "Didn’t show up: late → slot over → cancelled (≈20 s)", prep: { $0.noShowDemo = true }, routes: [.goToVehicle]),
                E(id: "W55", title: "Job cancelled: didn’t reach in time", prep: { $0.noShowCancelled = true; $0.noShowPlate = "TS 09 EA 4521" }, routes: [.noShowCancelled]),
            ]),
            ("08 · Wash and photos", [
                E(id: "W30", title: "Quick face check", routes: [.goToVehicle, .faceCheck]),
                E(id: "W31", title: "Before photos", prep: { $0.beforeDone = [0, 1] }, routes: [.goToVehicle, .beforePhotos]),
                E(id: "W32", title: "Camera – guided side", routes: [.goToVehicle, .beforePhotos, .camera(after: false, side: 2)]),
                E(id: "W33", title: "Photo too dark", routes: [.goToVehicle, .beforePhotos, .photoDark]),
                E(id: "W34", title: "Washing – timer", routes: [.goToVehicle, .washing]),
                E(id: "W34b", title: "Washing – late", prep: { $0.lateWash = true }, routes: [.goToVehicle, .washing]),
                E(id: "W35", title: "After photos", prep: { $0.afterDone = [0, 1, 2] }, routes: [.goToVehicle, .afterPhotos]),
                E(id: "W36", title: "AI photo check", prep: { $0.afterDone = [0, 1, 2, 3] }, routes: [.goToVehicle, .afterPhotos, .aiCheck]),
                E(id: "W37", title: "Sending photos (weak signal)", prep: { $0.lowSignal = true }, routes: [.uploading]),
                E(id: "W38", title: "Shine done", routes: [.jobDone(late: false)]),
                E(id: "W38b", title: "Done, late", routes: [.jobDone(late: true)]),
            ]),
            ("09 · Money, level, account", [
                E(id: "W40", title: "Money", tab: 2),
                E(id: "W41", title: "Payout detail", routes: [.payoutDetail]),
                E(id: "W42", title: "Money held", routes: [.payoutHeld]),
                E(id: "W43", title: "My level", routes: [.level]),
                E(id: "W44", title: "Probation extended", routes: [.probationExtended]),
                E(id: "W45", title: "Refresher video lock", routes: [.refresher]),
                E(id: "W46", title: "Account blocked, appeal", routes: [.blocked]),
                E(id: "W47", title: "Me (profile)", tab: 3),
                E(id: "W48", title: "Help (with Emergency)", routes: [.help]),
                E(id: "W51", title: "Notifications", prep: { $0.seedNotifications() }, routes: [.notifications]),
                E(id: "W51e", title: "Notifications – empty", prep: { $0.notifications = [] }, routes: [.notifications]),
                E(id: "W51o", title: "Notifications – alerts off", prep: { $0.seedNotifications(); $0.notificationsOn = false }, routes: [.notifications]),
                E(id: "W52", title: "Notification settings", routes: [.notificationSettings]),
                E(id: "W53", title: "Change phone number", routes: [.changePhone]),
                E(id: "W54", title: "Change payout UPI", routes: [.editUPI]),
                E(id: "W56", title: "Live banner: new job (in-app)", prep: { s in s.seedNotifications(); s.online = true; s.notify(.newJob, job: s.current) }, tab: 0),
            ]),
        ]
    }

    var body: some View {
        @Bindable var store = store
        WScreen(gutter: WSpace.gutterCaptain) {
            WAppBar(title: "Screens", subtitle: "Demo mode · sample data", trailing: nil, onLeading: { router.pop() })
        } content: {
            Text("Language").wText(.label).padding(.top, 10).padding(.bottom, 6)
            WSegmented(options: ["हिन्दी", "తెలుగు", "English"],
                       selection: Binding(get: { Lang.allCases.firstIndex(of: store.lang)! }, set: { store.lang = Lang.allCases[$0] }))
            VStack(spacing: 0) {
                Toggle("Dark photo on left side (W33)", isOn: $store.darkPhoto)
                Toggle("AI flags the left mirror (W36)", isOn: $store.aiFlag)
                Toggle("Wash runs late (W34b)", isOn: $store.lateWash)
                Toggle("Weak signal (W37, W50)", isOn: $store.lowSignal)
                Toggle("Batched job alert (W22b)", isOn: $store.batchedAlert)
            }
            .font(WFont.of(.body, size: 15)).tint(WColor.primary).padding(.top, 10)
            WButton("Reset demo", kind: .tonal) { store.resetDemo() }.padding(.vertical, 10)
            WButton("Step through all screens", kind: .tonal) { router.tour = 0; router.tourLang = store.lang; Self.open(Self.all[0], store, router) }.padding(.bottom, 10)
            ForEach(Self.sections, id: \.0) { s in
                Text(s.0).wText(.section, weight: .semibold).padding(.top, 20).padding(.bottom, 4)
                ForEach(s.1) { e in
                    Button { open(e) } label: {
                        HStack(spacing: 12) {
                            Text(e.id).wText(.label, color: WColor.primaryStrong).frame(width: 48, alignment: .leading)
                            Text(e.title).wText(.rowTitle)
                            Spacer()
                            WIconView(icon: .chevron, size: 12, color: WColor.secondary)
                        }
                        .padding(.vertical, 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    WDivider()
                }
            }
        }
    }

    func open(_ e: E) { router.tourLang = store.lang; router.tour = Self.all.firstIndex { $0.id == e.id }; Self.open(e, store, router) }

    static func open(_ e: E, _ store: CaptainStore, _ router: WRouter) {
        let lang = router.tourLang ?? store.lang
        store.resetDemo()
        store.lang = lang
        store.signedUp = e.stage >= 3
        store.registered = e.stage >= 2
        store.exploring = e.stage >= 1
        store.nudgeShown = true
        if e.stage >= 2 && store.notifications.isEmpty { store.seedNotifications() }
        e.prep(store)
        if let t = e.tab { router.home(); router.tab = t; return }
        router.replace(e.routes)
    }
}
