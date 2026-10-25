import SwiftUI

// MARK: - App bar

/// App bar: back (or close) on the left, title in the middle, help on the right.
struct WAppBar: View {
    var title: String = ""
    var subtitle: String? = nil
    var leading: WIcon? = .left
    var trailing: WIcon? = .help
    var dark: Bool = false
    var onLeading: () -> Void = {}
    var onTrailing: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let leading {
                    Button(action: onLeading) {
                        WIconView(icon: leading, size: 19, color: dark ? .white : WColor.heading, weight: .medium)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(leading == .close ? "Close" : "Go back")
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
            }
            VStack(spacing: 0) {
                if !title.isEmpty {
                    Text(title).wText(.appBarTitle, color: dark ? .white : WColor.heading).lineLimit(1)
                }
                if let subtitle {
                    Text(subtitle).wText(.caption, color: dark ? .white.opacity(0.7) : WColor.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            Group {
                if let trailing {
                    Button(action: onTrailing) {
                        WIconView(icon: trailing, size: 21, color: dark ? .white : WColor.heading)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(trailing == .help ? "Get help" : trailing.rawValue)
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
            }
        }
        .frame(minHeight: 56)
    }
}

// MARK: - Progress

/// Progress: thin track plus "Step 1 of 5 · Vehicle".
struct WProgress: View {
    let step: Int
    let of: Int
    var label: String? = nil
    var done: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WColor.track)
                    Capsule().fill(done ? WColor.success : WColor.primary)
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(max(of, 1)))
                }
            }
            .frame(height: 4)
            if let label {
                Text(label).wText(.label, color: WColor.primaryStrong)
            }
        }
    }
}

/// Segmented step bar used by the captain app (5 equal segments).
struct WSegmentBar: View {
    let filled: Int
    let total: Int
    var doneColor: Color = WColor.primary
    var labels: [String] = []
    var greenUpTo: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i < greenUpTo ? WColor.success : (i < filled ? doneColor : WColor.track))
                        .frame(height: 4)
                }
            }
            if !labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                        Text(l).wText(.caption, color: i < filled ? WColor.heading : WColor.secondary,
                                      weight: i < filled ? .medium : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Footer bar

/// Footer bar: 101 high, call/help on the left, the screen's one primary action on the right.
struct WFooterBar<Content: View>: View {
    var showCall: Bool = true
    var captain: Bool = false
    var onCall: () -> Void = {}
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(WColor.divider).frame(height: 1)
            HStack(spacing: 12) {
                if showCall {
                    if captain {
                        WIconButton(icon: .phone, style: .tint, size: WSize.iconButtonCaptain, label: "Call support", action: onCall)
                    } else {
                        WIconButton(icon: .phone, style: .elevated, label: "Call support", action: onCall)
                    }
                }
                content()
            }
            .padding(.horizontal, captain ? WSpace.gutterCaptain : WSpace.gutter)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(WColor.white)
    }
}

/// Footer with a primary action and a text action stacked (e.g. "Keep me posted" / "Cancel booking").
struct WStackedFooter<Content: View>: View {
    var captain: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(WColor.divider).frame(height: 1)
            VStack(spacing: 4) { content() }
                .padding(.horizontal, captain ? WSpace.gutterCaptain : WSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        .background(WColor.white)
    }
}

// MARK: - Screen scaffold

/// A screen: optional app bar, scrolling content, footer pinned to the bottom.
struct WScreen<Header: View, Content: View, Footer: View>: View {
    var canvas: Bool = false
    var gutter: CGFloat = WSpace.gutter
    var scrolls: Bool = true
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            header()
            if scrolls {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { content() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, gutter)
                        .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, gutter)
            }
            footer()
        }
        .background((canvas ? WColor.canvas : WColor.white).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Title block: Heading/Screen plus optional subtitle.
struct WTitleBlock: View {
    let title: String
    var subtitle: String? = nil
    var topPadding: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).wText(.screen).fixedSize(horizontal: false, vertical: true)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).wText(.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, topPadding)
        .padding(.bottom, 20)
    }
}

// MARK: - Cards

extension View {
    /// Elevation/Card on canvas: white, radius 20.
    func wCard(padding: CGFloat = 16, radius: CGFloat = WRadius.card) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WColor.white, in: RoundedRectangle(cornerRadius: radius))
            .shadow(color: WColor.shadowCard, radius: 10, y: 4)
    }

    /// Outlined card (border/default).
    func wOutlined(padding: CGFloat = 16, radius: CGFloat = WRadius.card, fill: Color = WColor.white,
                   stroke: Color = WColor.border, lineWidth: CGFloat = 1) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(stroke, lineWidth: lineWidth))
    }
}

// MARK: - Bottom navigation

struct WNavItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let icon: WIcon
    var badge: Int = 0
}

struct WBottomNav: View {
    let items: [WNavItem]
    @Binding var selection: Int

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(WColor.divider).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        selection = item.id
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                WIconView(icon: item.icon, size: 19,
                                          color: selection == item.id ? WColor.primaryStrong : WColor.secondary,
                                          weight: selection == item.id ? .semibold : .regular)
                                    .frame(width: 56, height: 30)
                                    .background(selection == item.id ? WColor.primaryTint : .clear, in: Capsule())
                                if item.badge > 0 {
                                    Text("\(item.badge)")
                                        .font(WFont.of(.small, weight: .bold, size: 10))
                                        .foregroundStyle(.white)
                                        .frame(width: 16, height: 16)
                                        .background(WColor.destructive, in: Circle())
                                        .offset(x: -8, y: -3)
                                }
                            }
                            Text(item.title)
                                .wText(.label, color: selection == item.id ? WColor.heading : WColor.secondary,
                                       weight: selection == item.id ? .semibold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
            }
        }
        .background(WColor.white.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Sheet

/// Bottom sheet chrome: grab handle and padding. Present with `.sheet` and a height detent.
struct WSheetChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(WColor.grab).frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)
            content()
        }
        .padding(.horizontal, WSpace.gutter)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WColor.white)
    }
}

extension View {
    /// Present a WashKrew bottom sheet sized to its content.
    func wSheet<Content: View>(isPresented: Binding<Bool>, height: CGFloat, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.sheet(isPresented: isPresented) {
            WSheetChrome(content: content)
                .presentationDetents([.height(height)])
                .presentationCornerRadius(WRadius.sheet)
                .presentationDragIndicator(.hidden)
        }
    }
}
