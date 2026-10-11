import SwiftUI
import CoreText

// Wheelio design system: tokens from the design read-me (designs/Main.dc.html)
// and the Figma "🎨 Design system" page. Both apps share this folder.

// MARK: - Brand

enum Brand {
    /// data-token="brand/name". "Wheelio" is a working name: change it here only.
    static let name = "Wheelio"
    static let tagline = "Clean wheels, zero hassle"
}

// MARK: - Colour

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum WColor {
    // action
    static let primary = Color(hex: 0x3160FF)        // action/primary
    static let primaryStrong = Color(hex: 0x1F4AD1)  // action/primary-strong
    static let success = Color(hex: 0x4BD08C)        // action/success
    static let onSuccess = Color(hex: 0x15352A)
    static let destructive = Color(hex: 0xB3261E)    // action/destructive

    // content
    static let heading = Color(hex: 0x172231)        // content/heading
    static let body = Color(hex: 0x2B3A4D)           // content/body
    static let secondary = Color(hex: 0x5E7087)      // content/secondary
    static let placeholder = Color(hex: 0x7E8B9C)
    static let muted = Color(hex: 0x9AA6B6)

    // surface
    static let white = Color.white
    static let canvas = Color(hex: 0xF6F9FD)         // surface/canvas
    static let primaryTint = Color(hex: 0xEAF0FF)    // surface/primary-tint
    static let successTint = Color(hex: 0xE6F8EF)    // surface/success-tint
    static let waitTint = Color(hex: 0xFFF3E0)
    static let wait = Color(hex: 0x8A4500)
    static let waitText = Color(hex: 0x5C2E00)
    static let errorTint = Color(hex: 0xFDECEA)
    static let errorText = Color(hex: 0x7A1A14)
    static let disabled = Color(hex: 0xE8ECF2)
    static let inverse = Color(hex: 0x1B2533)
    static let camera = Color(hex: 0x0E1520)
    static let cameraPanel = Color(hex: 0x1C2636)
    static let photo = Color(hex: 0xE6EAF0)
    static let map = Color(hex: 0xEEF2F7)
    static let mapBlock = Color(hex: 0xE2E8F0)
    static let mapGreen = Color(hex: 0xDDE9D8)
    static let star = Color(hex: 0xF0A030)

    // border
    static let border = Color(hex: 0xDCE2E9)         // border/default
    static let divider = Color(hex: 0xE1E5EA)
    static let track = Color(hex: 0xDCE5F6)
    static let dashed = Color(hex: 0x9FB3D9)
    static let grab = Color(hex: 0xC9D5E6)

    static let scrim = Color(hex: 0x172130, alpha: 0.48)
    static let shadow = Color(hex: 0x172130, alpha: 0.12)
    static let shadowCard = Color(hex: 0x172130, alpha: 0.08)
}

/// Semantic tone for badges, banners and state circles.
/// Colour is never the only signal: always pair a tone with an icon and a word.
enum WTone {
    case info, ok, wait, error, mute

    var background: Color {
        switch self {
        case .info: return WColor.primaryTint
        case .ok: return WColor.successTint
        case .wait: return WColor.waitTint
        case .error: return WColor.errorTint
        case .mute: return WColor.disabled
        }
    }

    var foreground: Color {
        switch self {
        case .info: return WColor.primaryStrong
        case .ok: return WColor.onSuccess
        case .wait: return WColor.wait
        case .error: return WColor.destructive
        case .mute: return WColor.body
        }
    }

    /// Text colour for longer text on a tinted banner.
    var bannerText: Color {
        switch self {
        case .info: return WColor.inverse
        case .ok: return WColor.onSuccess
        case .wait: return WColor.waitText
        case .error: return WColor.errorText
        case .mute: return WColor.body
        }
    }
}

// MARK: - Space, radius, size

enum WSpace {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    /// Screen gutter: 26 customer, 16 captain.
    static let gutter: CGFloat = 26
    static let gutterCaptain: CGFloat = 16
    static let section: CGFloat = 48
}

enum WRadius {
    static let field: CGFloat = 10
    static let chip: CGFloat = 10
    static let tile: CGFloat = 14
    static let card: CGFloat = 20
    static let button: CGFloat = 26
    static let sheet: CGFloat = 28
}

enum WSize {
    static let button: CGFloat = 52
    static let buttonCaptain: CGFloat = 64
    static let buttonAccept: CGFloat = 72
    static let iconButton: CGFloat = 48
    static let iconButtonCaptain: CGFloat = 64
    static let footer: CGFloat = 101
}

// MARK: - Type

/// Type scale from the design read-me (size / line height, weight).
enum WType {
    case display, screen, section, value, valueStrong, title, rowTitle, body, bodyStrong
    case action, caption, label, appBarTitle, bigMoney, hugeMoney, small

    var size: CGFloat {
        switch self {
        case .display: return 40
        case .screen: return 26
        case .section: return 20
        case .value, .valueStrong, .appBarTitle: return 17
        case .title, .rowTitle: return 16
        case .body, .bodyStrong: return 15
        case .action: return 16.5
        case .caption: return 13
        case .label: return 12.5
        case .small: return 11.5
        case .bigMoney: return 44
        case .hugeMoney: return 56
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .display: return 48
        case .screen: return 32
        case .section: return 26
        case .value, .valueStrong, .appBarTitle: return 22
        case .title, .rowTitle: return 21
        case .body, .bodyStrong: return 22
        case .action: return 21
        case .caption: return 18
        case .label: return 16
        case .small: return 14
        case .bigMoney: return 52
        case .hugeMoney: return 64
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .screen, .bigMoney, .hugeMoney: return .bold
        case .section, .valueStrong, .title, .action, .label, .appBarTitle: return .semibold
        default: return .regular
        }
    }

    var color: Color {
        switch self {
        case .body, .caption, .label, .small: return WColor.secondary
        case .bodyStrong: return WColor.body
        case .action: return WColor.white
        default: return WColor.heading
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .display, .bigMoney, .hugeMoney: return .largeTitle
        case .screen: return .title
        case .section: return .title3
        case .caption, .label, .small: return .caption
        default: return .body
        }
    }
}

enum WFont {
    static func name(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Roboto-Bold"
        case .semibold: return "Roboto-SemiBold"
        case .medium: return "Roboto-Medium"
        default: return "Roboto-Regular"
        }
    }

    static func of(_ type: WType, weight: Font.Weight? = nil, size: CGFloat? = nil) -> Font {
        Font.custom(name(weight ?? type.weight), size: size ?? type.size, relativeTo: type.textStyle)
    }

    /// Roboto ships inside the app (Shared/Fonts), so it looks the same everywhere
    /// and never waits for a download. Call once at launch.
    static func register() {
        for name in ["Roboto-Regular", "Roboto-Medium", "Roboto-SemiBold", "Roboto-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension View {
    /// Applies a type token: font, line height and default colour.
    func wText(_ type: WType, color: Color? = nil, weight: Font.Weight? = nil, size: CGFloat? = nil) -> some View {
        self.font(WFont.of(type, weight: weight, size: size))
            .lineSpacing(max(0, (type.lineHeight - type.size * 1.17) * (size ?? type.size) / type.size))
            .foregroundStyle(color ?? type.color)
    }

    /// Money always uses tabular figures.
    func wMoney() -> some View { self.monospacedDigit() }
}
