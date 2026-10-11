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

// MARK: C02 Welcome

struct WelcomeScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandMark().padding(.top, 20)
            Text("Clean wheels,\nzero hassle").wText(.display).padding(.top, 40)
            Text("Book a wash for your car or bike. Pay only after you see the photos.")
                .wText(.body, size: 16.5).padding(.top, 14)
            VStack(alignment: .leading, spacing: 18) {
                feature(.camera, "Photo proof, every wash", "Before and after, same angles")
                feature(.shield, "Money held safely", "Released only when you approve")
                feature(.clock, "You pick the time", "A nearby captain comes to your parking")
            }
            .padding(.top, 36)
            Spacer()
            // One way in. Returning customers say so at login, just before payment.
            WButton("Book a wash", icon: nil) {
                store.startNewBooking()
                router.push(.vehicleType(large: false))
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, WSpace.gutter)
        .background(WColor.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func feature(_ icon: WIcon, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            WIconBox(icon: icon, size: 48, radius: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).wText(.title, weight: .medium)
                Text(sub).wText(.caption)
            }
        }
    }
}
