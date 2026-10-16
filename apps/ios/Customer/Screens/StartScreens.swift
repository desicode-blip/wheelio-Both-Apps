import SwiftUI

/// Shared "call support" action for footers.
func callSupport() { Support.call() }

/// Brand mark: blue rounded square with the ring, plus the name token.
struct BrandMark: View {
    var size: CGFloat = 34
    var light: Bool = false
    var showName: Bool = true

    var body: some View {
        HStack(spacing: size * 0.3) {
            ZStack {
                if !light { RoundedRectangle(cornerRadius: size * 0.24).fill(WColor.primary) }
                Circle().strokeBorder(.white, lineWidth: size * 0.1).frame(width: size * 0.56, height: size * 0.56)
                Circle().fill(.white).frame(width: size * 0.2, height: size * 0.2)
            }
            .frame(width: size, height: size)
            if showName {
                Text(Brand.name)
                    .font(WFont.of(.screen, weight: .bold, size: size * (light ? 1.2 : 0.8)))
                    .foregroundStyle(light ? .white : WColor.heading)
            }
        }
    }
}

// MARK: C01 Splash

struct SplashScreen: View {
    var autoContinue = true
    var onDone: () -> Void = {}

    var body: some View {
        ZStack {
            WColor.primary.ignoresSafeArea()
            VStack(spacing: 14) {
                BrandMark(size: 40, light: true)
                Text(Brand.tagline).wText(.body, color: .white.opacity(0.92))
            }
        }
        .task {
            guard autoContinue else { return }
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            onDone()
        }
    }
}

// MARK: C02 Welcome: three slides, one feeling each (same pattern as the Captain app)

/// Big picture, two short lines, a quiet "Next". The dots double as the timer:
/// each fills from the left, then the next slide comes. Skip goes straight in.
struct WelcomeScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var index = 0
    @State private var progress: CGFloat = 0

    static let slideSeconds: Double = 3.5

    struct Slide { let art: CustomerWelcomeArt.Kind; let title: String; let line: String }

    let slides: [Slide] = [
        Slide(art: .morning, title: "Wake up to a clean car",
              line: "A captain washes it in your parking. You don’t need to be there."),
        Slide(art: .trust, title: "See it, then pay",
              line: "Before and after photos. Money moves only when you approve."),
        Slide(art: .time, title: "Your weekend is yours",
              line: "Spend it with family, not with a bucket."),
    ]

    var body: some View {
        let slide = slides[index]
        VStack(spacing: 0) {
            HStack {
                if index > 0 {
                    Button { go(to: index - 1) } label: {
                        HStack(spacing: 4) {
                            WIconView(icon: .left, size: 15, color: WColor.heading, weight: .semibold)
                            Text("Back").wText(.body, color: WColor.heading)
                        }
                        .frame(height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, WSpace.gutter)

            CustomerWelcomeArt(kind: slide.art)
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .frame(maxHeight: .infinity)
                .padding(.horizontal, WSpace.gutter)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text(slide.title).wText(.screen, size: 26).multilineTextAlignment(.center)
                Text(slide.line).wText(.body, color: WColor.secondary, size: 16.5).multilineTextAlignment(.center)
            }
            .id("text\(index)")
            .transition(.opacity)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WSpace.gutter)
            .padding(.top, 28)

            TimerDots(count: slides.count, index: index, progress: progress)
                .padding(.top, 26)

            HStack {
                Button { enterApp() } label: {
                    Text("Skip").wText(.body, color: WColor.secondary)
                        .frame(height: 48).padding(.horizontal, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button { next() } label: {
                    HStack(spacing: 8) {
                        Text("Next").wText(.title, color: WColor.primaryStrong, size: 17)
                        WIconView(icon: .arrowRight, size: 15, color: WColor.primaryStrong, weight: .semibold)
                    }
                    .padding(.horizontal, 26).frame(height: 52)
                    .background(WColor.primaryTint, in: Capsule())
                }
                .buttonStyle(WPressStyle())
            }
            .padding(.horizontal, WSpace.gutter)
            .padding(.top, 26).padding(.bottom, 12)
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.4), value: index)
        .task(id: index) {
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
    /// Into Home, where "Book a wash" is the main button.
    func enterApp() { withAnimation { store.hasSeenWelcome = true }; router.popToRoot() }
}

// MARK: Slide pictures (drawn, gently animated)

struct CustomerWelcomeArt: View {
    enum Kind { case morning, trust, time }
    let kind: Kind
    @State private var on = false

    var body: some View {
        GeometryReader { g in
            let w = max(g.size.width, 1), h = max(g.size.height, 1)
            ZStack {
                RoundedRectangle(cornerRadius: 32).fill(background)
                switch kind {
                case .morning: morning(w, h)
                case .trust: trust(w, h)
                case .time: time(w, h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { on = true } }
        .accessibilityHidden(true)
    }

    var background: LinearGradient {
        switch kind {
        case .morning: return LinearGradient(colors: [Color(hex: 0xFFE9D2), Color(hex: 0xDCEBFF)], startPoint: .top, endPoint: .bottom)
        case .trust: return LinearGradient(colors: [Color(hex: 0xE8ECFF), Color(hex: 0xF5F7FF)], startPoint: .top, endPoint: .bottom)
        case .time: return LinearGradient(colors: [Color(hex: 0xE3F6EE), Color(hex: 0xFFF6E3)], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Sunrise over the building; a gleaming car with sparkles in the parking.
    @ViewBuilder func morning(_ w: CGFloat, _ h: CGFloat) -> some View {
        Circle().fill(Color(hex: 0xFFC56E).opacity(0.35)).frame(width: w * 0.62)
            .scaleEffect(on ? 1.06 : 0.95).position(x: w * 0.74, y: h * 0.26)
        Circle().fill(Color(hex: 0xFFC56E)).frame(width: w * 0.32)
            .position(x: w * 0.74, y: h * 0.26)
        Image(systemName: "building.2.fill").font(.system(size: h * 0.30))
            .foregroundStyle(Color(hex: 0xB9C8DD)).position(x: w * 0.26, y: h * 0.40)
        Rectangle().fill(Color(hex: 0xC9D6E8)).frame(height: h * 0.30).position(x: w * 0.5, y: h * 0.88)
        Image(systemName: "car.side.fill").font(.system(size: h * 0.24))
            .foregroundStyle(WColor.primary)
            .position(x: w * 0.5, y: h * 0.70)
        ForEach(0..<4, id: \.self) { i in
            let xs: [CGFloat] = [0.30, 0.62, 0.74, 0.44]
            let ys: [CGFloat] = [0.58, 0.55, 0.70, 0.52]
            Image(systemName: "sparkle").font(.system(size: i % 2 == 0 ? 22 : 15, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: Color(hex: 0xFFC56E), radius: 4)
                .scaleEffect(on == (i % 2 == 0) ? 1.2 : 0.6)
                .opacity(on == (i % 2 == 0) ? 1 : 0.4)
                .position(x: w * xs[i], y: h * ys[i])
        }
    }

    /// A phone with before / after photos and a green tick; a shield floats beside it.
    @ViewBuilder func trust(_ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 26).fill(.white)
            .frame(width: w * 0.50, height: h * 0.74)
            .shadow(color: Color(hex: 0x3160FF).opacity(0.15), radius: 18, y: 8)
            .position(x: w * 0.46, y: h * 0.52)
        VStack(spacing: 10) {
            photo("Before", dull: true)
            photo("After", dull: false)
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                Text("Approve").font(WFont.of(.label, weight: .semibold, size: 13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).frame(height: 30)
            .background(WColor.success, in: Capsule())
            .scaleEffect(on ? 1.04 : 0.98)
        }
        .frame(width: w * 0.42)
        .position(x: w * 0.46, y: h * 0.52)
        Image(systemName: "checkmark.shield.fill").font(.system(size: h * 0.12))
            .foregroundStyle(WColor.primary)
            .offset(y: on ? -6 : 4)
            .position(x: w * 0.80, y: h * 0.26)
    }

    func photo(_ tag: String, dull: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12).fill(dull ? Color(hex: 0xD9D4CC) : Color(hex: 0xDCEBFF))
            Image(systemName: "car.side.fill").font(.system(size: 30))
                .foregroundStyle(dull ? Color(hex: 0x8C8577) : WColor.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !dull {
                Image(systemName: "sparkle").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: 0xFFC56E))
                    .padding(8).frame(maxWidth: .infinity, alignment: .trailing)
            }
            Text(tag).font(WFont.of(.small, weight: .semibold, size: 10))
                .foregroundStyle(dull ? Color(hex: 0x5E5A52) : WColor.primaryStrong)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.white.opacity(0.85), in: Capsule())
                .padding(6)
        }
        .frame(height: 72)
    }

    /// A family out together on a sunny day; the clean car waits at home.
    @ViewBuilder func time(_ w: CGFloat, _ h: CGFloat) -> some View {
        Circle().fill(Color(hex: 0xFFD27A)).frame(width: w * 0.22)
            .scaleEffect(on ? 1.06 : 0.96).position(x: w * 0.80, y: h * 0.18)
        Image(systemName: "cloud.fill").font(.system(size: 34)).foregroundStyle(.white)
            .position(x: w * (on ? 0.30 : 0.24), y: h * 0.16)
        Ellipse().fill(Color(hex: 0x8FD3A7)).frame(width: w * 1.5, height: h * 0.46)
            .position(x: w * 0.5, y: h * 1.0)
        Image(systemName: "tree.fill").font(.system(size: h * 0.20))
            .foregroundStyle(Color(hex: 0x4FA873)).position(x: w * 0.16, y: h * 0.62)
        Image(systemName: "figure.2.and.child.holdinghands").font(.system(size: h * 0.30))
            .foregroundStyle(WColor.primaryStrong)
            .offset(y: on ? -3 : 3)
            .position(x: w * 0.52, y: h * 0.62)
        Image(systemName: "car.side.fill").font(.system(size: h * 0.09))
            .foregroundStyle(WColor.primary.opacity(0.75))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0xFFC56E))
                    .opacity(on ? 1 : 0.3).offset(x: 6, y: -4)
            }
            .position(x: w * 0.84, y: h * 0.74)
    }
}
