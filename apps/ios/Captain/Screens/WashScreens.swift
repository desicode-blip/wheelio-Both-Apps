import SwiftUI
import Combine

/// Before · Wash · After progress for a job.
struct WashStageBar: View {
    @Environment(CaptainStore.self) var store
    /// 0 before, 1 wash, 2 after
    let stage: Int
    var body: some View {
        WSegmentBar(filled: stage + 1, total: 3,
                    labels: [store.t("Before", "पहले", "ముందు"), store.t("Wash", "धुलाई", "వాష్"), store.t("After", "बाद में", "తర్వాత")],
                    greenUpTo: stage)
    }
}

@MainActor
func sideName(_ store: CaptainStore, _ i: Int) -> String {
    switch i {
    case 0: return store.t("Front", "आगे", "ముందు భాగం")
    case 1: return store.t("Back", "पीछे", "వెనుక భాగం")
    case 2: return store.t("Left", "बायाँ", "ఎడమ")
    default: return store.t("Right", "दायाँ", "కుడి")
    }
}

// MARK: W30 Quick face check

struct FaceCheckScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var checking = false

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) {
            WHeader(title: store.t("Quick check", "जल्दी जाँच", "త్వరిత తనిఖీ"))
        } content: {
            WFullState(icon: .face, title: store.t("Show your face", "अपना चेहरा दिखाएं", "మీ ముఖం చూపించండి"),
                       message: store.t("Only to check it’s you. Takes 2 seconds.", "सिर्फ़ यह जाँचने के लिए कि आप ही हैं। 2 सेकंड लगेंगे।", "అది మీరేనని చూడటానికి మాత్రమే. 2 సెకన్లు."),
                       spinning: checking, captain: true)
        } footer: {
            WFooter {
                WButton(store.t("Open camera", "कैमरा खोलें", "కెమెరా తెరవండి"), icon: .camera, size: .captain, loading: checking) {
                    checking = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        checking = false
                        router.replace([.goToVehicle, .beforePhotos])
                    }
                }
            }
        }
    }
}

// MARK: W31 Before photos · W35 After photos

struct JobPhotosScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let after: Bool

    var body: some View {
        let done = after ? store.afterDone : store.beforeDone
        let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.current.plate)
        } content: {
            WashStageBar(stage: after ? 2 : 0).padding(.top, 4)
            HStack(alignment: .center, spacing: 10) {
                Text(after ? store.t("After photos", "बाद की फ़ोटो", "తర్వాతి ఫోటోలు") : store.t("Before photos", "पहले की फ़ोटो", "ముందు ఫోటోలు"))
                    .wTitle()
                Spacer(minLength: 6)
                OwnerNoteButton()
            }
            .padding(.top, 18)
            Text(after ? store.t("Same 4 sides as before.", "पहले जैसी ही 4 तरफ़।", "ముందు లాగే 4 వైపులు.")
                       : store.t("4 sides. Same as the outline.", "4 तरफ़। आउटलाइन जैसा।", "4 వైపులు. అవుట్‌లైన్ లాగే."))
                .wBodyBig().padding(.top, 4).padding(.bottom, 16)
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    if done.contains(i) {
                        VStack(alignment: .leading, spacing: 6) {
                            WPhotoSlot(label: sideName(store, i), state: .done, tag: after ? store.t("After", "बाद", "తర్వాత") : store.t("Before", "पहले", "ముందు"),
                                       tagTone: after ? .ok : .mute, height: 112)
                        }
                    } else {
                        Button { router.push(.camera(after: after, side: i)) } label: {
                            VStack(spacing: 8) {
                                WIconView(icon: .camera, size: 24, color: WColor.primaryStrong)
                                Text(sideName(store, i)).wText(.title, color: WColor.primaryStrong, size: 17)
                            }
                            .frame(maxWidth: .infinity).frame(height: 136)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WColor.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        }
                        .buttonStyle(WPressStyle())
                    }
                }
            }
        } footer: {
            WFooter {
                if after {
                    WButton(store.t("Check photos", "फ़ोटो जाँचें", "ఫోటోలు తనిఖీ చేయండి"), size: .captain, enabled: done.count == 4) {
                        router.push(store.aiFlag ? .aiCheck : .uploading)
                    }
                } else {
                    WButton(store.t("Next", "आगे", "తదుపరి"), size: .captain, enabled: done.count == 4) { router.push(.washing) }
                }
            }
        }
    }
}

// MARK: W32 Camera (in-app, time and location stamped)

struct JobCameraScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let after: Bool
    let side: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { router.pop() } label: { WIconView(icon: .close, size: 18, color: .white.opacity(0.5)).frame(width: 48, height: 48) }
                    .buttonStyle(.plain)
                Spacer()
                Text(sideName(store, side) + (side >= 2 ? store.t(" side", "", "") : "")).wText(.section, color: .white, weight: .semibold)
                Spacer()
                Text("\(side + 1) " + store.t("of", "/", "/") + " 4").wText(.label, color: WColor.primaryStrong)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(WColor.primaryTint, in: Capsule())
            }
            .padding(.horizontal, 8)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16).fill(WColor.cameraPanel)
                guide
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                WBadge(text: store.t("At the vehicle", "गाड़ी के पास", "వాహనం దగ్గర"), tone: .ok, icon: .location).padding(12)
            }
            .padding(.horizontal, 12).padding(.top, 6)
            HStack {
                WIconView(icon: .flash, size: 20, color: .white.opacity(0.4)).frame(width: 60)
                Spacer()
                Button(action: shoot) {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 5).frame(width: 84, height: 84)
                        Circle().fill(.white).frame(width: 66, height: 66)
                    }
                }
                .accessibilityLabel("Take photo")
                Spacer()
                Spacer().frame(width: 60)
            }
            .padding(.vertical, 22)
        }
        .background(WColor.camera.ignoresSafeArea())
    }

    /// Dotted guide matches the side: front and back views, or the side profile.
    @ViewBuilder var guide: some View {
        let style = StrokeStyle(lineWidth: 2.5, dash: [8, 6])
        switch side {
        case 0: CarFrontOutline().stroke(.white.opacity(0.85), style: style).frame(width: 240, height: 180)
        case 1: CarBackOutline().stroke(.white.opacity(0.85), style: style).frame(width: 240, height: 180)
        default: CarSideOutline().stroke(.white.opacity(0.85), style: style).frame(width: 270, height: 100)
        }
    }

    func shoot() {
        if store.darkPhoto && side == 2 && !after {
            store.darkPhoto = false
            router.replace(Array(router.path.dropLast()) + [.photoDark])
            return
        }
        if after { store.afterDone.insert(side) } else { store.beforeDone.insert(side) }
        let done = after ? store.afterDone : store.beforeDone
        if let next = (0..<4).first(where: { !done.contains($0) }) {
            router.replace(Array(router.path.dropLast()) + [.camera(after: after, side: next)])
        } else {
            router.pop()
        }
    }
}

/// Dashed side view of a car for the guided camera.
struct CarSideOutline: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX, y: r.minY + h * 0.75))
        p.addLine(to: CGPoint(x: r.minX + w * 0.04, y: r.minY + h * 0.45))
        p.addLine(to: CGPoint(x: r.minX + w * 0.28, y: r.minY + h * 0.38))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.68, y: r.minY + h * 0.35), control: CGPoint(x: r.minX + w * 0.45, y: r.minY - h * 0.1))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.02, y: r.minY + h * 0.55))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.75))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: r.minX + w * 0.15, y: r.minY + h * 0.58, width: h * 0.42, height: h * 0.42))
        p.addEllipse(in: CGRect(x: r.maxX - w * 0.15 - h * 0.42, y: r.minY + h * 0.58, width: h * 0.42, height: h * 0.42))
        return p
    }
}

/// Car seen from the front: cabin, body, headlights, grille, mirrors, wheels.
struct CarFrontOutline: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }
        func rc(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: r.minX + w * x0, y: r.minY + h * y0, width: w * (x1 - x0), height: h * (y1 - y0))
        }
        // Cabin and windscreen
        p.move(to: pt(0.24, 0.06)); p.addLine(to: pt(0.76, 0.06)); p.addLine(to: pt(0.88, 0.42)); p.addLine(to: pt(0.12, 0.42)); p.closeSubpath()
        p.move(to: pt(0.28, 0.13)); p.addLine(to: pt(0.72, 0.13)); p.addLine(to: pt(0.80, 0.37)); p.addLine(to: pt(0.20, 0.37)); p.closeSubpath()
        // Body
        p.addRoundedRect(in: rc(0.04, 0.42, 0.96, 0.82), cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
        // Mirrors
        p.addRoundedRect(in: rc(0.0, 0.33, 0.09, 0.42), cornerSize: CGSize(width: 4, height: 4))
        p.addRoundedRect(in: rc(0.91, 0.33, 1.0, 0.42), cornerSize: CGSize(width: 4, height: 4))
        // Headlights and grille
        p.addEllipse(in: rc(0.09, 0.50, 0.30, 0.62))
        p.addEllipse(in: rc(0.70, 0.50, 0.91, 0.62))
        p.addRoundedRect(in: rc(0.36, 0.52, 0.64, 0.64), cornerSize: CGSize(width: 4, height: 4))
        p.move(to: pt(0.04, 0.72)); p.addLine(to: pt(0.96, 0.72))
        // Wheels
        p.addRoundedRect(in: rc(0.10, 0.82, 0.25, 0.97), cornerSize: CGSize(width: 4, height: 4))
        p.addRoundedRect(in: rc(0.75, 0.82, 0.90, 0.97), cornerSize: CGSize(width: 4, height: 4))
        return p
    }
}

/// Car seen from the back: rear window, body, tail lights, number plate, wheels.
struct CarBackOutline: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }
        func rc(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: r.minX + w * x0, y: r.minY + h * y0, width: w * (x1 - x0), height: h * (y1 - y0))
        }
        // Roof and rear window
        p.move(to: pt(0.24, 0.08)); p.addLine(to: pt(0.76, 0.08)); p.addLine(to: pt(0.88, 0.42)); p.addLine(to: pt(0.12, 0.42)); p.closeSubpath()
        p.move(to: pt(0.29, 0.15)); p.addLine(to: pt(0.71, 0.15)); p.addLine(to: pt(0.78, 0.36)); p.addLine(to: pt(0.22, 0.36)); p.closeSubpath()
        // Body
        p.addRoundedRect(in: rc(0.04, 0.42, 0.96, 0.82), cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
        // Tail lights
        p.addRoundedRect(in: rc(0.06, 0.48, 0.24, 0.60), cornerSize: CGSize(width: 4, height: 4))
        p.addRoundedRect(in: rc(0.76, 0.48, 0.94, 0.60), cornerSize: CGSize(width: 4, height: 4))
        // Number plate and bumper
        p.addRect(rc(0.35, 0.58, 0.65, 0.69))
        p.move(to: pt(0.04, 0.74)); p.addLine(to: pt(0.96, 0.74))
        // Wheels
        p.addRoundedRect(in: rc(0.10, 0.82, 0.25, 0.97), cornerSize: CGSize(width: 4, height: 4))
        p.addRoundedRect(in: rc(0.75, 0.82, 0.90, 0.97), cornerSize: CGSize(width: 4, height: 4))
        return p
    }
}

// MARK: W33 Photo too dark

struct PhotoDarkScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: sideName(store, 2) + store.t(" side", "", ""))
        } content: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x2A3646))
                WIconView(icon: .car, size: 44, color: .white.opacity(0.4)).frame(maxWidth: .infinity, maxHeight: .infinity)
                WBadge(text: store.t("Too dark", "बहुत अंधेरा", "చాలా చీకటి"), tone: .error, icon: .sun).padding(12)
            }
            .frame(height: 216)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(WColor.destructive, lineWidth: 3))
            .padding(.top, 8)
            Text(store.t("Photo is too dark", "फ़ोटो बहुत अंधेरी है", "ఫోటో చాలా చీకటిగా ఉంది")).wTitle().padding(.top, 22)
            Text(store.t("Turn on flash or move your phone light closer.", "फ़्लैश चालू करें या फ़ोन की लाइट पास लाएं।", "ఫ్లాష్ ఆన్ చేయండి లేదా ఫోన్ లైట్ దగ్గరగా తీసుకురండి."))
                .wBodyBig().padding(.top, 6)
        } footer: {
            WFooter {
                WButton(store.t("Take again", "फिर से लें", "మళ్ళీ తీయండి"), icon: .camera, size: .captain) {
                    router.replace(Array(router.path.dropLast()) + [.camera(after: false, side: 2)])
                }
            }
        }
    }
}

// MARK: W34 Washing (W34b late)

struct WashingScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var seconds = 14 * 60 + 32
    @State var done: Set<Int> = []
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var late: Bool { store.lateWash }

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.current.plate)
        } content: {
            WashStageBar(stage: 1).padding(.top, 4)
            HStack { Spacer(); OwnerNoteButton() }.padding(.top, 12)
            VStack(spacing: 8) {
                Text(late ? store.t("Should have finished 8:55 AM", "8:55 AM तक ख़त्म होना था", "8:55 AM కి పూర్తవ్వాలి")
                          : store.t("Finish by 8:55 AM", "8:55 AM तक ख़त्म करें", "8:55 AM లోపు పూర్తి చేయండి"))
                    .wText(.body, size: 16)
                Text(late ? "+6:10" : Fmt.clock(seconds))
                    .font(WFont.of(.hugeMoney, weight: .bold, size: 64)).monospacedDigit()
                    .foregroundStyle(late ? WColor.destructive : WColor.heading)
                if late {
                    WBadge(text: store.t("−₹6 so far", "अब तक −₹6", "ఇప్పటి వరకు −₹6"), tone: .error, icon: .clock)
                } else {
                    WBadge(text: store.t("On time", "समय पर", "సమయానికి"), tone: .ok, icon: .check)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20).padding(.bottom, 22)
            BookingVisual(job: store.current).padding(.bottom, 22)
            if late {
                WBanner(tone: .wait, icon: .info, text: store.t("−₹1 for each late minute. Max ₹35 on this job.", "हर लेट मिनट पर −₹1। इस काम पर ज़्यादा से ज़्यादा ₹35।", "ప్రతి ఆలస్య నిమిషానికి −₹1. ఈ పనికి గరిష్టం ₹35."))
            } else {
                Text(store.t("Steps", "कदम", "దశలు")).wText(.label).padding(.bottom, 8)
                HStack(spacing: 10) {
                    if store.current.wash.water {
                        step(0, .bucket, store.t("Water", "पानी", "నీళ్ళు"))
                    } else {
                        step(0, .wipe, store.t("Dust", "धूल झाड़ें", "దుమ్ము దులపండి"))
                    }
                    step(1, .wipe, store.t("Wipe", "पोंछें", "తుడవండి"))
                    step(2, .sparkle, store.t("Dry", "सुखाएं", "ఆరబెట్టండి"))
                }
                .padding(.bottom, 20)
            }
        } footer: {
            WFooter {
                WButton(store.t("Done washing", "धुलाई पूरी", "వాష్ పూర్తైంది"), size: .captain) { router.push(.afterPhotos) }
            }
        }
        .onReceive(timer) { _ in if seconds > 0 && !late { seconds -= 1 } }
    }

    func step(_ i: Int, _ icon: WIcon, _ title: String) -> some View {
        let on = done.contains(i)
        return Button { if on { done.remove(i) } else { done.insert(i) } } label: {
            VStack(spacing: 10) {
                WIconView(icon: on ? .check : icon, size: 22, color: on ? WColor.onSuccess : WColor.primaryStrong)
                    .frame(width: 56, height: 56).background(on ? WColor.success : WColor.primaryTint, in: Circle())
                Text(title).wText(.title, size: 16.5)
            }
            .frame(maxWidth: .infinity).frame(height: 112)
            .background(on ? WColor.successTint : WColor.canvas, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(WPressStyle())
    }
}

// MARK: W36 AI photo check

struct AiCheckScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Photo check", "फ़ोटो जाँच", "ఫోటో తనిఖీ"))
        } content: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x33445C))
                HStack(spacing: -6) {
                    WIconView(icon: .car, size: 46, color: .white.opacity(0.5))
                    Circle().strokeBorder(WColor.star, lineWidth: 3).frame(width: 62, height: 62)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                WBadge(text: store.t("Left mirror", "बायाँ शीशा", "ఎడమ అద్దం"), tone: .wait, icon: .eye).padding(12)
            }
            .frame(height: 198)
            .padding(.top, 8)
            Text(store.t("Left mirror looks dusty", "बायाँ शीशा धूल भरा लग रहा है", "ఎడమ అద్దం దుమ్ముగా ఉంది")).wTitle().padding(.top, 22)
            Text(store.t("Wipe it once more and take the left photo again.", "एक बार और पोंछें और बाईं फ़ोटो फिर से लें।", "మళ్ళీ ఒకసారి తుడిచి ఎడమ ఫోటో మళ్ళీ తీయండి."))
                .wBodyBig().padding(.top, 6)
        } footer: {
            VStack(spacing: 0) {
                WFooter {
                    WButton(store.t("Wipe and retake", "पोंछें और फिर लें", "తుడిచి మళ్ళీ తీయండి"), icon: .camera, size: .captain) {
                        store.aiFlag = false
                        store.afterDone.remove(2)
                        router.replace(Array(router.path.dropLast()) + [.camera(after: true, side: 2)])
                    }
                }
                WLink(store.t("It’s clean, send anyway", "साफ़ है, फिर भी भेजें", "శుభ్రంగా ఉంది, అయినా పంపండి")) {
                    router.replace(Array(router.path.dropLast()) + [.uploading])
                }
                .padding(.bottom, 8)
            }
            .background(.white)
        }
    }
}

// MARK: W37 Sending photos

struct UploadingScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State var progress: [Double] = [1, 1, 0.5, 0.55]

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Sending photos", "फ़ोटो भेज रहे हैं", "ఫోటోలు పంపుతోంది"), back: false)
        } content: {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    WPhotoSlot(label: sideName(store, i), state: progress[i] >= 1 ? .done : .uploading,
                               tag: store.t("After", "बाद", "తర్వాత"), tagTone: .ok, height: 112)
                }
            }
            .padding(.top, 8)
            if store.lowSignal || progress.contains(where: { $0 < 1 }) {
                WBanner(tone: .wait, icon: .wifiOff, title: store.t("Weak signal.", "कमज़ोर सिग्नल।", "బలహీన సిగ్నల్."),
                        text: store.t("Photos are saved on your phone and will send by themselves. You can start the next job.",
                                      "फ़ोटो फ़ोन में सेव हैं और अपने आप चली जाएंगी। आप अगला काम शुरू कर सकते हैं।",
                                      "ఫోటోలు ఫోన్‌లో సేవ్ అయ్యాయి, అవే పంపబడతాయి. మీరు తదుపరి పని మొదలుపెట్టవచ్చు."))
                    .padding(.top, 16)
            }
        } footer: {
            WFooter {
                WButton(store.t("Next job", "अगला काम", "తదుపరి పని"), size: .captain) {
                    router.replace([.jobDone(late: store.lateWash)])
                }
            }
        }
        .task {
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                progress = progress.map { min(1, $0 + 0.05) }
            }
        }
    }
}

// MARK: W38 Shine done (W38b late)

struct JobDoneScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let late: Bool

    var body: some View {
        let pay = store.current.pay
        WScreen(gutter: WSpace.gutterCaptain) {
            Color.clear.frame(height: 40)
        } content: {
            VStack(spacing: 12) {
                WStateCircle(icon: late ? .clock : .sparkle, tone: late ? .wait : .ok, size: 112).padding(.top, 50)
                Text(late ? store.t("Done, 12 min late", "हो गया, 12 मिनट लेट", "పూర్తైంది, 12 నిమిషాలు ఆలస్యం") : store.t("Shine done!", "चमक गई!", "మెరిసింది!"))
                    .wText(.section, weight: .semibold, size: 24)
                Text(late ? store.t("Try to start earlier next time.", "अगली बार जल्दी शुरू करें।", "తదుపరిసారి ముందుగా మొదలుపెట్టండి.")
                          : store.t("Owner checks the photos. Money comes tonight before 12.", "मालिक फ़ोटो देखेंगे। पैसे आज रात 12 बजे से पहले आएंगे।", "యజమాని ఫోటోలు చూస్తారు. డబ్బు ఈ రాత్రి 12 లోపు వస్తుంది."))
                    .wBodyBig().multilineTextAlignment(.center)
                if late {
                    WKeyValueCard(rows: [
                        (store.t("Pay", "कमाई", "చెల్లింపు"), Fmt.rupees(pay)),
                        (store.t("Late 12 min", "12 मिनट लेट", "12 నిమిషాల ఆలస్యం"), "−₹12"),
                        (store.t("You get", "आपको मिलेंगे", "మీకు వచ్చేది"), Fmt.rupees(pay - 12)),
                    ], boldLast: true)
                    .padding(.top, 14)
                } else {
                    VStack(spacing: 6) {
                        Text(store.t("This job", "यह काम", "ఈ పని")).wText(.caption)
                        Text(Fmt.rupees(pay)).wText(.bigMoney).wMoney()
                        WBadge(text: store.t("Waiting for owner", "मालिक का इंतज़ार", "యజమాని కోసం వేచి ఉంది"), tone: .wait, icon: .clock)
                    }
                    .frame(maxWidth: .infinity)
                    .wCard(padding: 20)
                    .padding(.top, 14)
                }
            }
            .frame(maxWidth: .infinity)
        } footer: {
            WFooter {
                WButton(store.t("Next job", "अगला काम", "తదుపరి పని"), size: .captain) {
                    store.finishJob()
                    store.lateWash = false
                    router.home()
                    router.tab = 1
                }
            }
        }
    }
}
