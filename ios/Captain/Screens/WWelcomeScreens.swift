import SwiftUI

// MARK: W00 Welcome: three slides, one idea each

/// Big picture, two short lines, a quiet "Next". The dots double as the timer:
/// each fills from the left in a few seconds, then the next slide comes.
struct WelcomeScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var index = 0
    @State private var progress: CGFloat = 0

    static let slideSeconds: Double = 3.5

    struct Slide { let art: WelcomeArt.Kind; let title: String; let line: String }

    var slides: [Slide] {
        [
            Slide(art: .freedom,
                  title: store.t("Work when you want", "जब चाहें, काम करें", "మీకు నచ్చినప్పుడు పని"),
                  line: store.t("Morning, evening or both. You decide.", "सुबह, शाम या दोनों। आप तय करें।", "ఉదయం, సాయంత్రం లేదా రెండూ. మీ ఇష్టం.")),
            Slide(art: .nearHome,
                  title: store.t("Jobs near your home", "घर के पास काम", "ఇంటి దగ్గరే పని"),
                  line: store.t("Cars parked in buildings close to you.", "आपके पास की बिल्डिंग में खड़ी गाड़ियाँ।", "మీ దగ్గరి భవనాల్లో పార్క్ చేసిన కార్లు.")),
            Slide(art: .evening,
                  title: store.t("Paid every night", "हर रात पैसे", "ప్రతి రాత్రి డబ్బు"),
                  line: store.t("Straight to your UPI. No waiting.", "सीधे आपके UPI में। कोई इंतज़ार नहीं।", "నేరుగా మీ UPI కి. ఎదురుచూపు లేదు.")),
        ]
    }

    var body: some View {
        let slide = slides[index]
        VStack(spacing: 0) {
            // Top bar: Back appears once we've moved past the first slide.
            HStack {
                if index > 0 {
                    Button { go(to: index - 1) } label: {
                        HStack(spacing: 4) {
                            WIconView(icon: .left, size: 15, color: WColor.heading, weight: .semibold)
                            Text(store.t("Back", "पीछे", "వెనక్కి")).wText(.body, color: WColor.heading)
                        }
                        .frame(height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, WSpace.gutterCaptain)

            WelcomeArt(kind: slide.art)
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .frame(maxHeight: .infinity)
                .padding(.horizontal, WSpace.gutterCaptain)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text(slide.title).wText(.screen, size: 26).multilineTextAlignment(.center)
                Text(slide.line).wBodyBig().multilineTextAlignment(.center).foregroundStyle(WColor.secondary)
            }
            .id("text\(index)")
            .transition(.opacity)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WSpace.gutterCaptain)
            .padding(.top, 28)

            TimerDots(count: slides.count, index: index, progress: progress)
                .padding(.top, 26)

            HStack {
                Button { enterApp() } label: {
                    Text(store.t("Skip", "छोड़ें", "దాటవేయి")).wText(.body, color: WColor.secondary)
                        .frame(height: 48).padding(.horizontal, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button { next() } label: {
                    HStack(spacing: 8) {
                        Text(store.t("Next", "आगे", "తదుపరి")).wText(.title, color: WColor.primaryStrong, size: 17)
                        WIconView(icon: .arrowRight, size: 15, color: WColor.primaryStrong, weight: .semibold)
                    }
                    .padding(.horizontal, 26).frame(height: 52)
                    .background(WColor.primaryTint, in: Capsule())
                }
                .buttonStyle(WPressStyle())
            }
            .padding(.horizontal, WSpace.gutterCaptain)
            .padding(.top, 26).padding(.bottom, 12)
        }
        .background(Color.white.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.4), value: index)
        .task(id: index) {
            // Fill the current dot, then move on (the last slide waits for Next).
            progress = 0
            let steps = 60
            for _ in 0..<steps {
                try? await Task.sleep(nanoseconds: UInt64(Self.slideSeconds / Double(steps) * 1_000_000_000))
                if Task.isCancelled { return }
                progress += 1 / CGFloat(steps)
            }
            progress = 1
            if index < slides.count - 1 { index += 1 }
        }
    }

    func go(to i: Int) { index = max(0, min(slides.count - 1, i)) }
    func next() { if index < slides.count - 1 { go(to: index + 1) } else { enterApp() } }
    func enterApp() { store.exploring = true; router.home() }
}

/// Three dots; the current one stretches and fills from the left like a timer.
struct TimerDots: View {
    let count: Int
    let index: Int
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                let w: CGFloat = i == index ? 30 : 8
                ZStack(alignment: .leading) {
                    Capsule().fill(i < index ? WColor.primary : WColor.border)
                    if i == index {
                        Capsule().fill(WColor.primary).frame(width: max(8, w * progress))
                    }
                }
                .frame(width: w, height: 8)
                .animation(.easeInOut(duration: 0.3), value: index)
            }
        }
        .accessibilityLabel("Slide \(index + 1) of \(count)")
    }
}

// MARK: Slide pictures (drawn, gently animated; no money shown)

struct WelcomeArt: View {
    enum Kind { case freedom, nearHome, evening }
    let kind: Kind
    @State private var on = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 32).fill(background)
                switch kind {
                case .freedom: freedom(w, h)
                case .nearHome: nearHome(w, h)
                case .evening: evening(w, h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { on = true } }
        .accessibilityHidden(true)
    }

    var background: LinearGradient {
        switch kind {
        case .freedom: return LinearGradient(colors: [Color(hex: 0xDCEBFF), Color(hex: 0xFFF3D6)], startPoint: .top, endPoint: .bottom)
        case .nearHome: return LinearGradient(colors: [Color(hex: 0xE3F6EE), Color(hex: 0xF4FBF7)], startPoint: .top, endPoint: .bottom)
        case .evening: return LinearGradient(colors: [Color(hex: 0x2B2F6B), Color(hex: 0x5A4E9A)], startPoint: .top, endPoint: .bottom)
        }
    }

    /// A man with open arms on a hill at sunrise, birds drifting.
    @ViewBuilder func freedom(_ w: CGFloat, _ h: CGFloat) -> some View {
        Circle().fill(Color(hex: 0xFFD27A)).frame(width: w * 0.36)
            .scaleEffect(on ? 1.06 : 0.96)
            .position(x: w * 0.72, y: h * 0.28)
        Circle().fill(Color(hex: 0xFFD27A).opacity(0.35)).frame(width: w * 0.54)
            .scaleEffect(on ? 1.08 : 0.94)
            .position(x: w * 0.72, y: h * 0.28)
        Image(systemName: "bird.fill").font(.system(size: 22)).foregroundStyle(Color(hex: 0x5E7087))
            .position(x: w * (on ? 0.30 : 0.24), y: h * (on ? 0.18 : 0.22))
        Image(systemName: "bird.fill").font(.system(size: 15)).foregroundStyle(Color(hex: 0x5E7087).opacity(0.7))
            .position(x: w * (on ? 0.44 : 0.38), y: h * (on ? 0.12 : 0.15))
        Ellipse().fill(Color(hex: 0x8FD3A7)).frame(width: w * 1.5, height: h * 0.5)
            .position(x: w * 0.5, y: h * 1.02)
        Ellipse().fill(Color(hex: 0x6CC28F)).frame(width: w * 1.1, height: h * 0.36)
            .position(x: w * 0.15, y: h * 1.04)
        Image(systemName: "figure.arms.open")
            .font(.system(size: h * 0.36, weight: .regular))
            .foregroundStyle(WColor.primaryStrong)
            .offset(y: on ? -4 : 4)
            .position(x: w * 0.48, y: h * 0.62)
    }

    /// A man walking a short path from home to the building next door.
    @ViewBuilder func nearHome(_ w: CGFloat, _ h: CGFloat) -> some View {
        Image(systemName: "building.2.fill").font(.system(size: h * 0.34))
            .foregroundStyle(Color(hex: 0x9CC9B5))
            .position(x: w * 0.76, y: h * 0.50)
        Image(systemName: "house.fill").font(.system(size: h * 0.20))
            .foregroundStyle(Color(hex: 0x6FB596))
            .position(x: w * 0.20, y: h * 0.58)
        Rectangle().fill(Color(hex: 0xCBE9DA)).frame(height: h * 0.22)
            .position(x: w * 0.5, y: h * 0.86)
        Path { p in
            p.move(to: CGPoint(x: w * 0.24, y: h * 0.76))
            p.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.76), control: CGPoint(x: w * 0.5, y: h * 0.84))
        }
        .stroke(Color(hex: 0x6FB596), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 12]))
        Image(systemName: "mappin.circle.fill").font(.system(size: 30))
            .foregroundStyle(WColor.primary)
            .offset(y: on ? -6 : 0)
            .position(x: w * 0.76, y: h * 0.20)
        Image(systemName: "figure.walk")
            .font(.system(size: h * 0.26))
            .foregroundStyle(WColor.primaryStrong)
            .position(x: w * (on ? 0.56 : 0.42), y: h * 0.64)
    }

    /// Home at night with family; the day's work is done.
    @ViewBuilder func evening(_ w: CGFloat, _ h: CGFloat) -> some View {
        Image(systemName: "moon.fill").font(.system(size: h * 0.12))
            .foregroundStyle(Color(hex: 0xFFE6A8))
            .rotationEffect(.degrees(-20))
            .position(x: w * 0.78, y: h * 0.18)
        ForEach(0..<6, id: \.self) { i in
            let xs: [CGFloat] = [0.14, 0.32, 0.52, 0.62, 0.22, 0.90]
            let ys: [CGFloat] = [0.14, 0.26, 0.10, 0.30, 0.38, 0.40]
            Image(systemName: "sparkle").font(.system(size: i % 2 == 0 ? 14 : 10))
                .foregroundStyle(.white.opacity(on == (i % 2 == 0) ? 0.95 : 0.35))
                .position(x: w * xs[i], y: h * ys[i])
        }
        Ellipse().fill(Color(hex: 0x3D3A7E)).frame(width: w * 1.4, height: h * 0.42)
            .position(x: w * 0.5, y: h * 1.02)
        Image(systemName: "figure.2.and.child.holdinghands")
            .font(.system(size: h * 0.34))
            .foregroundStyle(.white)
            .offset(y: on ? -2 : 2)
            .position(x: w * 0.46, y: h * 0.64)
        // A soft "done" notification: the day's money has arrived (no amount shown).
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(WColor.success)
            Text("UPI").font(WFont.of(.label, weight: .semibold, size: 13)).foregroundStyle(WColor.heading)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .scaleEffect(on ? 1 : 0.94)
        .position(x: w * 0.24, y: h * 0.24)
    }
}

// MARK: Light sign-up: name, number (W02) → code (W03)

/// Shown when a guest wants to go online, or from the nudge / Me tab.
struct SignUpScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var login = false
    @State private var name = ""
    @State private var number = ""
    @State private var focusNumber = false

    private var valid: Bool { Validators.isValidMobile(number) && (login || Validators.isValidName(name)) }

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: login ? store.t("Log in", "लॉग इन", "లాగిన్") : store.t("Sign up", "साइन अप", "సైన్ అప్"))
        } content: {
            Text(login ? store.t("Welcome back", "फिर से स्वागत है", "మళ్ళీ స్వాగతం")
                       : store.t("Save your spot", "अपनी जगह पक्की करें", "మీ స్థానం ఖాయం చేసుకోండి")).wTitle().padding(.top, 10)
            Text(login ? store.t("Enter your number. We send a code by SMS.", "अपना नंबर डालें। हम SMS से कोड भेजेंगे।", "మీ నంబర్ ఇవ్వండి. SMS ద్వారా కోడ్ పంపుతాము.")
                       : store.t("Just your name and number for now. Documents come later, only when you take your first job.",
                                 "अभी सिर्फ़ नाम और नंबर। कागज़ बाद में, जब आप पहला काम लेंगे।",
                                 "ఇప్పుడు పేరు, నంబర్ మాత్రమే. పత్రాలు తర్వాత, మొదటి పని తీసుకున్నప్పుడు."))
                .wBodyBig().padding(.top, 6).padding(.bottom, 22)
            if !login {
                // Name first (keyboard opens here), then Next moves to the number.
                WTextField(label: store.t("Your name", "आपका नाम", "మీ పేరు"), text: $name, placeholder: "Raju Yadav",
                           capitalization: .words, large: true, focusOnAppear: true, submitLabel: .next,
                           onSubmit: { focusNumber = false; DispatchQueue.main.async { focusNumber = true } })
                    .padding(.bottom, 16)
            }
            WPhoneField(number: $number, large: true, focusOnAppear: login, focusTrigger: focusNumber)
            Text(store.t("We send a code by SMS.", "हम SMS से कोड भेजेंगे।", "మేము SMS ద్వారా కోడ్ పంపుతాము.")).wText(.caption).padding(.top, 12)
        } footer: {
            WFooter {
                WButton(store.t("Get code", "कोड भेजें", "కోడ్ పొందండి"), size: .captain, enabled: valid) {
                    if !login { store.name = name.trimmingCharacters(in: .whitespaces) }
                    store.phone = String(Validators.digitsOnly(number).prefix(10))
                    router.push(.otp(login: login))
                }
            }
        }
    }
}

// MARK: Nudge after looking around for a while

struct SignUpNudgeSheet: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 14) {
            WStateCircle(icon: .sparkle, tone: .ok, size: 84).padding(.top, 26)
            Text(store.t("Like what you see?", "पसंद आया?", "నచ్చిందా?")).wText(.section, weight: .semibold, size: 22)
            Text(store.t("Add your name and number to save your spot. It takes 30 seconds.",
                         "अपनी जगह पक्की करने के लिए नाम और नंबर डालें। 30 सेकंड लगेंगे।",
                         "మీ స్థానం ఖాయం చేసుకోవడానికి పేరు, నంబర్ ఇవ్వండి. 30 సెకన్లు చాలు."))
                .wBodyBig().multilineTextAlignment(.center)
            Spacer(minLength: 0)
            WButton(store.t("Sign up", "साइन अप करें", "సైన్ అప్"), size: .captain) {
                dismiss()
                router.push(.signUp(login: false))
            }
            WButton(store.t("Later", "बाद में", "తర్వాత"), kind: .text) { dismiss() }
        }
        .padding(.horizontal, WSpace.gutterCaptain).padding(.bottom, 12)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: Guest notice used on Jobs and Money

struct GuestNotice: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WIconView(icon: .eye, size: 17, color: WColor.primaryStrong)
            VStack(alignment: .leading, spacing: 8) {
                Text(text).wText(.caption, color: WColor.inverse, size: 14.5)
                if !store.registered {
                    WLink(store.t("Sign up to start", "शुरू करने के लिए साइन अप करें", "మొదలుపెట్టడానికి సైన్ అప్"), type: .caption) {
                        router.push(.signUp(login: false))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16).background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
    }
}
