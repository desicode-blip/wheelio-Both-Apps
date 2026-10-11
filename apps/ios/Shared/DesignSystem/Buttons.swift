import SwiftUI

/// Button/Primary, Button/Success, Button/Outline, Button/Text, Button/Danger, Button/Tonal.
/// One primary action per screen. Green only to pay, approve or accept.
/// Red only for errors and destructive actions.
enum WButtonStyleKind { case primary, success, outline, text, danger, tonal }

enum WButtonSize {
    case regular   // customer, 52
    case captain    // 64
    case accept    // 72

    var height: CGFloat {
        switch self {
        case .regular: return WSize.button
        case .captain: return WSize.buttonCaptain
        case .accept: return WSize.buttonAccept
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .regular: return 16.5
        case .captain: return 19
        case .accept: return 22
        }
    }
}

struct WButton: View {
    let title: String
    var icon: WIcon? = nil
    var kind: WButtonStyleKind = .primary
    var size: WButtonSize = .regular
    var enabled: Bool = true
    var loading: Bool = false
    var fullWidth: Bool = true
    let action: () -> Void

    init(_ title: String, icon: WIcon? = nil, kind: WButtonStyleKind = .primary, size: WButtonSize = .regular,
         enabled: Bool = true, loading: Bool = false, fullWidth: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.size = size
        self.enabled = enabled
        self.loading = loading
        self.fullWidth = fullWidth
        self.action = action
    }

    private var background: Color {
        guard enabled else { return kind == .text ? .clear : WColor.disabled }
        switch kind {
        case .primary: return WColor.primary
        case .success: return WColor.success
        case .outline: return WColor.white
        case .text: return .clear
        case .danger: return WColor.destructive
        case .tonal: return WColor.primaryTint
        }
    }

    private var foreground: Color {
        guard enabled else { return WColor.placeholder }
        switch kind {
        case .primary, .danger: return WColor.white
        case .success: return WColor.onSuccess
        case .outline, .text, .tonal: return WColor.primaryStrong
        }
    }

    var body: some View {
        Button {
            if enabled && !loading { action() }
        } label: {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(foreground)
                } else {
                    if let icon { WIconView(icon: icon, size: size.fontSize + 1, color: foreground, weight: .medium) }
                    Text(title)
                        .font(Font.custom(WFont.name(.semibold), size: size.fontSize, relativeTo: .body))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: kind == .text ? 48 : size.height)
            .background(background, in: Capsule())
            .overlay {
                if kind == .outline {
                    Capsule().strokeBorder(enabled ? WColor.primary : WColor.border, lineWidth: 1.5)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(WPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

/// Subtle press feedback for every tappable surface.
struct WPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Icon button: elevated (Elevation/Subtle), flat, or tinted.
struct WIconButton: View {
    enum Style { case elevated, flat, tint }

    let icon: WIcon
    var style: Style = .elevated
    var size: CGFloat = WSize.iconButton
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WIconView(icon: icon, size: size * 0.42, color: style == .tint ? WColor.primaryStrong : WColor.heading)
                .frame(width: size, height: size)
                .background {
                    switch style {
                    case .elevated:
                        Circle().fill(WColor.white).shadow(color: WColor.shadow, radius: 1.5, y: 1)
                    case .flat:
                        Circle().fill(Color.clear)
                    case .tint:
                        Circle().fill(WColor.primaryTint)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(WPressStyle())
        .accessibilityLabel(label.isEmpty ? icon.rawValue : label)
    }
}

/// Underlined inline link, e.g. "Change", "Retry", "See tomorrow".
struct WLink: View {
    let title: String
    var color: Color = WColor.primaryStrong
    var type: WType = .body
    let action: () -> Void

    init(_ title: String, color: Color = WColor.primaryStrong, type: WType = .body, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.type = type
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).underline().wText(type, color: color, weight: .medium)
                .lineLimit(2).minimumScaleFactor(0.8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
