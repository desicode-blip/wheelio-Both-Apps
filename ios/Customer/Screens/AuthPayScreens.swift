import SwiftUI
import Combine
import UserNotifications

extension Router {
    /// After login: back to Check and pay with the pay sheet open, or home.
    func finishLogin() {
        if let i = path.firstIndex(of: .review) {
            path = Array(path.prefix(i + 1))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.showPaySheet = true }
        } else {
            path = []
            tab = 0
        }
    }
}

/// Plain header with back and help, no title (login screens).
struct PlainHeader: View {
    @Environment(Router.self) var router
    var leading: WIcon? = .left
    var body: some View {
        WAppBar(leading: leading, onLeading: { router.pop() }, onTrailing: { router.push(.help) })
            .padding(.horizontal, 14)
            .padding(.top, 4)
    }
}

// MARK: C14 Log in (C14b invalid)

struct LoginScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var showError = false
    @State var phone = ""
    @State var error = false
    @State var loading = false

    var valid: Bool { Validators.isValidMobile(phone) }

    var body: some View {
        WScreen {
            PlainHeader()
        } content: {
            WTitleBlock(title: "Almost done. What’s your number?",
                        subtitle: store.returningCustomer ? "We’ll send a 6-digit code to find your account." : "We’ll send a 6-digit code. Then just your name.",
                        topPadding: 8)
            WSegmented(options: ["I’m new here", "I’ve booked before"],
                       selection: Binding(get: { store.returningCustomer ? 1 : 0 }, set: { store.returningCustomer = $0 == 1 }))
                .padding(.bottom, 18)
            WPhoneField(number: $phone, error: (error || showError) && !valid ? "Enter all 10 digits" : nil)
                .onChange(of: phone) { _, _ in error = false }
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Get code", enabled: !phone.isEmpty && (valid || !(error || showError)), loading: loading) { submit() }
            }
        }
        .onAppear { if showError && phone.isEmpty { phone = "98480112" } }
    }

    func submit() {
        guard valid else { error = true; return }
        loading = true
        Task {
            try? await store.requestOtp(String(Validators.digitsOnly(phone).prefix(10)))
            loading = false
            router.push(.otp(.entering))
        }
    }
}

// MARK: C15 Enter the code (C15b wrong, C15c expired)

struct OtpScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var start: OtpStart = .entering
    @State var code = ""
    @State var state: OtpStart = .entering
    @State var triesLeft = 2
    @State var seconds = 24
    @State var loading = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        WScreen {
            PlainHeader()
        } content: {
            Text("Enter the code").wText(.screen).padding(.top, 8)
            HStack(spacing: 4) {
                Text("Sent to \(Fmt.phone(store.pendingPhone.isEmpty ? AppStore.samplePhone : store.pendingPhone)).").wText(.body)
                WLink("Change") { router.pop() }
            }
            .padding(.top, 6).padding(.bottom, 22)
            WOtpField(code: $code, error: state == .wrong, boxSize: 46)
                .onChange(of: code) { _, new in
                    if state == .wrong && new.count < 6 { state = .entering }
                    if new.count == 6 { verify() }
                }
            switch state {
            case .entering:
                Text(seconds > 0 ? "Resend code in \(Fmt.clock(seconds))" : "")
                    .wText(.caption).padding(.top, 22)
                if seconds == 0 {
                    WLink("Resend code") { seconds = 30 }.padding(.top, 4)
                }
            case .wrong:
                HStack(spacing: 6) {
                    WIconView(icon: .warning, size: 13, color: WColor.destructive)
                    Text("That code doesn’t match. \(triesLeft) tries left.").wText(.caption, color: WColor.destructive)
                }
                .padding(.top, 18)
            case .expired:
                WBanner(tone: .wait, icon: .clock, text: "That code expired. Get a new one.", actionTitle: "Resend") {
                    state = .entering; code = ""; seconds = 30
                }
                .padding(.top, 22)
                WButton("Get the code on a call instead", kind: .text, fullWidth: false) {}
                    .padding(.top, 20)
            }
            Text("Demo code: 123456").wText(.caption, color: WColor.muted).padding(.top, 30)
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Verify", enabled: code.count == 6 && state == .entering, loading: loading) { verify() }
            }
        }
        .onAppear {
            state = start
            if start == .wrong { code = "482190" }
        }
        .onReceive(timer) { _ in if seconds > 0 { seconds -= 1 } }
    }

    func verify() {
        guard !loading, code.count == 6 else { return }
        loading = true
        Task {
            let r = try? await store.verifyOtp(code)
            loading = false
            switch r {
            case .ok(let isNew):
                // Returning customers: phone + code only. New customers also give their name.
                if isNew && !store.returningCustomer { router.push(.name) } else { router.finishLogin() }
            case .wrong(let left):
                triesLeft = left; state = .wrong
            case .expired:
                state = .expired; code = ""
            case .tooManyTries:
                state = .expired; code = ""
            case .none:
                router.push(.offline)
            }
        }
    }
}

// MARK: C16 Your name

struct NameScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var name = ""

    var body: some View {
        WScreen {
            PlainHeader()
        } content: {
            WTitleBlock(title: "What should we call you?", subtitle: "Your captain sees your first name only.", topPadding: 8)
            WTextField(label: "Your name", text: $name, placeholder: "Your name", capitalization: .words, focusOnAppear: true)
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Continue", enabled: Validators.isValidName(name)) {
                    Task {
                        try? await store.updateName(name)
                        router.finishLogin()
                    }
                }
            }
        }
        .onAppear { if name.isEmpty { name = store.customer?.name ?? "" } }
    }
}

// MARK: C17 Payment method sheet

struct PayMethodSheet: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        let price = store.draft.price
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pay \(Fmt.rupees(price))").wText(.section, weight: .semibold).wMoney()
                Spacer()
                WBadge(text: "Held until you approve", tone: .mute, icon: .shield)
            }
            .padding(.bottom, 4)
            ForEach(store.paymentMethods) { m in
                WSelectionTile(icon: .receipt, title: m.title, subtitle: m.detail, selected: store.payMethodId == m.id,
                               radio: true, iconTone: .mute) {
                    store.payMethodId = m.id
                }
            }
            WButton("Pay \(Fmt.rupees(price))", kind: .success) {
                router.showPaySheet = false
                router.push(.paying(.processing))
            }
            .padding(.top, 6)
            Text("Secured by Razorpay. Full refund if no captain comes.")
                .wText(.caption).frame(maxWidth: .infinity)
        }
    }
}

// MARK: C18 Paying (C18b failed, C18c pending)

struct PayingScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var initial: PayView = .processing
    @State var view: PayView = .processing
    @State var started = false
    @State var checking = false

    var body: some View {
        WScreen(scrolls: false) {
            if view == .processing { Color.clear.frame(height: 56) } else { PlainHeader() }
        } content: {
            switch view {
            case .processing:
                WFullState(icon: .clock, title: "Confirming payment", message: "Don’t close the app. This takes a few seconds.", spinning: true)
            case .failed:
                WFullState(icon: .receipt, tone: .error, title: "Payment didn’t go through",
                           message: "Your bank declined it. No money was taken. Try again or use another method.",
                           primary: "Try again", secondary: "Change method",
                           onPrimary: { store.demo.payment = .success; view = .processing; run() },
                           onSecondary: {
                               router.path.removeLast()
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.showPaySheet = true }
                           })
            case .pending:
                WFullState(icon: .clock, tone: .wait, title: "Waiting for your bank",
                           message: "We haven’t heard back yet. If money left your account, it will be refunded automatically within 3 days.",
                           primary: checking ? "Checking…" : "Check again", secondary: "Call support",
                           onPrimary: check, onSecondary: callSupport)
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            guard !started else { return }
            started = true
            view = initial
            if initial == .processing { run() }
        }
    }

    func run() {
        Task {
            let outcome = (try? await store.createOrderAndPay()) ?? .failed
            switch outcome {
            case .success: router.replace(with: [.booked])
            case .failed: view = .failed
            case .pending: view = .pending
            }
        }
    }

    func check() {
        checking = true
        Task {
            _ = try? await store.checkPendingPayment()
            checking = false
            router.replace(with: [.booked])
        }
    }
}

// MARK: C19 You're booked

struct BookedScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        let o = store.currentOrder
        WScreen {
            Color.clear.frame(height: 30)
        } content: {
            VStack(spacing: 0) {
                WStateCircle(icon: .check, tone: .ok).padding(.bottom, 20)
                Text("You’re booked").wText(.screen)
                // The booking details open tracking; there's no separate "Track" button.
                Button { track() } label: {
                    HStack(spacing: 6) {
                        Text("\(o?.slot.full ?? "Today, 8 – 10 AM") · \(o?.vehicle.plate ?? "TS 09 EA 4521")")
                            .wText(.body, color: WColor.heading)
                        WIconView(icon: .chevron, size: 11, color: WColor.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(WColor.canvas, in: Capsule())
                    .overlay(Capsule().strokeBorder(WColor.border))
                    .contentShape(Capsule())
                }
                .buttonStyle(WPressStyle())
                .accessibilityLabel("Track this booking")
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    WIconBox(icon: .whatsapp, size: 44, tone: .ok, radius: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("One last thing: your gate pass").wText(.title)
                        Text("We sent you a WhatsApp message").wText(.caption)
                    }
                }
                Text("Reply there with your MyGate or society entry pass, so the captain can get in.").wText(.body)
                WButton("Open WhatsApp", icon: .whatsapp, kind: .outline) { router.push(.whatsApp) }
            }
            .wCard(padding: 18)
            .padding(.bottom, 18)
            WBanner(tone: .info, icon: .search, text: "We’re finding a captain now. We’ll notify you when someone accepts.")
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Go home") { router.tab = 0; router.popToRoot() }
            }
        }
    }

    private func track() {
        if store.customer?.notificationsOn == true { router.replace(with: [.live]) }
        else { router.replace(with: [.notifyAsk]) }
    }
}

// MARK: C19b WhatsApp bot (reference)

struct WhatsAppReferenceScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        let o = store.currentOrder
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { router.pop() } label: { WIconView(icon: .left, size: 18).frame(width: 36, height: 44) }.buttonStyle(.plain)
                BrandMark(size: 26, showName: false)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Brand.name).wText(.title)
                    Text("Business account").wText(.caption)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.white)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    bubble(time: "7:42 AM") {
                        Text("Booking confirmed\n").font(WFont.of(.body, size: 14.5))
                        + Text("\(o?.vehicle.plate ?? "TS 09 EA 4521")").font(WFont.of(.body, weight: .bold, size: 14.5))
                        + Text(" · \(o?.vehicle.type.shortName ?? "Hatchback")\n\(o?.slot.full ?? "Today, 8 – 10 AM")\n\(o?.place.title ?? "My Home Avatar, Tower 3"), \(o?.place.parkingShort ?? "B2 slot 41")\n\(Fmt.rupees(o?.price ?? 149)) held safely")
                            .font(WFont.of(.body, size: 14.5))
                    }
                    bubble(time: "7:42 AM") {
                        Text("Please reply with your ").font(WFont.of(.body, size: 14.5))
                        + Text("society entry pass").font(WFont.of(.body, weight: .bold, size: 14.5))
                        + Text(" (MyGate, NoBrokerHood or a photo of the gate pass). The captain needs it to get in.").font(WFont.of(.body, size: 14.5))
                    }
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            WIconView(icon: .image, size: 20, color: WColor.secondary)
                            Text("MyGate pass").wText(.small)
                        }
                        .frame(width: 160, height: 110)
                        .background(WColor.photo, in: RoundedRectangle(cornerRadius: 10))
                        .padding(4)
                        .background(Color(hex: 0xDCF8C6), in: RoundedRectangle(cornerRadius: 12))
                    }
                    bubble(time: "7:44 AM") {
                        Text("Got it. Pass saved for this booking. We’ll share it with your captain only.").font(WFont.of(.body, size: 14.5))
                    }
                }
                .padding(16)
            }
            .background(Color(hex: 0xECE5DD))
            Text("Reference only: WhatsApp is outside the app. Message templates for the bot.")
                .wText(.caption).multilineTextAlignment(.center).padding(14)
        }
        .background(Color(hex: 0xECE5DD).ignoresSafeArea())
    }

    func bubble(time: String, text: () -> Text) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            text().foregroundStyle(WColor.heading).frame(maxWidth: .infinity, alignment: .leading)
            Text(time).wText(.small)
        }
        .padding(12)
        .frame(maxWidth: 260, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: C49 Notifications ask

struct NotifyAskScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        WScreen(scrolls: false) {
            PlainHeader()
        } content: {
            WFullState(icon: .bell, title: "Know when it’s done",
                       message: "We’ll tell you when a captain accepts and when the photos are ready. No spam.",
                       primary: "Turn on notifications", secondary: "Not now",
                       onPrimary: {
                           store.setNotifications(true)
                           router.replace(with: [.live])
                       },
                       onSecondary: { router.replace(with: [.live]) })
        }
    }
}

enum UNUserNotificationCenterShim {
    static func request() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
