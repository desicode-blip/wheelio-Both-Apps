import SwiftUI
import Observation

/// One route per captain screen ID (W01–W50). Suffixes b, h, t are states or
/// language variants of the same screen.
enum WRoute: Hashable {
    case welcome          // W00
    case signUp(login: Bool) // W02
    case otp(login: Bool) // W03
    case steps(problem: Bool) // W04, W15
    case aadhaar(unclear: Bool) // W05, W05b
    case selfie           // W06
    case bank             // W07
    case training         // W08
    case video(Int)       // W09
    case quiz             // W10
    case quizResult(passed: Bool) // W11, W11b
    case rules            // W12
    case underReview      // W13
    case live             // W14
    case jobAlert(batched: Bool) // W22, W22b, W22h, W22t
    case jobMissed        // W23
    case goToVehicle      // W26
    case gateProblem      // W27
    case cantFind         // W28
    case ownerCancelled   // W29
    case faceCheck        // W30
    case beforePhotos     // W31
    case camera(after: Bool, side: Int) // W32
    case photoDark        // W33
    case washing          // W34, W34b
    case afterPhotos      // W35
    case aiCheck          // W36
    case uploading        // W37
    case jobDone(late: Bool) // W38, W38b
    case payoutDetail     // W41
    case payoutHeld       // W42
    case level            // W43
    case probationExtended // W44
    case refresher        // W45
    case blocked          // W46
    case help             // W48
    case notifications    // W51
    case notificationSettings // W52
    case changePhone      // W53
    case editUPI          // W54
    case noShowCancelled  // W55
    case workArea         // W57
    case ownerNote        // W26n
    case helpFlow(CaptainHelpTopic) // W48a–d
    case gallery
}

@MainActor
@Observable
final class WRouter {
    var path: [WRoute] = []
    var tab = 0
    /// Index into the gallery while stepping through screens (demo only).
    var tour: Int? = nil
    var tourLang: Lang? = nil
    func push(_ r: WRoute) { path.append(r) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func home() { path = []; tab = 0 }
    func replace(_ r: [WRoute]) { path = r }
}

@main
struct CaptainApp: App {
    @State var store = CaptainStore()
    @State var router = WRouter()

    init() { WFont.register() }

    var body: some Scene {
        WindowGroup {
            CaptainRoot()
                .environment(store)
                .environment(router)
                .preferredColorScheme(.light)
                .tint(WColor.primary)
        }
    }
}

struct CaptainRoot: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        @Bindable var router = router
        ZStack {
            NavigationStack(path: $router.path) {
                Group {
                    if store.signedUp || store.exploring { CaptainTabs() } else { LanguageScreen() }
                }
                .navigationDestination(for: WRoute.self) { r in
                    destination(r).toolbar(.hidden, for: .navigationBar)
                }
            }
            WGalleryTab()
            WLiveBanner()
        }
        .onChange(of: scenePhase) { _, p in
            store.appIsActive = p == .active
            if p == .active { store.refreshSystemPermission() }
        }
        .onChange(of: store.registered) { _, on in
            if on && store.notifications.isEmpty { store.seedNotifications() }
        }
        .onAppear { store.refreshSystemPermission() }
    }

    @ViewBuilder func destination(_ r: WRoute) -> some View {
        switch r {
        case .welcome: WelcomeScreen()
        case .signUp(let l): SignUpScreen(login: l)
        case .otp(let l): WOtpScreen(login: l)
        case .steps(let p): StepsScreen(problem: p)
        case .aadhaar(let u): AadhaarScreen(unclear: u)
        case .selfie: SelfieScreen()
        case .bank: BankScreen()
        case .training: TrainingScreen()
        case .video(let i): VideoScreen(index: i)
        case .quiz: QuizScreen()
        case .quizResult(let p): QuizResultScreen(passed: p)
        case .rules: RulesScreen()
        case .underReview: UnderReviewScreen()
        case .live: LiveScreen()
        case .jobAlert(let b): JobAlertScreen(batched: b)
        case .jobMissed: JobMissedScreen()
        case .goToVehicle: GoToVehicleScreen()
        case .gateProblem: GateProblemScreen()
        case .cantFind: CantFindScreen()
        case .ownerCancelled: OwnerCancelledScreen()
        case .faceCheck: FaceCheckScreen()
        case .beforePhotos: JobPhotosScreen(after: false)
        case .camera(let after, let side): JobCameraScreen(after: after, side: side)
        case .photoDark: PhotoDarkScreen()
        case .washing: WashingScreen()
        case .afterPhotos: JobPhotosScreen(after: true)
        case .aiCheck: AiCheckScreen()
        case .uploading: UploadingScreen()
        case .jobDone(let late): JobDoneScreen(late: late)
        case .payoutDetail: PayoutDetailScreen()
        case .payoutHeld: PayoutHeldScreen()
        case .level: LevelScreen()
        case .probationExtended: ProbationScreen()
        case .refresher: RefresherScreen()
        case .blocked: BlockedScreen()
        case .help: WHelpScreen()
        case .notifications: WNotificationsScreen()
        case .notificationSettings: WNotificationSettingsScreen()
        case .changePhone: WChangePhoneScreen()
        case .editUPI: WEditUPIScreen()
        case .noShowCancelled: WNoShowCancelledScreen()
        case .workArea: WorkAreaScreen()
        case .ownerNote: OwnerNoteScreen()
        case .helpFlow(let t): HelpFlowScreen(topic: t)
        case .gallery: WGalleryScreen()
        }
    }
}

struct WGalleryTab: View {
    @Environment(WRouter.self) var router
    @Environment(CaptainStore.self) var store
    var body: some View {
        GeometryReader { geo in
            if let i = router.tour, router.path.last != .gallery {
                VStack(spacing: 4) {
                    Text(WGalleryScreen.all[i].id)
                        .font(WFont.of(.small, weight: .semibold, size: 11)).foregroundStyle(.white)
                    HStack(spacing: 0) {
                        tourButton("‹", to: i - 1)
                        tourButton("›", to: i + 1)
                    }
                }
                .padding(4)
                .background(WColor.inverse.opacity(0.72), in: UnevenRoundedRectangle(bottomTrailingRadius: 12, topTrailingRadius: 12))
                .position(x: 30, y: geo.size.height * 0.42 + 52)
            }
            Button {
                if router.path.last != .gallery { router.push(.gallery) }
            } label: {
                Text("Screens")
                    .font(WFont.of(.small, weight: .semibold, size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(WColor.inverse.opacity(0.72),
                                in: UnevenRoundedRectangle(bottomTrailingRadius: 12, topTrailingRadius: 12))
            }
            .buttonStyle(.plain)
            .position(x: 30, y: geo.size.height * 0.42)
        }
        .frame(width: 70)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ignoresSafeArea(.keyboard)
    }

    func tourButton(_ label: String, to j: Int) -> some View {
        let all = WGalleryScreen.all
        return Button {
            guard all.indices.contains(j) else { return }
            router.tour = j
            WGalleryScreen.open(all[j], store, router)
        } label: {
            Text(label).font(WFont.of(.body, weight: .bold, size: 18)).foregroundStyle(.white)
                .frame(width: 26, height: 30).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Shared captain chrome

/// Captain header: back, title (+ subtitle), help.
struct WHeader: View {
    @Environment(WRouter.self) var router
    var title: String = ""
    var subtitle: String? = nil
    var back = true
    var help = true

    var body: some View {
        WAppBar(title: title, subtitle: subtitle, leading: back ? .left : nil, trailing: help ? .help : nil,
                onLeading: { router.pop() }, onTrailing: { router.push(.help) })
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }
}

/// Captain footer: one big action, full width. No call button: support lives in
/// Help (the ? in the header and Me → Help).
struct WFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        WFooterBar(showCall: false, captain: true, content: content)
    }
}

/// Bigger, plainer type for the captain app (low cognitive load).
extension View {
    func wTitle() -> some View { self.wText(.screen, weight: .bold, size: 27) }
    func wBodyBig() -> some View { self.wText(.body, size: 17) }
}
