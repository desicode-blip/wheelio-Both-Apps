import SwiftUI
import UIKit

// MARK: Testing shortcut (remove before launch)

/// Testing only: skip the videos, quiz and the rest of onboarding, straight to "You're in".
/// Turn off by setting `TestFlags.onboardingSkip` to false.
enum TestFlags { static let onboardingSkip = true }

struct TestSkipButton: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        if TestFlags.onboardingSkip {
            Button {
                for s in KycStep.allCases { store.complete(s) }
                store.videosWatched = 3
                router.replace([.live])
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward.end.fill").font(.system(size: 12))
                    Text("TEST ONLY · Skip onboarding").font(WFont.of(.label, weight: .semibold, size: 13))
                }
                .foregroundStyle(Color(hex: 0xB45309))
                .padding(.horizontal, 14).frame(height: 36)
                .background(Color(hex: 0xFFF4E0), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: 0xB45309), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: W01 Choose your language

struct LanguageScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            EmptyView()
        } content: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(WColor.primary)
                    Circle().strokeBorder(.white, lineWidth: 3).frame(width: 18, height: 18)
                    Circle().fill(.white).frame(width: 6, height: 6)
                }
                .frame(width: 32, height: 32)
                Text(Brand.name).wText(.screen, size: 25)
            }
            .padding(.top, 24)
            WIconView(icon: .translate, size: 24, color: WColor.primaryStrong).padding(.top, 26)
            Text("Choose your language").wTitle().padding(.top, 8)
            Text("भाषा चुनें · భాష ఎంచుకోండి").wText(.caption).padding(.top, 2).padding(.bottom, 20)
            VStack(spacing: 12) {
                langTile(.en, "A", "English")
                langTile(.hi, "अ", "हिन्दी · Hindi")
                langTile(.te, "అ", "తెలుగు · Telugu")
            }
        } footer: {
            WFooter {
                WButton(store.t("Next", "आगे", "తదుపరి"), size: .captain) { router.push(.welcome) }
            }
        }
    }

    func langTile(_ l: Lang, _ glyph: String, _ title: String) -> some View {
        let on = store.lang == l
        return Button { store.lang = l } label: {
            HStack(spacing: 18) {
                Text(glyph).wText(.screen, size: 24).frame(width: 40)
                Text(title).wText(.value, size: 18)
                Spacer()
                WRadio(on: on)
            }
            .padding(.horizontal, 18)
            .frame(height: 78)
            .background(on ? WColor.primaryTint : .white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? WColor.primary : WColor.border, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(WPressStyle())
    }
}

// MARK: W03 Enter the code

struct WOtpScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var login = false
    @State var code = ""
    @State var reading = true

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: login ? store.t("Log in", "लॉग इन", "లాగిన్") : store.t("Sign up", "साइन अप", "సైన్ అప్"))
        } content: {
            WIconView(icon: .chat, size: 24, color: WColor.primaryStrong).padding(.top, 14)
            Text(store.t("Enter the code", "कोड डालें", "కోడ్ నమోదు చేయండి")).wTitle().padding(.top, 8)
            Text(store.t("Sent to", "भेजा गया", "పంపబడింది") + " " + Fmt.phoneShort(store.phone)).wBodyBig().padding(.top, 4).padding(.bottom, 20)
            WOtpField(code: $code, boxSize: 46, autoFocus: false)
            if reading {
                HStack(spacing: 10) {
                    WIconView(icon: .check, size: 15, color: WColor.heading)
                    Text(store.t("Reading the code from SMS…", "SMS से कोड पढ़ रहे हैं…", "SMS నుండి కోడ్ చదువుతోంది…")).wText(.caption, color: WColor.heading)
                    Spacer()
                }
                .padding(.horizontal, 16).frame(height: 44)
                .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 20)
            }
        } footer: {
            WFooter {
                WButton(store.t("Next", "आगे", "తదుపరి"), size: .captain, enabled: code.count == 6) {
                    // Demo: a returning captain has already done KYC.
                    if login { store.signedUp = true }
                    store.finishRegistration()
                    router.home()
                }
            }
        }
        .task {
            // Demo: auto-read the SMS code like Android's SMS Retriever.
            for d in "381624" {
                try? await Task.sleep(nanoseconds: 450_000_000)
                code.append(d)
            }
            reading = false
        }
    }
}

// MARK: W04 4 steps (W15 one thing to fix)

struct StepsScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var problem = false

    /// What the captain will go through. Information only: nothing here is tappable.
    enum Stage: CaseIterable { case aadhaar, photo, bank, onboarding }

    func info(_ s: Stage) -> (WIcon, String, String) {
        switch s {
        case .aadhaar: return (.idCard, store.t("Aadhaar", "आधार", "ఆధార్"),
                               store.t("Photo of the front and back", "आगे और पीछे की फ़ोटो", "ముందు, వెనుక ఫోటో"))
        case .photo: return (.face, store.t("Your photo", "आपकी फ़ोटो", "మీ ఫోటో"),
                             store.t("A quick selfie to match your Aadhaar", "आधार से मिलाने के लिए एक सेल्फ़ी", "ఆధార్‌తో సరిపోల్చడానికి ఒక సెల్ఫీ"))
        case .bank: return (.bank, store.t("Bank or UPI", "बैंक या UPI", "బ్యాంక్ లేదా UPI"),
                            store.t("Where your money comes every night", "जहाँ हर रात आपके पैसे आएंगे", "ప్రతి రాత్రి మీ డబ్బు వచ్చే చోటు"))
        case .onboarding: return (.play, store.t("Onboarding", "ऑनबोर्डिंग", "ఆన్‌బోర్డింగ్"),
                                  store.t("Short training videos and a quiz", "छोटे ट्रेनिंग वीडियो और एक क्विज़", "చిన్న శిక్షణ వీడియోలు, ఒక క్విజ్"))
        }
    }

    func state(_ s: Stage) -> StepState {
        if problem { return s == .photo ? .problem : .done }
        switch s {
        case .aadhaar: return store.steps[.aadhaar] ?? .todo
        case .photo: return store.steps[.photo] ?? .todo
        case .bank: return store.steps[.bank] ?? .todo
        case .onboarding: return store.steps[.training] == .done && store.steps[.quiz] == .done ? .done : .todo
        }
    }

    var body: some View {
        let list: [Stage] = problem ? [.aadhaar, .photo, .bank] : Stage.allCases
        let current = list.firstIndex { state($0) != .done }
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Quick KYC", "छोटा KYC", "చిన్న KYC"), back: !problem)
        } content: {
            if store.kycFromJob && !problem {
                HStack(alignment: .top, spacing: 12) {
                    WIconView(icon: .lock, size: 17, color: WColor.waitText)
                    Text(store.t("To accept jobs, finish these steps once. Owners only let verified captains in.",
                                 "काम लेने के लिए ये कदम एक बार पूरे करें। मालिक सिर्फ़ जाँचे गए कैप्टन को अंदर आने देते हैं।",
                                 "పనులు తీసుకోవడానికి ఈ దశలు ఒక్కసారి పూర్తి చేయండి. యజమానులు ధృవీకరించిన కెప్టెన్లనే అనుమతిస్తారు."))
                        .wText(.caption, color: WColor.waitText, size: 14.5)
                    Spacer(minLength: 0)
                }
                .padding(16).background(WColor.waitTint, in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 10)
            }
            if problem {
                Text(store.t("1 thing to fix", "1 चीज़ ठीक करें", "1 విషయం సరిచేయండి")).wTitle().padding(.top, 10)
                Text(store.t("We couldn’t match your selfie with Aadhaar.", "आपकी सेल्फ़ी आधार से मेल नहीं खाई।", "మీ సెల్ఫీ ఆధార్‌తో సరిపోలలేదు."))
                    .wBodyBig().padding(.top, 6).padding(.bottom, 26)
            } else {
                Text(store.t("4 steps to take jobs", "काम लेने के 4 कदम", "పనులు తీసుకోవడానికి 4 దశలు")).wTitle().padding(.top, 14)
                Text(store.t("Here’s what comes next. We’ll take you through each one.",
                             "आगे यह होगा। हम हर कदम में आपकी मदद करेंगे।",
                             "తర్వాత ఇవి ఉంటాయి. ప్రతి దశలో మేము మీకు సహాయం చేస్తాము."))
                    .wBodyBig().padding(.top, 6).padding(.bottom, 26)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.offset) { i, s in
                    let inf = info(s)
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            marker(inf.0, state(s), isCurrent: i == current)
                            if i < list.count - 1 {
                                Rectangle()
                                    .fill(state(s) == .done ? WColor.success : WColor.border)
                                    .frame(width: 2).frame(minHeight: 34)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(store.t("Step", "कदम", "దశ")) \(i + 1)").wText(.label, color: WColor.secondary)
                            Text(inf.1).wText(.title, color: i == current || state(s) == .problem ? WColor.heading : WColor.secondary,
                                              weight: i == current ? .semibold : .medium, size: 19)
                            Text(inf.2).wText(.caption, size: 14.5)
                        }
                        .padding(.top, 2).padding(.bottom, 22)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !problem { TestSkipButton().padding(.top, 4) }
        } footer: {
            WFooter {
                if problem {
                    WButton(store.t("Take photo again", "फिर से फ़ोटो लें", "మళ్ళీ ఫోటో తీయండి"), icon: .camera, size: .captain) { router.push(.selfie) }
                } else {
                    WButton(store.stepsDone == 0 ? store.t("Start", "शुरू करें", "ప్రారంభించండి") : store.t("Continue", "जारी रखें", "కొనసాగించండి"), size: .captain) {
                        switch store.nextStep {
                        case .aadhaar: router.push(.aadhaar(unclear: false))
                        case .photo: router.push(.selfie)
                        case .bank: router.push(.bank)
                        case .training: router.push(.training)
                        case .quiz: router.push(.quiz)
                        case .none: router.push(.rules)
                        }
                    }
                }
            }
        }
    }

    /// Round infographic on the left: done = green tick, now = filled blue, later = soft grey.
    @ViewBuilder func marker(_ icon: WIcon, _ st: StepState, isCurrent: Bool) -> some View {
        switch st {
        case .done:
            WIconView(icon: .check, size: 18, color: WColor.onSuccess, weight: .bold)
                .frame(width: 48, height: 48).background(WColor.success, in: Circle())
        case .problem:
            WIconView(icon: .warning, size: 18, color: WColor.destructive)
                .frame(width: 48, height: 48).background(WColor.errorTint, in: Circle())
        case .todo:
            WIconView(icon: icon, size: 20, color: isCurrent ? .white : WColor.secondary)
                .frame(width: 48, height: 48)
                .background(isCurrent ? WColor.primary : WColor.canvas, in: Circle())
                .overlay(Circle().strokeBorder(isCurrent ? .clear : WColor.border, lineWidth: 1.5))
        }
    }
}

// MARK: W05 Aadhaar (W05b photo not clear)

struct AadhaarScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var unclear = false

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Aadhaar", "आधार", "ఆధార్"))
        } content: {
            WSegmentBar(filled: 1, total: 5).padding(.top, 6)
            if unclear {
                Text(store.t("Photo is not clear", "फ़ोटो साफ़ नहीं है", "ఫోటో స్పష్టంగా లేదు")).wTitle().padding(.top, 22).padding(.bottom, 16)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12).fill(WColor.photo)
                    WIconView(icon: .idCard, size: 40, color: WColor.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                    WBadge(text: store.t("Blurry", "धुंधली", "అస్పష్టం"), tone: .error, icon: .close).padding(12)
                }
                .frame(height: 178)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WColor.destructive, lineWidth: 2))
                VStack(alignment: .leading, spacing: 14) {
                    tip(.sun, store.t("Stand in light", "रोशनी में खड़े हों", "వెలుతురులో నిలబడండి"))
                    tip(.idCard, store.t("All 4 corners inside", "चारों कोने अंदर हों", "నాలుగు మూలలు లోపల ఉండాలి"))
                    tip(.close, store.t("No finger on the card", "कार्ड पर उंगली न हो", "కార్డుపై వేలు ఉండకూడదు"))
                }
                .padding(.top, 22)
            } else {
                WIconView(icon: .idCard, size: 26, color: WColor.primaryStrong).padding(.top, 22)
                Text(store.t("Verify Aadhaar", "आधार सत्यापित करें", "ఆధార్ ధృవీకరించండి")).wTitle().padding(.top, 8)
                Text(store.t("Fastest with DigiLocker. Takes 1 minute.", "DigiLocker से सबसे जल्दी। 1 मिनट लगेगा।", "DigiLocker తో వేగంగా. 1 నిమిషం పడుతుంది."))
                    .wBodyBig().padding(.top, 4).padding(.bottom, 18)
                HStack(spacing: 12) {
                    WIconView(icon: .shield, size: 17, color: WColor.heading)
                    Text(store.t("We only see your name, photo and age.", "हम सिर्फ़ आपका नाम, फ़ोटो और उम्र देखते हैं।", "మేము మీ పేరు, ఫోటో, వయసు మాత్రమే చూస్తాము."))
                        .wText(.caption, color: WColor.heading, size: 14.5)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(WColor.canvas, in: RoundedRectangle(cornerRadius: 14))
                WButton(store.t("Upload Aadhaar photo instead", "आधार की फ़ोटो अपलोड करें", "ఆధార్ ఫోటో అప్‌లోడ్ చేయండి"), kind: .text, fullWidth: false) {
                    router.push(.aadhaar(unclear: true))
                }
                .padding(.top, 14)
            }
        } footer: {
            WFooter {
                if unclear {
                    WButton(store.t("Take again", "फिर से लें", "మళ్ళీ తీయండి"), icon: .camera, size: .captain) {
                        store.complete(.aadhaar)
                        router.replace([.steps(problem: false)])
                    }
                } else {
                    WButton(store.t("Open DigiLocker", "DigiLocker खोलें", "DigiLocker తెరవండి"), size: .captain) {
                        store.complete(.aadhaar)
                        router.replace([.steps(problem: false)])
                    }
                }
            }
        }
    }

    func tip(_ icon: WIcon, _ text: String) -> some View {
        HStack(spacing: 12) {
            WIconView(icon: icon, size: 17, color: WColor.primaryStrong)
            Text(text).wText(.bodyStrong, color: WColor.heading, size: 16.5)
        }
    }
}

// MARK: W06 Your photo (selfie)

struct SelfieScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        VStack(spacing: 0) {
            WAppBar(title: store.t("Your photo", "आपकी फ़ोटो", "మీ ఫోటో"), trailing: nil, dark: true, onLeading: { router.pop() })
                .padding(.horizontal, 4)
            Spacer()
            ZStack {
                Ellipse().stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [7, 6])).frame(width: 226, height: 296)
                WIconView(icon: .face, size: 60, color: .white.opacity(0.85))
            }
            Spacer()
            Text(store.t("Face inside the oval. No cap, no mask.", "चेहरा ओवल के अंदर। टोपी या मास्क नहीं।", "ముఖం ఓవల్ లోపల. టోపీ, మాస్క్ వద్దు."))
                .wText(.value, color: .white, size: 16.5).multilineTextAlignment(.center).padding(.horizontal, 20)
            Button {
                store.complete(.photo)
                router.replace([.steps(problem: false)])
            } label: {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 5).frame(width: 84, height: 84)
                    Circle().fill(.white).frame(width: 66, height: 66)
                }
            }
            .accessibilityLabel("Take photo")
            .padding(.vertical, 22)
        }
        .background(WColor.camera.ignoresSafeArea())
    }
}

// MARK: W07 Get paid (bank or UPI)

struct BankScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var mode = 0
    @State var upi = "raju.yadav@ybl"
    @State var account = ""

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Get paid", "पैसे पाएं", "డబ్బు పొందండి"))
        } content: {
            WSegmentBar(filled: 3, total: 5).padding(.top, 6)
            WIconView(icon: .rupee, size: 24, color: WColor.primaryStrong).padding(.top, 22)
            Text(store.t("Where should we send money?", "पैसे कहाँ भेजें?", "డబ్బు ఎక్కడికి పంపాలి?")).wTitle().padding(.top, 8).padding(.bottom, 18)
            WSegmented(options: ["UPI", store.t("Bank account", "बैंक खाता", "బ్యాంక్ ఖాతా")], selection: $mode, height: 54)
                .padding(.bottom, 22)
            if mode == 0 {
                WTextField(label: "UPI ID", text: $upi, placeholder: "name@bank", large: true)
                if upi.contains("@") {
                    HStack(spacing: 10) {
                        WIconView(icon: .check, size: 15, color: WColor.onSuccess)
                        (Text(store.t("Name matches: ", "नाम मिलता है: ", "పేరు సరిపోయింది: ")) + Text("RAJU YADAV").bold())
                            .wText(.caption, color: WColor.onSuccess, size: 14.5)
                        Spacer()
                    }
                    .padding(.horizontal, 16).frame(height: 46)
                    .background(WColor.successTint, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 20)
                }
            } else {
                WTextField(label: store.t("Account number", "खाता नंबर", "ఖాతా నంబర్"), text: $account, placeholder: "0000 0000 0000",
                           keyboard: .numberPad, large: true)
            }
        } footer: {
            WFooter {
                WButton(store.t("Save", "सेव करें", "సేవ్ చేయండి"), size: .captain, enabled: mode == 0 ? upi.contains("@") : account.count >= 9) {
                    store.upi = upi
                    store.complete(.bank)
                    router.replace([.steps(problem: false)])
                }
            }
        }
    }
}

// MARK: W08 Training videos

struct TrainingScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var videos: [(String, String)] {
        [(store.t("Car wash: step by step", "कार धुलाई: एक-एक कदम", "కార్ వాష్: దశలవారీగా"), "4 min"),
         (store.t("Bike wash", "बाइक धुलाई", "బైక్ వాష్"), "3 min"),
         (store.t("Do’s and don’ts", "क्या करें, क्या नहीं", "చేయాల్సినవి, చేయకూడనివి"), "2 min")]
    }

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Training", "ट्रेनिंग", "శిక్షణ"), subtitle: store.langName)
        } content: {
            WSegmentBar(filled: 4, total: 5).padding(.top, 6)
            Text(store.t("Watch 3 short videos", "3 छोटे वीडियो देखें", "3 చిన్న వీడియోలు చూడండి")).wTitle().padding(.top, 20)
            Text(store.t("Then a 2-minute quiz.", "फिर 2 मिनट का क्विज़।", "తర్వాత 2 నిమిషాల క్విజ్.")).wBodyBig().padding(.top, 4).padding(.bottom, 18)
            VStack(spacing: 12) {
                ForEach(Array(videos.enumerated()), id: \.offset) { i, v in
                    Button { if i <= store.videosWatched { router.push(.video(i)) } } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(WColor.inverse)
                                Image(systemName: "play.fill").font(.system(size: 20)).foregroundStyle(.white)
                            }
                            .frame(width: 96, height: 64)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.0).wText(.title, size: 16.5).fixedSize(horizontal: false, vertical: true)
                                Text(v.1).wText(.caption)
                            }
                            Spacer(minLength: 4)
                            if i < store.videosWatched {
                                ZStack { Circle().fill(WColor.success); WIconView(icon: .check, size: 14, color: WColor.onSuccess, weight: .bold) }
                                    .frame(width: 32, height: 32)
                            } else if i == store.videosWatched {
                                WBadge(text: store.t("Watch", "देखें", "చూడండి"), tone: .info, icon: .check)
                            } else {
                                ZStack { Circle().strokeBorder(WColor.muted); WIconView(icon: .lock, size: 13, color: WColor.muted) }
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(WColor.border))
                    }
                    .buttonStyle(WPressStyle())
                }
            }
            TestSkipButton().padding(.top, 20)
        } footer: {
            WFooter {
                if store.videosWatched >= 3 {
                    WButton(store.t("Start quiz", "क्विज़ शुरू करें", "క్విజ్ ప్రారంభించండి"), size: .captain) {
                        store.complete(.training)
                        router.push(.quiz)
                    }
                } else {
                    WButton(store.t("Watch next", "अगला देखें", "తదుపరి చూడండి"), icon: .play, size: .captain) {
                        router.push(.video(store.videosWatched))
                    }
                }
            }
        }
    }
}

// MARK: W09 Video player

struct VideoScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let index: Int
    @State var progress: Double = 0
    @State var playing = true

    var body: some View {
        let titles = [store.t("Car wash", "कार धुलाई", "కార్ వాష్"), store.t("Bike wash", "बाइक धुलाई", "బైక్ వాష్"), store.t("Do’s and don’ts", "क्या करें, क्या नहीं", "చేయాల్సినవి")]
        WScreen(gutter: 0) {
            WHeader(title: titles[min(index, 2)])
        } content: {
            ZStack(alignment: .bottom) {
                WColor.camera
                Button { playing.toggle() } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 26)).foregroundStyle(.white)
                        .frame(width: 72, height: 72).background(.white.opacity(0.18), in: Circle())
                }
                .frame(maxHeight: .infinity)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3))
                        Capsule().fill(WColor.primary).frame(width: g.size.width * progress)
                    }
                }
                .frame(height: 4).padding(.horizontal, 12).padding(.bottom, 14)
            }
            .frame(height: 202)
            VStack(alignment: .leading, spacing: 14) {
                Text(store.t("In this video", "इस वीडियो में", "ఈ వీడియోలో")).wText(.section, weight: .semibold)
                point(.bucket, store.t("Clean water, clean bucket", "साफ़ पानी, साफ़ बाल्टी", "శుభ్రమైన నీరు, శుభ్రమైన బకెట్"))
                point(.wipe, store.t("Wet cloth first, then dry", "पहले गीला कपड़ा, फिर सूखा", "ముందు తడి గుడ్డ, తర్వాత పొడి"))
                point(.close, store.t("Never wipe a dry, dusty bike", "सूखी, धूल भरी बाइक कभी न पोंछें", "పొడి, దుమ్ము బైక్‌ను ఎప్పుడూ తుడవకండి"))
                Text(store.t("Must watch till the end. You can’t skip.", "आख़िर तक देखना ज़रूरी है। छोड़ नहीं सकते।", "చివరి వరకు చూడాలి. దాటవేయలేరు."))
                    .wText(.caption).padding(.top, 4)
                TestSkipButton().padding(.top, 8)
            }
            .padding(16)
        } footer: {
            WFooter {
                WButton(store.t("Next video", "अगला वीडियो", "తదుపరి వీడియో"), size: .captain, enabled: progress >= 1) {
                    store.videosWatched = max(store.videosWatched, index + 1)
                    router.pop()
                }
            }
        }
        .task {
            // Demo: a 6-second stand-in for the YouTube player (official player only, never downloaded).
            while progress < 1 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if playing { progress = min(1, progress + 1.0 / 60) }
            }
        }
    }

    func point(_ icon: WIcon, _ text: String) -> some View {
        HStack(spacing: 14) {
            WIconBox(icon: icon, size: 40, radius: 20)
            Text(text).wText(.bodyStrong, color: WColor.heading, size: 16.5)
        }
    }
}

// MARK: W10 Quiz

struct QuizScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var q = 0
    @State var pick: Int? = nil
    @State var correct = 0

    struct Q { let text: (String, String, String); let a: (String, String, String, WIcon); let b: (String, String, String, WIcon); let right: Int }

    var questions: [Q] {
        [
            Q(text: ("Where do you take before photos?", "पहले की फ़ोटो कहाँ लेते हैं?", "ముందు ఫోటోలు ఎక్కడ తీస్తారు?"),
              a: ("At the vehicle", "गाड़ी के पास", "వాహనం దగ్గర", .car), b: ("At home", "घर पर", "ఇంట్లో", .home), right: 0),
            Q(text: ("The bike is dusty. What do you do first?", "बाइक पर धूल है। पहले क्या करेंगे?", "బైక్ దుమ్ముగా ఉంది. ముందు ఏం చేస్తారు?"),
              a: ("Pour water", "पानी डालें", "నీళ్ళు పోయండి", .drop), b: ("Wipe with dry cloth", "सूखे कपड़े से पोंछें", "పొడి గుడ్డతో తుడవండి", .wipe), right: 0),
            Q(text: ("Can you use soap?", "क्या साबुन लगा सकते हैं?", "సబ్బు వాడవచ్చా?"),
              a: ("Yes", "हाँ", "అవును", .check), b: ("No, water only", "नहीं, सिर्फ़ पानी", "లేదు, నీళ్ళు మాత్రమే", .bucket), right: 1),
            Q(text: ("Owner wants to pay cash. You…", "मालिक नकद देना चाहे तो…", "యజమాని నగదు ఇవ్వాలనుకుంటే…"),
              a: ("Say no, app only", "मना करें, सिर्फ़ ऐप", "వద్దు అనండి, యాప్ మాత్రమే", .ban), b: ("Take it", "ले लें", "తీసుకోండి", .rupee), right: 0),
            Q(text: ("You’ll be 10 minutes late. You…", "आप 10 मिनट लेट होंगे तो…", "మీరు 10 నిమిషాలు ఆలస్యం అయితే…"),
              a: ("Tell the app", "ऐप में बताएं", "యాప్‌లో చెప్పండి", .phone), b: ("Say nothing", "कुछ न कहें", "ఏమీ చెప్పకండి", .close), right: 0),
        ]
    }

    var body: some View {
        let cur = questions[q]
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Quiz", "क्विज़", "క్విజ్"), subtitle: store.t("Question \(q + 1) of 5", "प्रश्न \(q + 1) / 5", "ప్రశ్న \(q + 1) / 5"))
        } content: {
            WSegmentBar(filled: q + 1, total: 5).padding(.top, 6)
            HStack(alignment: .top, spacing: 14) {
                WIconBox(icon: .refresh, size: 52, radius: 26)
                Text(store.t(cur.text.0, cur.text.1, cur.text.2)).wText(.section, weight: .semibold, size: 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20).padding(.bottom, 18)
            HStack(spacing: 12) {
                option(0, cur.a, right: cur.right)
                option(1, cur.b, right: cur.right)
            }
            if let p = pick { feedback(p == cur.right, cur) }
            if pick == nil {
            VStack(spacing: 8) {
                Button {} label: {
                    WIconView(icon: .mic, size: 30, color: .white).frame(width: 80, height: 80).background(WColor.primary, in: Circle())
                }
                .accessibilityLabel("Say your answer")
                Text(store.t("Or tap and say your answer", "या टैप करके जवाब बोलें", "లేదా నొక్కి జవాబు చెప్పండి")).wText(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            }
            TestSkipButton().padding(.top, 20)
        } footer: {
            WFooter {
                WButton(store.t("Next", "आगे", "తదుపరి"), size: .captain, enabled: pick != nil) {
                    if pick == cur.right { correct += 1 }
                    if q < 4 { q += 1; pick = nil } else {
                        let passed = correct >= 4
                        if passed { store.complete(.quiz) }
                        router.push(.quizResult(passed: passed))
                    }
                }
            }
        }
    }

    /// Once answered, the choice locks: the right option turns green (with a tick),
    /// a wrong pick turns red so the captain sees what the correct answer was.
    func option(_ i: Int, _ o: (String, String, String, WIcon), right: Int) -> some View {
        let answered = pick != nil
        let isRight = i == right
        let picked = pick == i
        let tone: Color = !answered ? WColor.border : (isRight ? WColor.success : (picked ? WColor.destructive : WColor.border))
        let fill: Color = !answered ? .white : (isRight ? WColor.successTint : (picked ? WColor.errorTint : .white))
        return Button {
            guard pick == nil else { return }
            withAnimation(.spring(duration: 0.3)) { pick = i }
            UINotificationFeedbackGenerator().notificationOccurred(isRight ? .success : .error)
        } label: {
            VStack(spacing: 12) {
                WIconView(icon: o.3, size: 24, color: WColor.primaryStrong)
                    .frame(width: 60, height: 60).background(answered ? WColor.white : WColor.primaryTint, in: Circle())
                Text(store.t(o.0, o.1, o.2)).wText(.title, size: 16).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).frame(height: 142)
            .background(fill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tone, lineWidth: answered && (isRight || picked) ? 3 : 1))
            .overlay(alignment: .topTrailing) {
                if answered && (isRight || picked) {
                    WIconView(icon: isRight ? .check : .close, size: 13, color: .white, weight: .bold)
                        .frame(width: 28, height: 28)
                        .background(isRight ? WColor.success : WColor.destructive, in: Circle())
                        .padding(10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .opacity(answered && !isRight && !picked ? 0.55 : 1)
        }
        .buttonStyle(WPressStyle())
        .disabled(answered && !picked && !isRight)
    }

    func feedback(_ ok: Bool, _ cur: Q) -> some View {
        let rightText = cur.right == 0 ? store.t(cur.a.0, cur.a.1, cur.a.2) : store.t(cur.b.0, cur.b.1, cur.b.2)
        return HStack(alignment: .top, spacing: 12) {
            WIconView(icon: ok ? .checkCircle : .warning, size: 22, color: ok ? WColor.success : WColor.destructive)
            VStack(alignment: .leading, spacing: 3) {
                Text(ok ? store.t("Correct!", "सही जवाब!", "సరైన జవాబు!") : store.t("Not quite", "सही नहीं", "సరైనది కాదు"))
                    .wText(.title, color: ok ? WColor.onSuccess : WColor.destructive, size: 17)
                if !ok {
                    Text(store.t("The right answer is: \(rightText)", "सही जवाब है: \(rightText)", "సరైన జవాబు: \(rightText)"))
                        .wText(.body, color: WColor.heading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(ok ? WColor.successTint : WColor.errorTint, in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: W11 Passed (W11b failed)

struct QuizResultScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let passed: Bool

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) {
            EmptyView()
        } content: {
            if passed {
                WFullState(icon: .check, tone: .ok, title: store.t("Passed! 5 of 5", "पास! 5 में से 5", "పాస్! 5 లో 5"),
                           message: store.t("Next: the rules. Then we verify you.", "आगे: नियम। फिर हम आपकी जाँच करेंगे।", "తర్వాత: నియమాలు. ఆపై మిమ్మల్ని ధృవీకరిస్తాము."),
                           captain: true)
            } else {
                WFullState(icon: .refresh, tone: .wait, title: store.t("3 of 5. Almost!", "5 में से 3. लगभग!", "5 లో 3. దాదాపు!"),
                           message: store.t("Watch the bike video again, then try the quiz once more.", "बाइक वाला वीडियो फिर देखें, फिर दोबारा क्विज़ दें।", "బైక్ వీడియో మళ్ళీ చూసి, మళ్ళీ క్విజ్ ప్రయత్నించండి."),
                           primary: store.t("Watch again", "फिर से देखें", "మళ్ళీ చూడండి"), primaryIcon: .play, captain: true,
                           onPrimary: { router.replace([.video(1)]) })
            }
        } footer: {
            if passed {
                WFooter {
                    WButton(store.t("See the rules", "नियम देखें", "నియమాలు చూడండి"), size: .captain) { router.push(.rules) }
                }
            }
        }
    }
}

// MARK: W12 Rules

struct RulesScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Rules", "नियम", "నియమాలు"))
        } content: {
            Text(store.t("How you earn here", "यहाँ कमाई कैसे होती है", "ఇక్కడ ఎలా సంపాదిస్తారు")).wTitle().padding(.top, 10).padding(.bottom, 14)
            VStack(spacing: 10) {
                rule(.rupee, "₹116", .ok, store.t("Your pay for a hatchback. Shown before you accept.", "हैचबैक के लिए आपकी कमाई। स्वीकार करने से पहले दिखेगी।", "హ్యాచ్‌బ్యాక్‌కు మీ సంపాదన. అంగీకరించే ముందు చూపిస్తాము."))
                rule(.clock, "12 AM", .ok, store.t("Paid to UPI the same night, after the owner approves", "मालिक के मंज़ूर करने के बाद उसी रात UPI में", "యజమాని ఆమోదించాక అదే రాత్రి UPI కి"))
                rule(.star, "4★+", .info, store.t("Every wash must get 4 stars or more", "हर धुलाई पर 4 या ज़्यादा स्टार चाहिए", "ప్రతి వాష్‌కి 4 లేదా ఎక్కువ స్టార్లు రావాలి"))
                rule(.stopwatch, "−₹1", .error, store.t("For every minute late. Max 30% of pay.", "हर मिनट देरी पर। ज़्यादा से ज़्यादा 30%।", "ప్రతి నిమిషం ఆలస్యానికి. గరిష్టం 30%."))
                rule(.ban, store.t("Out", "बाहर", "తొలగింపు"), .error, store.t("Damage on purpose or taking customers outside the app", "जानबूझकर नुकसान या ग्राहक को ऐप से बाहर ले जाना", "కావాలని నష్టం లేదా కస్టమర్‌ను యాప్ బయటకు తీసుకెళ్ళడం"))
            }
        } footer: {
            WFooter {
                WButton(store.t("I agree", "मैं सहमत हूँ", "నేను అంగీకరిస్తున్నాను"), icon: .check, size: .captain) { router.push(.underReview) }
            }
        }
    }

    func rule(_ icon: WIcon, _ big: String, _ tone: WTone, _ text: String) -> some View {
        HStack(spacing: 14) {
            WIconView(icon: icon, size: 22, color: tone == .ok ? WColor.heading : tone.foreground)
            Text(big).wText(.section, color: tone == .error ? WColor.destructive : (tone == .info ? WColor.primaryStrong : WColor.heading), weight: .bold)
                .frame(width: 70, alignment: .leading)
            Text(text).wText(.caption, color: WColor.heading, size: 14.5).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: W13 Under review (video call)

struct UnderReviewScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) {
            WHeader(title: store.t("Get ready", "तैयार हो जाइए", "సిద్ధం అవ్వండి"), back: false)
        } content: {
            VStack(spacing: 16) {
                Spacer()
                WStateCircle(icon: .phone, size: 112)
                Text(store.t("We’ll call you today", "हम आज आपको कॉल करेंगे", "మేము ఈరోజు మీకు కాల్ చేస్తాము")).wText(.section, weight: .semibold, size: 23)
                Text(store.t("A 10-minute video call to check your documents. Keep your Aadhaar ready.", "दस्तावेज़ जाँचने के लिए 10 मिनट की वीडियो कॉल। आधार तैयार रखें।", "మీ పత్రాలు చూడటానికి 10 నిమిషాల వీడియో కాల్. ఆధార్ సిద్ధంగా ఉంచుకోండి."))
                    .wBodyBig().multilineTextAlignment(.center)
                Text(store.t("Today, 3 – 5 PM", "आज, 3 – 5 PM", "ఈరోజు, 3 – 5 PM")).wText(.section, weight: .semibold)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(WColor.canvas, in: RoundedRectangle(cornerRadius: 14))
                Button { router.replace([.live]) } label: {
                    Text("Demo: call done →").wText(.caption, color: WColor.muted)
                }
                Spacer()
            }
        } footer: {
            WFooter {
                WButton(store.t("Change time", "समय बदलें", "సమయం మార్చండి"), kind: .outline, size: .captain) {}
            }
        }
    }
}

// MARK: W14 You're in

struct LiveScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) {
            EmptyView()
        } content: {
            VStack(spacing: 16) {
                Spacer()
                WStateCircle(icon: .sparkle, tone: .ok, size: 112)
                Text(store.t("You’re in, \(store.firstName)!", "आप जुड़ गए, \(store.firstName)!", "మీరు చేరారు, \(store.firstName)!")).wText(.section, weight: .semibold, size: 23)
                Text(store.t("First 3 days you get fewer jobs. Good ratings unlock more.", "पहले 3 दिन कम काम मिलेंगे। अच्छी रेटिंग से ज़्यादा।", "మొదటి 3 రోజులు తక్కువ పనులు. మంచి రేటింగ్‌తో ఎక్కువ."))
                    .wBodyBig().multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    dayTile(store.t("2 jobs", "2 काम", "2 పనులు"), store.t("Day 1", "दिन 1", "రోజు 1"))
                    dayTile(store.t("4 jobs", "4 काम", "4 పనులు"), store.t("Day 2", "दिन 2", "రోజు 2"))
                    dayTile("6 – 8", store.t("Day 3 on", "दिन 3 से", "రోజు 3 నుండి"))
                }
                .padding(.top, 6)
                Spacer()
            }
        } footer: {
            WFooter {
                WButton(store.t("Go to home", "होम पर जाएं", "హోమ్‌కి వెళ్ళండి"), size: .captain) {
                    store.finishKyc()
                    router.home()
                }
            }
        }
    }

    func dayTile(_ big: String, _ small: String) -> some View {
        VStack(spacing: 6) {
            WIconView(icon: .calendar, size: 20, color: WColor.primaryStrong)
            Text(big).wText(.section, weight: .semibold)
            Text(small).wText(.caption)
        }
        .frame(maxWidth: .infinity).frame(height: 104)
        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
    }
}
