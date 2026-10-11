import SwiftUI
import UIKit

// MARK: Notification centre (bell on Home)

struct NotificationsScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var filter: NotificationCategory? = nil
    @State private var info: String? = nil
    @State private var confirmClear = false

    private var items: [AppNotification] {
        store.notifications.filter { filter == nil || $0.kind.category == filter }
    }

    var body: some View {
        WScreen(canvas: true) {
            WAppBar(title: "Notifications", trailing: store.customer == nil ? nil : .gear,
                    onLeading: { router.pop() }, onTrailing: { router.push(.notificationSettings) })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            if store.customer == nil {
                WFullState(icon: .bell, title: "Log in to see your updates",
                           message: "Booking updates, refunds and offers show up here once you’re logged in.",
                           primary: "Log in", onPrimary: { router.push(.login(error: false)) })
                    .padding(.top, 40)
            } else {
                statusBanner
                filters.padding(.top, 6).padding(.bottom, 4)
                if items.isEmpty {
                    emptyState.padding(.top, 50)
                } else {
                    HStack {
                        Text(store.unreadCount == 0 ? "All caught up" : "\(store.unreadCount) unread").wText(.label)
                        Spacer()
                        if store.unreadCount > 0 {
                            WLink("Mark all as read", type: .caption) { store.markAllRead() }
                        }
                    }
                    .padding(.top, 10)
                    ForEach(sections, id: \.0) { title, list in
                        Text(title).wText(.label, color: WColor.muted).padding(.top, 16).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(list) { n in
                                row(n)
                                if n.id != list.last?.id { WDivider(inset: 62) }
                            }
                        }
                        .wCard(padding: 0, radius: 16)
                    }
                    WButton("Clear all", kind: .text) { confirmClear = true }
                        .padding(.top, 16)
                    Text("Long-press a notification to delete it or mark it unread.")
                        .wText(.small, color: WColor.muted).frame(maxWidth: .infinity).padding(.top, 2)
                }
            }
        }
        .alert(info ?? "", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("Clear all notifications?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { withAnimation { store.clearNotifications() } }
        } message: {
            Text("This only clears the list. Your bookings aren’t affected.")
        }
    }

    /// Why updates might not reach the customer, with the fix one tap away.
    @ViewBuilder var statusBanner: some View {
        if !store.notificationsOn {
            WBanner(tone: .wait, icon: .bellSlash, title: "Notifications are off.",
                    text: "Updates still land here, but we won’t alert you.", actionTitle: "Turn on") {
                store.setNotifications(true)
            }
            .padding(.top, 10)
        } else if store.systemPermission == .denied {
            WBanner(tone: .error, icon: .bellSlash, title: "Blocked in iPhone Settings.",
                    text: "Allow notifications for \(Brand.name) to get alerts.", actionTitle: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .padding(.top, 10)
        } else if store.notificationPrefs.isMuted(), let until = store.notificationPrefs.mutedUntil {
            WBanner(tone: .info, icon: .speakerOff, title: "Muted until \(Fmt.day(until)), \(Fmt.time(until)).",
                    text: "Updates land here quietly.", actionTitle: "Unmute") {
                store.mute(for: nil)
            }
            .padding(.top, 10)
        }
    }

    var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                WChip(title: "All", selected: filter == nil, height: 36) { filter = nil }
                ForEach([NotificationCategory.bookings, .payments, .offers, .account], id: \.self) { c in
                    WChip(title: c.filterTitle, selected: filter == c, height: 36) { filter = c }
                }
            }
            .padding(.vertical, 2)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            WStateCircle(icon: .bell, size: 72)
            Text(filter == nil ? "No notifications yet" : "Nothing here").wText(.section, weight: .semibold)
            Text(filter == nil ? "We’ll let you know when a captain accepts, when photos are ready and when money moves."
                 : "No \(filter!.filterTitle.lowercased()) updates right now.")
                .wText(.body).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Today / Yesterday / Earlier.
    var sections: [(String, [AppNotification])] {
        let cal = Calendar.current
        var today: [AppNotification] = [], yesterday: [AppNotification] = [], earlier: [AppNotification] = []
        for n in items {
            if cal.isDateInToday(n.date) { today.append(n) }
            else if cal.isDateInYesterday(n.date) { yesterday.append(n) }
            else { earlier.append(n) }
        }
        return [("Today", today), ("Yesterday", yesterday), ("Earlier", earlier)].filter { !$0.1.isEmpty }
    }

    func row(_ n: AppNotification) -> some View {
        let expired = (n.expiresAt ?? .distantFuture) < Date()
        return Button { open(n) } label: {
            HStack(alignment: .top, spacing: 12) {
                WIconBox(icon: n.kind.icon, size: 38, tone: expired ? .mute : n.kind.tone, radius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(n.title).wText(.title, weight: n.read ? .regular : .semibold, size: 15.5)
                        Spacer(minLength: 6)
                        Text(relative(n.date)).wText(.small, color: WColor.muted)
                    }
                    Text(n.body).wText(.caption).lineLimit(3)
                    if expired { Text("Offer ended").wText(.small, color: WColor.muted).padding(.top, 2) }
                }
                Circle().fill(n.read ? .clear : WColor.primary).frame(width: 8, height: 8).padding(.top, 6)
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(n.read ? Color.clear : WColor.primaryTint.opacity(0.35))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if n.read {
                Button { store.markUnread(n.id) } label: { Label("Mark as unread", systemImage: "envelope.badge") }
            } else {
                Button { store.markRead(n.id) } label: { Label("Mark as read", systemImage: "envelope.open") }
            }
            Button(role: .destructive) { withAnimation { store.deleteNotification(n.id) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(n.read ? "" : "Unread. ")\(n.title). \(n.body)")
    }

    func open(_ n: AppNotification) {
        if case .info(let msg) = NotificationOpener.open(n, store: store, router: router) { info = msg }
    }

    func relative(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 60 { return "Now" }
        if s < 3600 { return "\(Int(s / 60)) min" }
        if Calendar.current.isDateInToday(d) { return "\(Int(s / 3600)) h" }
        if Calendar.current.isDateInYesterday(d) { return Fmt.time(d) }
        return Fmt.date(d)
    }
}

// MARK: Notification settings (Profile → Notifications, or the gear)

struct NotificationSettingsScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var confirmBookingsOff = false

    var body: some View {
        @Bindable var store = store
        let on = store.notificationsOn
        WScreen(canvas: true) {
            WAppBar(title: "Notifications", trailing: nil, onLeading: { router.pop() })
                .padding(.horizontal, 14).padding(.top, 4)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: Binding(get: { on }, set: { store.setNotifications($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow notifications").wText(.title)
                        Text(on ? "We’ll alert you about your washes." : "Off. Updates still show in the list.").wText(.caption)
                    }
                }
                .tint(WColor.primary)
            }
            .wCard(padding: 16, radius: 16)
            .padding(.top, 14)

            if store.systemPermission == .denied && on {
                WBanner(tone: .error, icon: .bellSlash, title: "Blocked in iPhone Settings.",
                        text: "We can’t alert you until you allow notifications for \(Brand.name).", actionTitle: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .padding(.top, 12)
            }

            Group {
                Text("How they arrive").wText(.label).padding(.top, 24).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(AlertStyle.allCases, id: \.self) { style in
                        Button { store.notificationPrefs.style = style } label: {
                            HStack(spacing: 12) {
                                WIconView(icon: style == .soundAndBanner ? .bell : .speakerOff, size: 16, color: WColor.primaryStrong)
                                    .frame(width: 24)
                                Text(style.title).wText(.rowTitle)
                                Spacer()
                                WRadio(on: store.notificationPrefs.style == style)
                            }
                            .padding(.vertical, 12).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if style != AlertStyle.allCases.last { WDivider(inset: 36) }
                    }
                }
                .wCard(padding: 14, radius: 16)

                Text("Mute for a while").wText(.label).padding(.top, 24).padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 12) {
                    if store.notificationPrefs.isMuted(), let until = store.notificationPrefs.mutedUntil {
                        HStack {
                            WIconView(icon: .speakerOff, size: 15, color: WColor.primaryStrong)
                            Text("Muted until \(Fmt.day(until)), \(Fmt.time(until))").wText(.bodyStrong)
                            Spacer()
                            WLink("Unmute", type: .caption) { store.mute(for: nil) }
                        }
                    } else {
                        Text("No banners or sounds. Everything still lands in the list.").wText(.caption)
                    }
                    HStack(spacing: 8) {
                        WChip(title: "1 hour", height: 38) { store.mute(for: 3600) }
                        WChip(title: "8 hours", height: 38) { store.mute(for: 8 * 3600) }
                        WChip(title: "Till morning", height: 38) { store.muteUntilMorning() }
                    }
                }
                .wCard(padding: 16, radius: 16)

                VStack(alignment: .leading, spacing: 0) {
                    Toggle(isOn: $store.notificationPrefs.quietHours) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet hours").wText(.title)
                            Text("10 PM – 7 AM: banners arrive without sound.").wText(.caption)
                        }
                    }
                    .tint(WColor.primary)
                }
                .wCard(padding: 16, radius: 16)
                .padding(.top, 12)

                Text("What you hear about").wText(.label).padding(.top, 24).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(NotificationCategory.allCases, id: \.self) { c in
                        Toggle(isOn: Binding(
                            get: { c == .account || store.notificationPrefs.categories.contains(c) },
                            set: { newValue in
                                if c == .bookings && !newValue { confirmBookingsOff = true; return }
                                if newValue { store.notificationPrefs.categories.insert(c) }
                                else { store.notificationPrefs.categories.remove(c) }
                            })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title).wText(.rowTitle)
                                Text(c.detail).wText(.caption)
                            }
                        }
                        .tint(WColor.primary)
                        .disabled(c == .account)
                        .padding(.vertical, 10)
                        if c != NotificationCategory.allCases.last { WDivider() }
                    }
                }
                .wCard(padding: 16, radius: 16)
            }
            .disabled(!on)
            .opacity(on ? 1 : 0.45)

            Text("Turning things off here never cancels a booking. Photo checks still auto-approve at midnight.")
                .wText(.small, color: WColor.muted).padding(.top, 14)
        }
        .onAppear { store.refreshSystemPermission() }
        .alert("Turn off booking updates?", isPresented: $confirmBookingsOff) {
            Button("Keep them on", role: .cancel) {}
            Button("Turn off", role: .destructive) { store.notificationPrefs.categories.remove(.bookings) }
        } message: {
            Text("You might miss when the captain arrives or when photos are ready. If you don’t check them, the wash auto-approves at midnight.")
        }
    }
}

// MARK: In-app banner and toast (shown over every screen)

struct LiveNotificationBanner: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var info: String? = nil

    var body: some View {
        VStack {
            if let n = store.liveBanner {
                Button {
                    if case .info(let m) = NotificationOpener.open(n, store: store, router: router) { info = m }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        WIconBox(icon: n.kind.icon, size: 36, tone: n.kind.tone, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.title).wText(.title, size: 15)
                            Text(n.body).wText(.caption).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: WColor.shadow, radius: 16, y: 6)
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .gesture(DragGesture(minimumDistance: 10).onEnded { v in
                    if v.translation.height < 0 { withAnimation { store.liveBanner = nil } }
                })
                .task(id: n.id) {
                    try? await Task.sleep(nanoseconds: 4_500_000_000)
                    if store.liveBanner?.id == n.id { withAnimation { store.liveBanner = nil } }
                }
            }
            Spacer()
            if let t = store.toast {
                Text(t).wText(.caption, color: .white, weight: .medium)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(WColor.inverse, in: Capsule())
                    .padding(.bottom, 100)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: t) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if store.toast == t { withAnimation { store.toast = nil } }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: store.liveBanner?.id)
        .animation(.easeOut(duration: 0.25), value: store.toast)
        .alert(info ?? "", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

/// Bell with unread count, for the Home header.
struct NotificationBell: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        Button { router.push(.notifications) } label: {
            ZStack(alignment: .topTrailing) {
                WIconView(icon: store.notificationsOn ? .bell : .bellSlash, size: 20)
                    .frame(width: 44, height: 44)
                if store.unreadCount > 0 {
                    Text(store.unreadCount > 9 ? "9+" : "\(store.unreadCount)")
                        .font(WFont.of(.small, weight: .bold, size: 10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).frame(minWidth: 17, minHeight: 17)
                        .background(WColor.destructive, in: Capsule())
                        .offset(x: 2, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.unreadCount > 0 ? "Notifications, \(store.unreadCount) unread" : "Notifications")
    }
}
