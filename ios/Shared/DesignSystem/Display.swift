import SwiftUI

extension WScreen where Footer == EmptyView {
    init(canvas: Bool = false, gutter: CGFloat = WSpace.gutter, scrolls: Bool = true,
         @ViewBuilder header: @escaping () -> Header, @ViewBuilder content: @escaping () -> Content) {
        self.init(canvas: canvas, gutter: gutter, scrolls: scrolls, header: header, content: content, footer: { EmptyView() })
    }
}

// MARK: - Icon box

/// Rounded square holding an icon (tinted), used in tiles and rows.
struct WIconBox: View {
    let icon: WIcon
    var size: CGFloat = 44
    var tone: WTone = .info
    var radius: CGFloat = 12
    var iconSize: CGFloat? = nil

    var body: some View {
        WIconView(icon: icon, size: iconSize ?? size * 0.45, color: tone.foreground)
            .frame(width: size, height: size)
            .background(tone.background, in: RoundedRectangle(cornerRadius: radius))
    }
}

/// Large state circle (96) with an icon, used by full-screen states.
struct WStateCircle: View {
    let icon: WIcon
    var tone: WTone = .info
    var size: CGFloat = 96
    var spinning: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(tone.background)
            if spinning {
                ProgressView().controlSize(.large).tint(WColor.primary)
            } else {
                WIconView(icon: icon, size: size * 0.36, color: tone == .ok ? WColor.onSuccess : tone.foreground, weight: .medium)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Badge

/// Badge: icon + word on a tint. Colour is never the only signal.
struct WBadge: View {
    let text: String
    var tone: WTone = .info
    var icon: WIcon? = nil
    var solid: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon { WIconView(icon: icon, size: 11, color: solid ? .white : tone.foreground, weight: .semibold) }
            Text(text).wText(.label, color: solid ? .white : tone.foreground, weight: .semibold).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(solid ? tone.foreground : tone.background, in: Capsule())
    }
}

// MARK: - Banner

/// Inline banner: tinted panel with icon, text and an optional link action.
struct WBanner: View {
    var tone: WTone = .info
    var icon: WIcon = .info
    var title: String? = nil
    let text: String
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WIconView(icon: icon, size: 17, color: tone == .info ? WColor.heading : tone.bannerText)
                .padding(.top, 2)
            (titleText + Text(text))
                .wText(.caption, color: tone.bannerText, size: 14)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle {
                WLink(actionTitle, color: WColor.primaryStrong, type: .caption, action: action)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var titleText: Text {
        if let title { return Text(title + " ").font(WFont.of(.body, weight: .semibold, size: 14)) }
        return Text("")
    }
}

// MARK: - Full-screen state

/// Centered state: circle, title, body, primary and text actions.
struct WFullState: View {
    let icon: WIcon
    var tone: WTone = .info
    let title: String
    var message: String = ""
    var spinning: Bool = false
    var primary: String? = nil
    var primaryIcon: WIcon? = nil
    var primaryKind: WButtonStyleKind = .primary
    var secondary: String? = nil
    var captain: Bool = false
    var onPrimary: () -> Void = {}
    var onSecondary: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            WStateCircle(icon: icon, tone: tone, size: captain ? 112 : 96, spinning: spinning)
                .padding(.bottom, 22)
            Text(title)
                .wText(captain ? .section : .section, weight: .semibold, size: captain ? 23 : 21)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            if !message.isEmpty {
                Text(message)
                    .wText(.body, size: captain ? 16.5 : 15)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 24)
            }
            if let primary {
                WButton(primary, icon: primaryIcon, kind: primaryKind, size: captain ? .captain : .regular, action: onPrimary)
            }
            if let secondary {
                WButton(secondary, kind: .text, action: onSecondary).padding(.top, 6)
            }
            Spacer(minLength: 20)
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, captain ? WSpace.gutterCaptain : WSpace.gutter)
    }
}

// MARK: - Selection tile

/// Selection tile (e.g. "Selection tile/Vehicle type"): icon box, title, subtitle, trailing value.
struct WSelectionTile: View {
    let icon: WIcon
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var selected: Bool = false
    var radio: Bool = false
    var iconTone: WTone = .info
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                WIconBox(icon: icon, size: 48, tone: iconTone)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).wText(.title).fixedSize(horizontal: false, vertical: true)
                    if let subtitle { Text(subtitle).wText(.caption) }
                }
                Spacer(minLength: 8)
                if let trailing { Text(trailing).wText(.valueStrong).wMoney() }
                if radio { WRadio(on: selected) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? WColor.primaryTint : WColor.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selected ? WColor.primary : WColor.border, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(WPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct WRadio: View {
    let on: Bool
    var body: some View {
        ZStack {
            Circle().strokeBorder(on ? WColor.primary : WColor.muted, lineWidth: 2)
            if on { Circle().fill(WColor.primary).frame(width: 12, height: 12) }
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Chip

struct WChip: View {
    let title: String
    var selected: Bool = false
    var icon: WIcon? = nil
    var enabled: Bool = true
    var strike: Bool = false
    var height: CGFloat = 46
    var fill: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected { WIconView(icon: .check, size: 13, color: WColor.primaryStrong, weight: .semibold) }
                else if let icon { WIconView(icon: icon, size: 14, color: WColor.heading) }
                Text(title)
                    .strikethrough(strike, color: WColor.muted)
                    .wText(.bodyStrong, color: enabled ? (selected ? WColor.primaryStrong : WColor.heading) : WColor.muted,
                           weight: selected ? .semibold : .regular, size: 15.5)
            }
            .lineLimit(1)
            .padding(.horizontal, 15)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: height)
            .background(selected ? WColor.primaryTint : (enabled ? WColor.white : WColor.canvas),
                        in: RoundedRectangle(cornerRadius: WRadius.chip))
            .overlay(RoundedRectangle(cornerRadius: WRadius.chip)
                .strokeBorder(selected ? WColor.primary : WColor.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(WPressStyle())
        .disabled(!enabled)
    }
}

/// Simple wrapping layout for chips.
struct WFlow: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - Segmented control

struct WSegmented: View {
    let options: [String]
    @Binding var selection: Int
    var height: CGFloat = 46
    var disabled: Set<Int> = []

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, title in
                Button {
                    selection = i
                } label: {
                    Text(title)
                        .wText(.bodyStrong, color: selection == i ? WColor.heading : WColor.secondary,
                               weight: selection == i ? .semibold : .medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: height - 8)
                        .background {
                            if selection == i {
                                Capsule().fill(WColor.white).shadow(color: WColor.shadow, radius: 2, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(WColor.disabled, in: Capsule())
    }
}

/// Underline tabs (Bookings: Upcoming / Past).
struct WTabs: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, title in
                    Button { selection = i } label: {
                        VStack(spacing: 10) {
                            Text(title).wText(.title, color: selection == i ? WColor.primaryStrong : WColor.secondary,
                                              weight: selection == i ? .semibold : .medium)
                            Capsule().fill(selection == i ? WColor.primary : .clear).frame(width: 68, height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Rectangle().fill(WColor.divider).frame(height: 1)
        }
    }
}

// MARK: - Plate

/// Number plate tag (outlined, spaced letters).
struct WPlate: View {
    let text: String
    var large: Bool = false

    var body: some View {
        Text(text)
            .font(WFont.of(.title, weight: .bold, size: large ? 22 : 14.5))
            .tracking(large ? 2 : 1.3)
            .foregroundStyle(WColor.heading)
            .lineLimit(1)
            .padding(.horizontal, large ? 12 : 10)
            .padding(.vertical, large ? 8 : 5)
            .background(WColor.white, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(WColor.heading, lineWidth: 1.5))
    }
}

// MARK: - Avatar

struct WAvatar: View {
    let initials: String
    var size: CGFloat = 48

    var body: some View {
        Text(initials)
            .font(WFont.of(.title, weight: .bold, size: size * 0.36))
            .foregroundStyle(WColor.primaryStrong)
            .frame(width: size, height: size)
            .background(WColor.primaryTint, in: Circle())
    }
}

// MARK: - Rows

/// List row: icon box, title, subtitle, chevron.
struct WListRow: View {
    let icon: WIcon
    let title: String
    var subtitle: String? = nil
    var tone: WTone = .info
    var trailing: String? = nil
    var chevron: Bool = true
    var iconSize: CGFloat = 40
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                WIconBox(icon: icon, size: iconSize, tone: tone, radius: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).wText(.rowTitle).fixedSize(horizontal: false, vertical: true)
                    if let subtitle { Text(subtitle).wText(.caption).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 6)
                if let trailing { Text(trailing).wText(.caption) }
                if chevron { WIconView(icon: .chevron, size: 13, color: WColor.secondary, weight: .medium) }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WDivider: View {
    var inset: CGFloat = 0
    var body: some View { Rectangle().fill(WColor.divider).frame(height: 1).padding(.leading, inset) }
}

/// Key / value rows in an outlined card (Check and pay, booking detail).
struct WKeyValueCard: View {
    let rows: [(String, String)]
    var boldLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(alignment: .top) {
                    Text(row.0).wText(.body, color: WColor.secondary)
                    Spacer(minLength: 12)
                    Text(row.1)
                        .wText(boldLast && i == rows.count - 1 ? .valueStrong : .bodyStrong,
                               color: WColor.heading)
                        .multilineTextAlignment(.trailing)
                        .wMoney()
                }
                .padding(.vertical, 12)
                if i < rows.count - 1 { WDivider() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(WColor.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(WColor.border))
    }
}

// MARK: - Status steps

/// Vertical status steps (Booked → Captain on the way → Washing → Check photos).
struct WStatusSteps: View {
    struct Step: Identifiable {
        let id = UUID()
        let title: String
        var detail: String? = nil
    }

    let steps: [Step]
    /// Index of the current step. Steps before it are done.
    let current: Int
    var spacing: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        dot(i)
                        if i < steps.count - 1 {
                            Rectangle()
                                .fill(i < current ? WColor.success : WColor.border)
                                .frame(width: 2)
                                .frame(minHeight: spacing - 4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .wText(.rowTitle, color: i == current ? WColor.primaryStrong : (i < current ? WColor.heading : WColor.secondary),
                                   weight: i <= current ? .semibold : .regular)
                        if let d = step.detail { Text(d).wText(.caption) }
                    }
                    .padding(.top, 1)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder private func dot(_ i: Int) -> some View {
        if i < current {
            ZStack {
                Circle().fill(WColor.success)
                WIconView(icon: .check, size: 11, color: WColor.onSuccess, weight: .bold)
            }
            .frame(width: 24, height: 24)
        } else if i == current {
            ZStack {
                Circle().fill(WColor.primary)
                Circle().fill(.white).frame(width: 8, height: 8)
            }
            .frame(width: 24, height: 24)
        } else {
            Circle().strokeBorder(WColor.border, lineWidth: 2).frame(width: 24, height: 24)
        }
    }
}

// MARK: - Photo slot

enum WPhotoState { case empty, uploading, done, failed }

/// Photo slot: dashed empty slot with camera, or a placeholder photo with state.
struct WPhotoSlot: View {
    let label: String
    var state: WPhotoState = .empty
    var tag: String? = nil
    var tagTone: WTone = .mute
    var height: CGFloat = 126
    var showLabelBelow: Bool = false
    var icon: WIcon = .car
    var action: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                ZStack {
                    switch state {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(WColor.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        VStack(spacing: 6) {
                            WIconView(icon: .camera, size: 20, color: WColor.primaryStrong)
                            Text(showLabelBelow ? "" : label).wText(.label, color: WColor.primaryStrong)
                        }
                    case .failed:
                        RoundedRectangle(cornerRadius: 12).fill(WColor.errorTint)
                        VStack(spacing: 6) {
                            WIconView(icon: .refresh, size: 18, color: WColor.destructive, weight: .medium)
                            Text("Retry upload").wText(.label, color: WColor.destructive)
                        }
                    case .uploading, .done:
                        RoundedRectangle(cornerRadius: 12).fill(WColor.photo)
                        WIconView(icon: icon, size: 20, color: WColor.secondary)
                        if state == .uploading {
                            VStack { Spacer(); ProgressView(value: 0.55).tint(WColor.primary).padding(8) }
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if state == .done {
                        ZStack {
                            Circle().fill(WColor.success)
                            WIconView(icon: .check, size: 11, color: WColor.onSuccess, weight: .bold)
                        }
                        .frame(width: 22, height: 22)
                        .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let tag, state != .empty {
                        Text(tag)
                            .wText(.small, color: tagTone == .ok ? WColor.onSuccess : .white, weight: .semibold)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(tagTone == .ok ? WColor.success : WColor.inverse, in: Capsule())
                            .padding(8)
                    }
                }
                .frame(height: height)
                .contentShape(Rectangle())
            }
            .buttonStyle(WPressStyle())
            if showLabelBelow || state != .empty {
                Text(label).wText(.label, color: WColor.heading, weight: .medium)
            }
        }
    }
}

/// Grey placeholder used where a real photo will be (mock mode).
struct WPhotoPlaceholder: View {
    var icon: WIcon = .car
    var tag: String? = nil
    var tagTone: WTone = .mute
    var radius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(WColor.photo)
            WIconView(icon: icon, size: 18, color: WColor.secondary)
        }
        .overlay(alignment: .bottomLeading) {
            if let tag {
                Text(tag)
                    .wText(.small, color: tagTone == .ok ? WColor.onSuccess : .white, weight: .semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(tagTone == .ok ? WColor.success : WColor.inverse, in: Capsule())
                    .padding(6)
            }
        }
    }
}

// MARK: - Section label

struct WSectionLabel: View {
    let text: String
    var body: some View {
        Text(text).wText(.label).padding(.bottom, 8)
    }
}
