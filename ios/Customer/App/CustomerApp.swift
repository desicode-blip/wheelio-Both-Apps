import SwiftUI
import Observation

/// One route per screen ID (design read-me). Letter suffixes (b, c) are states
/// of the same screen and are not separate routes.
enum Route: Hashable {
    case welcome                       // C02
    case vehicleType(large: Bool)      // C05, C52
    case washType                      // Wash kind (after C05)
    case vehicleNumber                 // C06, C06b
    case photos                        // C07, C07b, C07c
    case camera(PhotoAngle, denied: Bool) // C08, C08b
    case location(off: Bool)           // C09, C09b
    case addressSearch                 // C09c
    case floorSlot                     // C10
    case entryNotes                    // C11
    case timeSlot                      // C12, C12b
    case review                        // C13 (+ C17 sheet)
    case login(error: Bool)            // C14, C14b
    case otp(OtpStart)                 // C15, C15b, C15c
    case name                          // C16
    case paying(PayView)               // C18, C18b, C18c
    case booked                        // C19
    case whatsApp                      // C19b
    case notifyAsk                     // C49
    case live                          // C20–C25, C28–C30 (one screen that follows the order)
    case photoCompare                  // C26
    case rate                          // C27
    case reportProblem                 // C31
    case problemPhotos(ProblemKind)    // C32
    case disputeStatus                 // C33–C36
    case refund                        // C37
    case bookingDetail(String)         // C44
    case repeatBooking(String)         // C45
    case help                          // C48
    case helpCaptain(HelpTopic)         // Help: sort it with your captain
    case helpEmergency                 // Help: emergencies only reach us
    case changePhone                   // Profile: change phone (OTP to new number)
    case notifications                 // Bell: notification centre
    case refundUPI(String?)            // Where to send a refund (order id), or edit saved UPI (nil)
    case notificationSettings          // Notification settings
    case offline                       // C50
    case serverError                   // C51
    case sessionExpired                // C54
    case gallery                       // Screens gallery (demo only)
}

enum OtpStart: Hashable { case entering, wrong, expired }
enum PayView: Hashable { case processing, failed, pending }

@MainActor
@Observable
final class Router {
    var path: [Route] = []
    var tab = 0
    var showSplash = true
    /// Pay sheet (C17) shown over Review.
    var showPaySheet = false

    func push(_ r: Route) { path.append(r) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = [] }
    func replace(with routes: [Route]) { path = routes }

    /// Go home and show a live order.
    func goLive() { path = [.live] }
}

@main
struct CustomerApp: App {
    @State var store = AppStore()
    @State var router = Router()

    init() { WFont.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .preferredColorScheme(.light)
                .tint(WColor.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        @Bindable var router = router
        ZStack {
            NavigationStack(path: $router.path) {
                Group {
                    if store.isLoggedIn || store.hasSeenWelcome {
                        MainTabs()
                    } else {
                        WelcomeScreen()
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    destination(route).toolbar(.hidden, for: .navigationBar)
                }
            }
            if router.showSplash {
                SplashScreen { withAnimation(.easeOut(duration: 0.3)) { router.showSplash = false } }
                    .transition(.opacity)
                    .zIndex(2)
            }
            GalleryTab().zIndex(3)
            LiveNotificationBanner().zIndex(4)
        }
        .onChange(of: scenePhase) { _, phase in
            store.appIsActive = phase == .active
            if phase == .active { store.refreshSystemPermission() }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .welcome: WelcomeScreen()
        case .vehicleType(let large): VehicleTypeScreen(largeText: large)
        case .washType: WashTypeScreen()
        case .vehicleNumber: VehicleNumberScreen()
        case .photos: PhotosScreen()
        case .camera(let angle, let denied): CameraScreen(angle: angle, forceDenied: denied)
        case .location(let off): LocationScreen(forceOff: off)
        case .addressSearch: AddressSearchScreen()
        case .floorSlot: FloorSlotScreen()
        case .entryNotes: EntryNotesScreen()
        case .timeSlot: TimeSlotScreen()
        case .review: ReviewScreen()
        case .login(let error): LoginScreen(showError: error)
        case .otp(let start): OtpScreen(start: start)
        case .name: NameScreen()
        case .paying(let v): PayingScreen(initial: v)
        case .booked: BookedScreen()
            .onAppear { store.viewingOrderId = store.currentOrderId }
            .onDisappear { if router.path.last != .live && router.path.last != .booked { store.viewingOrderId = nil } }
        case .whatsApp: WhatsAppReferenceScreen()
        case .notifyAsk: NotifyAskScreen()
        case .live: LiveOrderScreen()
            .onAppear { store.viewingOrderId = store.currentOrderId }
            .onDisappear { if router.path.last != .live && router.path.last != .booked { store.viewingOrderId = nil } }
        case .photoCompare: PhotoCompareScreen()
        case .rate: RateScreen()
        case .reportProblem: ReportProblemScreen()
        case .problemPhotos(let kind): ProblemPhotosScreen(kind: kind)
        case .disputeStatus: DisputeStatusScreen()
        case .refund: RefundScreen()
        case .bookingDetail(let id): BookingDetailScreen(orderId: id)
        case .repeatBooking(let id): RepeatScreen(vehicleId: id)
        case .help: HelpScreen()
        case .helpCaptain(let t): HelpCaptainScreen(topic: t)
        case .helpEmergency: EmergencyHelpScreen()
        case .changePhone: ChangePhoneScreen()
        case .notifications: NotificationsScreen()
        case .refundUPI(let id): RefundUPIScreen(orderId: id)
        case .notificationSettings: NotificationSettingsScreen()
        case .offline: OfflineScreen()
        case .serverError: ServerErrorScreen()
        case .sessionExpired: SessionExpiredScreen()
        case .gallery: GalleryScreen()
        }
    }
}

/// Small "Screens" tab on the left edge in demo mode that opens the screen gallery.
struct GalleryTab: View {
    @Environment(Router.self) var router

    var body: some View {
        GeometryReader { geo in
            Button {
                router.showSplash = false
                if router.path.last != .gallery { router.push(.gallery) }
            } label: {
                Text("Screens")
                    .font(WFont.of(.small, weight: .semibold, size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WColor.inverse.opacity(0.72),
                                in: UnevenRoundedRectangle(bottomTrailingRadius: 12, topTrailingRadius: 12))
            }
            .buttonStyle(.plain)
            .position(x: 30, y: geo.size.height * 0.42)
        }
        .allowsHitTesting(true)
        .frame(width: 70)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
