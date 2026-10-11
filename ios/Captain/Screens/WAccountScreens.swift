import SwiftUI
import PhotosUI
import UIKit

// MARK: Profile photo (Me and Home header)

/// Tap to pick a photo, long-press to remove. Separate from the KYC selfie.
struct WProfilePhoto: View {
    @Environment(CaptainStore.self) var store
    var size: CGFloat = 60
    var badge = true
    @State private var item: PhotosPickerItem? = nil

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                if let d = store.profilePhoto, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: size, height: size).clipShape(Circle())
                } else {
                    WAvatar(initials: initials, size: size)
                }
                if badge {
                    WIconView(icon: .camera, size: 11, color: .white)
                        .frame(width: 24, height: 24)
                        .background(WColor.primary, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.t("Profile photo", "प्रोफ़ाइल फ़ोटो", "ప్రొఫైల్ ఫోటో"))
        .contextMenu {
            if store.profilePhoto != nil {
                Button(store.t("Remove photo", "फ़ोटो हटाएं", "ఫోటో తీసివేయండి"), role: .destructive) { store.profilePhoto = nil }
            }
        }
        .onChange(of: item) { _, new in
            guard let new else { return }
            Task { @MainActor in
                if let data = try? await new.loadTransferable(type: Data.self) { store.profilePhoto = data }
                item = nil
            }
        }
    }

    var initials: String {
        store.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

// MARK: Bell (Home header)

struct WNotificationBell: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        Button { router.push(.notifications) } label: {
            ZStack(alignment: .topTrailing) {
                WIconView(icon: store.notificationsOn ? .bell : .bellSlash, size: 22)
                    .frame(width: 48, height: 48)
                if store.unreadCount > 0 {
                    Text(store.unreadCount > 9 ? "9+" : "\(store.unreadCount)")
                        .font(WFont.of(.small, weight: .bold, size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).frame(minWidth: 19, minHeight: 19)
                        .background(WColor.destructive, in: Capsule())
                        .offset(x: 2, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు"))
    }
}

// MARK: Notification list

struct WNotificationsScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var filter: WNotifCategory? = nil
    @State private var info: String? = nil
    @State private var confirmClear = false

    private var items: [WNotif] { store.notifications.filter { filter == nil || $0.kind.category == filter } }

    var body: some View {
        WScreen(canvas: true, gutter: WSpace.gutterCaptain) {
            WAppBar(title: store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు"), trailing: .gear,
                    onLeading: { router.pop() }, onTrailing: { router.push(.notificationSettings) })
                .padding(.horizontal, 4).padding(.top, 4)
        } content: {
            statusBanner
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    WChip(title: store.t("All", "सभी", "అన్నీ"), selected: filter == nil, height: 40) { filter = nil }
                    ForEach(WNotifCategory.allCases, id: \.self) { c in
                        WChip(title: store.categoryTitle(c), selected: filter == c, height: 40) { filter = c }
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.top, 10)
            if items.isEmpty {
                VStack(spacing: 12) {
                    WStateCircle(icon: .bell, size: 80)
                    Text(store.t("Nothing here yet", "अभी कुछ नहीं", "ఇంకా ఏమీ లేదు")).wText(.section, weight: .semibold)
                    Text(store.t("New jobs, money and level updates show up here.", "नए काम, पैसे और लेवल की खबरें यहाँ दिखेंगी।", "కొత్త పనులు, డబ్బు, స్థాయి వివరాలు ఇక్కడ కనిపిస్తాయి."))
                        .wBodyBig().multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.top, 50)
            } else {
                HStack {
                    Text(store.unreadCount == 0 ? store.t("All read", "सब पढ़ लिया", "అన్నీ చదివారు")
                         : store.t("\(store.unreadCount) new", "\(store.unreadCount) नई", "\(store.unreadCount) కొత్తవి")).wText(.label)
                    Spacer()
                    if store.unreadCount > 0 {
                        WLink(store.t("Mark all read", "सब पढ़ा हुआ करें", "అన్నీ చదివినట్లు"), type: .caption) { store.markAllRead() }
                    }
                }
                .padding(.top, 12)
                ForEach(sections, id: \.0) { title, list in
                    Text(title).wText(.label, color: WColor.muted).padding(.top, 16).padding(.bottom, 8)
                    VStack(spacing: 0) {
                        ForEach(list) { n in
                            row(n)
                            if n.id != list.last?.id { WDivider(inset: 70) }
                        }
                    }
                    .wCard(padding: 0, radius: 16)
                }
                WButton(store.t("Clear all", "सब हटाएं", "అన్నీ తొలగించండి"), kind: .text) { confirmClear = true }.padding(.top, 16)
                Text(store.t("Press and hold a message to delete it or mark it unread.",
                             "किसी संदेश को दबाकर रखें: हटाएं या ‘नहीं पढ़ा’ करें।",
                             "సందేశాన్ని నొక్కి పట్టుకోండి: తొలగించండి లేదా చదవనిదిగా మార్చండి."))
                    .wText(.small, color: WColor.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.bottom, 20)
            }
        }
        .alert(info ?? "", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog(store.t("Clear all messages?", "सब संदेश हटाएं?", "అన్ని సందేశాలు తొలగించాలా?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(store.t("Clear all", "सब हटाएं", "అన్నీ తొలగించండి"), role: .destructive) { withAnimation { store.clearNotifications() } }
        } message: {
            Text(store.t("Your jobs and money are not affected.", "आपके काम और पैसे पर असर नहीं होगा।", "మీ పనులు, డబ్బుపై ప్రభావం ఉండదు."))
        }
    }

    @ViewBuilder var statusBanner: some View {
        if !store.notificationsOn {
            WBanner(tone: .wait, icon: .bellSlash, title: store.t("Alerts are off.", "अलर्ट बंद हैं।", "అలర్ట్‌లు ఆఫ్‌లో ఉన్నాయి."),
                    text: store.online ? store.t("New jobs still ring while you’re Online.", "ऑनलाइन रहते नए काम फिर भी बजेंगे।", "ఆన్‌లైన్‌లో ఉన్నప్పుడు కొత్త పనులు మోగుతాయి.")
                                       : store.t("Messages still come here.", "संदेश फिर भी यहाँ आएंगे।", "సందేశాలు ఇక్కడికి వస్తాయి."),
                    actionTitle: store.t("Turn on", "चालू करें", "ఆన్ చేయండి")) { store.setNotifications(true) }
                .padding(.top, 10)
        } else if store.systemPermission == .denied {
            WBanner(tone: .error, icon: .bellSlash, title: store.t("Blocked in iPhone Settings.", "iPhone सेटिंग में बंद है।", "iPhone సెట్టింగ్స్‌లో బ్లాక్ అయింది."),
                    text: store.t("You may miss new jobs. Allow notifications.", "नए काम छूट सकते हैं। सूचनाएं चालू करें।", "కొత్త పనులు మిస్ కావచ్చు. నోటిఫికేషన్లు అనుమతించండి."),
                    actionTitle: store.t("Open Settings", "सेटिंग खोलें", "సెట్టింగ్స్ తెరవండి")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .padding(.top, 10)
        } else if store.notifPrefs.isMuted(), let until = store.notifPrefs.mutedUntil {
            WBanner(tone: .info, icon: .speakerOff,
                    title: store.t("Muted till", "बंद है", "మ్యూట్") + " \(Fmt.time(until))",
                    text: store.t("New jobs still ring while Online.", "ऑनलाइन रहते नए काम फिर भी बजेंगे।", "ఆన్‌లైన్‌లో కొత్త పనులు మోగుతాయి."),
                    actionTitle: store.t("Unmute", "चालू करें", "అన్‌మ్యూట్")) { store.mute(for: nil) }
                .padding(.top, 10)
        }
    }

    var sections: [(String, [WNotif])] {
        let cal = Calendar.current
        var a: [WNotif] = [], b: [WNotif] = [], c: [WNotif] = []
        for n in items {
            if cal.isDateInToday(n.date) { a.append(n) } else if cal.isDateInYesterday(n.date) { b.append(n) } else { c.append(n) }
        }
        return [(store.t("Today", "आज", "ఈరోజు"), a), (store.t("Yesterday", "कल", "నిన్న"), b), (store.t("Earlier", "पहले", "ఇంతకు ముందు"), c)]
            .filter { !$0.1.isEmpty }
    }

    func row(_ n: WNotif) -> some View {
        Button {
            if let m = WNotifOpener.open(n, store: store, router: router) { info = m }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                WIconBox(icon: n.kind.icon, size: 44, tone: n.kind.tone, radius: 12)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(store.title(n)).wText(.title, weight: n.read ? .regular : .semibold, size: 16.5)
                        Spacer(minLength: 6)
                        Text(relative(n.date)).wText(.small, color: WColor.muted)
                    }
                    Text(store.body(n)).wText(.caption, size: 14.5).lineLimit(3)
                }
                Circle().fill(n.read ? .clear : WColor.primary).frame(width: 9, height: 9).padding(.top, 7)
            }
            .padding(14)
            .background(n.read ? Color.clear : WColor.primaryTint.opacity(0.35))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if n.read {
                Button { store.markUnread(n.id) } label: { Label(store.t("Mark unread", "‘नहीं पढ़ा’ करें", "చదవనిదిగా"), systemImage: "envelope.badge") }
            } else {
                Button { store.markRead(n.id) } label: { Label(store.t("Mark read", "पढ़ा हुआ करें", "చదివినట్లు"), systemImage: "envelope.open") }
            }
            Button(role: .destructive) { withAnimation { store.deleteNotification(n.id) } } label: {
                Label(store.t("Delete", "हटाएं", "తొలగించండి"), systemImage: "trash")
            }
        }
    }

    func relative(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 60 { return store.t("Now", "अभी", "ఇప్పుడు") }
        if s < 3600 { return "\(Int(s / 60)) min" }
        if Calendar.current.isDateInToday(d) { return "\(Int(s / 3600)) h" }
        if Calendar.current.isDateInYesterday(d) { return Fmt.time(d) }
        return Fmt.date(d)
    }
}

// MARK: Notification settings

struct WNotificationSettingsScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router

    var body: some View {
        @Bindable var store = store
        let on = store.notificationsOn
        WScreen(canvas: true, gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Notifications", "सूचनाएं", "నోటిఫికేషన్లు"), help: false)
        } content: {
            Toggle(isOn: Binding(get: { on }, set: { store.setNotifications($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t("Alerts", "अलर्ट", "అలర్ట్‌లు")).wText(.title, size: 18)
                    Text(on ? store.t("Banner and sound for updates.", "खबरों पर बैनर और आवाज़।", "అప్‌డేట్‌లకు బ్యానర్, శబ్దం.")
                            : store.t("Off. Messages still come to the list.", "बंद। संदेश लिस्ट में आएंगे।", "ఆఫ్. సందేశాలు లిస్ట్‌లో వస్తాయి.")).wText(.caption)
                }
            }
            .tint(WColor.primary).wCard(padding: 16, radius: 16).padding(.top, 10)

            HStack(alignment: .top, spacing: 12) {
                WIconView(icon: .bell, size: 17, color: WColor.heading)
                Text(store.t("New jobs always ring while you’re Online. To stop them, go Offline.",
                             "ऑनलाइन रहते नए काम हमेशा बजेंगे। रोकने के लिए ऑफ़लाइन जाएं।",
                             "ఆన్‌లైన్‌లో ఉన్నప్పుడు కొత్త పనులు ఎప్పుడూ మోగుతాయి. ఆపడానికి ఆఫ్‌లైన్‌కి వెళ్ళండి."))
                    .wText(.caption, color: WColor.inverse, size: 14.5)
                Spacer(minLength: 0)
            }
            .padding(16).background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14)).padding(.top, 12)

            if store.systemPermission == .denied && on {
                WBanner(tone: .error, icon: .bellSlash, title: store.t("Blocked in iPhone Settings.", "iPhone सेटिंग में बंद है।", "iPhone సెట్టింగ్స్‌లో బ్లాక్."),
                        text: store.t("Allow notifications so the phone rings for jobs.", "सूचनाएं चालू करें ताकि काम पर फ़ोन बजे।", "పనులకు ఫోన్ మోగాలంటే నోటిఫికేషన్లు అనుమతించండి."),
                        actionTitle: store.t("Open Settings", "सेटिंग खोलें", "సెట్టింగ్స్ తెరవండి")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .padding(.top, 12)
            }

            Group {
                Toggle(isOn: $store.notifPrefs.soundOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("Sound", "आवाज़", "శబ్దం")).wText(.title, size: 18)
                        Text(store.t("Off: banner only, no sound.", "बंद: सिर्फ़ बैनर, आवाज़ नहीं।", "ఆఫ్: బ్యానర్ మాత్రమే, శబ్దం లేదు.")).wText(.caption)
                    }
                }
                .tint(WColor.primary).wCard(padding: 16, radius: 16).padding(.top, 20)

                Text(store.t("Mute for a while", "कुछ देर बंद करें", "కాసేపు మ్యూట్")).wText(.label).padding(.top, 22).padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 12) {
                    if store.notifPrefs.isMuted(), let until = store.notifPrefs.mutedUntil {
                        HStack {
                            WIconView(icon: .speakerOff, size: 16, color: WColor.primaryStrong)
                            Text(store.t("Muted till", "बंद है", "మ్యూట్") + " \(Fmt.day(until)), \(Fmt.time(until))").wText(.bodyStrong)
                            Spacer()
                            WLink(store.t("Unmute", "चालू करें", "అన్‌మ్యూట్"), type: .caption) { store.mute(for: nil) }
                        }
                    }
                    HStack(spacing: 8) {
                        WChip(title: store.t("1 hour", "1 घंटा", "1 గంట"), height: 44) { store.mute(for: 3600) }
                        WChip(title: store.t("8 hours", "8 घंटे", "8 గంటలు"), height: 44) { store.mute(for: 8 * 3600) }
                        WChip(title: store.t("Till morning", "सुबह तक", "ఉదయం వరకు"), height: 44) { store.muteUntilMorning() }
                    }
                }
                .wCard(padding: 16, radius: 16)

                Toggle(isOn: $store.notifPrefs.quietHours) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("Quiet at night", "रात में शांत", "రాత్రి నిశ్శబ్దం")).wText(.title, size: 18)
                        Text(store.t("10 PM – 7 AM: no sound.", "रात 10 – सुबह 7: आवाज़ नहीं।", "రాత్రి 10 – ఉదయం 7: శబ్దం లేదు.")).wText(.caption)
                    }
                }
                .tint(WColor.primary).wCard(padding: 16, radius: 16).padding(.top, 12)

                Text(store.t("What you hear about", "किस बारे में", "వేటి గురించి")).wText(.label).padding(.top, 22).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(WNotifCategory.allCases, id: \.self) { c in
                        Toggle(isOn: Binding(
                            get: { c == .account || !store.notifPrefs.off.contains(c) },
                            set: { if $0 { store.notifPrefs.off.remove(c) } else { store.notifPrefs.off.insert(c) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.categoryTitle(c)).wText(.rowTitle, size: 17)
                                Text(store.categoryDetail(c)).wText(.caption)
                            }
                        }
                        .tint(WColor.primary).disabled(c == .account).padding(.vertical, 10)
                        if c != WNotifCategory.allCases.last { WDivider() }
                    }
                }
                .wCard(padding: 16, radius: 16)
            }
            .disabled(!on).opacity(on ? 1 : 0.45)
            .padding(.bottom, 24)
        }
        .onAppear { store.refreshSystemPermission() }
    }
}

// MARK: Banner + toast over every screen

struct WLiveBanner: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var info: String? = nil

    var body: some View {
        VStack {
            if let n = store.liveBanner {
                Button {
                    if let m = WNotifOpener.open(n, store: store, router: router) { info = m }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        WIconBox(icon: n.kind.icon, size: 40, tone: n.kind.tone, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.title(n)).wText(.title, size: 16)
                            Text(store.body(n)).wText(.caption).lineLimit(2)
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
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if store.liveBanner?.id == n.id { withAnimation { store.liveBanner = nil } }
                }
            }
            Spacer()
            if let t = store.toast {
                Text(t).wText(.caption, color: .white, weight: .medium)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(WColor.inverse, in: Capsule())
                    .padding(.bottom, 110)
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

// MARK: Change phone (code to the new number)

struct WChangePhoneScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    enum Stage { case number, code, done }
    @State private var stage: Stage = .number
    @State private var phone = ""
    @State private var code = ""
    @State private var wrong = false
    @State private var loading = false

    private var digits: String { String(Validators.digitsOnly(phone).prefix(10)) }
    private var canSend: Bool { Validators.isValidMobile(phone) && digits != store.phone }

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Phone number", "फ़ोन नंबर", "ఫోన్ నంబర్"))
        } content: {
            switch stage {
            case .number:
                Text(store.t("New number", "नया नंबर", "కొత్త నంబర్")).wTitle().padding(.top, 10)
                Text(store.t("Now: \(Fmt.phone(store.phone)). We send a code to the new number.",
                             "अभी: \(Fmt.phone(store.phone))। नए नंबर पर कोड भेजेंगे।",
                             "ఇప్పుడు: \(Fmt.phone(store.phone)). కొత్త నంబర్‌కి కోడ్ పంపుతాము."))
                    .wBodyBig().padding(.top, 6).padding(.bottom, 18)
                WPhoneField(number: $phone, large: true)
                if digits == store.phone {
                    Text(store.t("That’s your current number.", "यह आपका अभी का नंबर है।", "ఇది మీ ప్రస్తుత నంబర్.")).wText(.caption).padding(.top, 8)
                }
            case .code:
                Text(store.t("Enter the code", "कोड डालें", "కోడ్ ఎంటర్ చేయండి")).wTitle().padding(.top, 10)
                Text(store.t("Sent to \(Fmt.phone(digits)).", "\(Fmt.phone(digits)) पर भेजा।", "\(Fmt.phone(digits)) కి పంపాము."))
                    .wBodyBig().padding(.top, 6).padding(.bottom, 22)
                WOtpField(code: $code, error: wrong, boxSize: 48)
                    .onChange(of: code) { _, new in
                        if wrong && new.count < 6 { wrong = false }
                        if new.count == 6 { verify() }
                    }
                if wrong {
                    Text(store.t("Wrong code. Try again.", "गलत कोड। फिर कोशिश करें।", "తప్పు కోడ్. మళ్ళీ ప్రయత్నించండి.")).wText(.caption, color: WColor.destructive).padding(.top, 14)
                }
                Text("Demo code: 123456").wText(.caption, color: WColor.muted).padding(.top, 30)
            case .done:
                WFullState(icon: .check, tone: .ok, title: store.t("Number changed", "नंबर बदल गया", "నంబర్ మారింది"),
                           message: store.t("Log in with \(Fmt.phone(store.phone)) from now.", "अब \(Fmt.phone(store.phone)) से लॉग इन करें।", "ఇకపై \(Fmt.phone(store.phone)) తో లాగిన్ అవ్వండి."),
                           primary: store.t("Done", "ठीक है", "సరే"), captain: true, onPrimary: { router.pop() })
                    .padding(.top, 40)
            }
        } footer: {
            if stage != .done {
                WFooter {
                    if stage == .number {
                        WButton(store.t("Send code", "कोड भेजें", "కోడ్ పంపండి"), size: .captain, enabled: canSend, loading: loading) { send() }
                    } else {
                        WButton(store.t("Verify", "जाँचें", "ధృవీకరించండి"), size: .captain, enabled: code.count == 6, loading: loading) { verify() }
                    }
                }
            }
        }
    }

    private func send() {
        guard canSend else { return }
        loading = true
        Task { @MainActor in
            await store.requestPhoneChange(digits)
            loading = false; code = ""; wrong = false; stage = .code
        }
    }

    private func verify() {
        guard !loading, code.count == 6 else { return }
        loading = true
        Task { @MainActor in
            let ok = await store.confirmPhoneChange(code)
            loading = false
            if ok { stage = .done } else { wrong = true }
        }
    }
}

// MARK: Change payout UPI (code to the registered phone)

struct WEditUPIScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    enum Stage { case upi, code }
    @State private var stage: Stage = .upi
    @State private var upi = ""
    @State private var code = ""
    @State private var showError = false
    @State private var wrong = false
    @State private var loading = false

    private var valid: Bool { Validators.isValidUPI(upi) }
    private var same: Bool { upi.lowercased() == store.upi.lowercased() }

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Payout UPI", "पेमेंट UPI", "చెల్లింపు UPI"))
        } content: {
            switch stage {
            case .upi:
                Text(store.t("Where should money go?", "पैसे कहाँ भेजें?", "డబ్బు ఎక్కడికి పంపాలి?")).wTitle().padding(.top, 10)
                Text(store.t("Now: \(store.upi)", "अभी: \(store.upi)", "ఇప్పుడు: \(store.upi)")).wBodyBig().padding(.top, 6).padding(.bottom, 18)
                WTextField(label: "UPI ID", text: $upi, placeholder: "name@ybl",
                           helper: store.t("Like name@ybl or 9876543210@paytm", "जैसे name@ybl या 9876543210@paytm", "ఉదా: name@ybl లేదా 9876543210@paytm"),
                           error: showError && !valid ? store.t("Check the UPI ID. It needs an @.", "UPI ID जाँचें। इसमें @ होना चाहिए।", "UPI ID చూడండి. అందులో @ ఉండాలి.") : nil,
                           keyboard: .emailAddress, capitalization: .never, large: true, focusOnAppear: true, onSubmit: send)
                    .onChange(of: upi) { _, _ in showError = false }
                if same && !upi.isEmpty {
                    Text(store.t("That’s your current UPI.", "यह आपका अभी का UPI है।", "ఇది మీ ప్రస్తుత UPI.")).wText(.caption).padding(.top, 8)
                }
                HStack(alignment: .top, spacing: 10) {
                    WIconView(icon: .shield, size: 15, color: WColor.secondary)
                    Text(store.t("For safety we send a code to \(Fmt.phone(store.phone)) first.",
                                 "सुरक्षा के लिए पहले \(Fmt.phone(store.phone)) पर कोड भेजेंगे।",
                                 "భద్రత కోసం ముందుగా \(Fmt.phone(store.phone)) కి కోడ్ పంపుతాము."))
                        .wText(.caption)
                }
                .padding(.top, 18)
            case .code:
                Text(store.t("Enter the code", "कोड डालें", "కోడ్ ఎంటర్ చేయండి")).wTitle().padding(.top, 10)
                Text(store.t("Sent to \(Fmt.phone(store.phone)). UPI changes to \(store.pendingUPI) after this.",
                             "\(Fmt.phone(store.phone)) पर भेजा। इसके बाद UPI \(store.pendingUPI) होगा।",
                             "\(Fmt.phone(store.phone)) కి పంపాము. తర్వాత UPI \(store.pendingUPI) అవుతుంది."))
                    .wBodyBig().padding(.top, 6).padding(.bottom, 22)
                WOtpField(code: $code, error: wrong, boxSize: 48)
                    .onChange(of: code) { _, new in
                        if wrong && new.count < 6 { wrong = false }
                        if new.count == 6 { verify() }
                    }
                if wrong {
                    Text(store.t("Wrong code. Try again.", "गलत कोड। फिर कोशिश करें।", "తప్పు కోడ్. మళ్ళీ ప్రయత్నించండి.")).wText(.caption, color: WColor.destructive).padding(.top, 14)
                }
                Text("Demo code: 123456").wText(.caption, color: WColor.muted).padding(.top, 30)
            }
        } footer: {
            WFooter {
                if stage == .upi {
                    WButton(store.t("Send code", "कोड भेजें", "కోడ్ పంపండి"), size: .captain, enabled: !upi.isEmpty && !same, loading: loading) { send() }
                } else {
                    WButton(store.t("Verify and save", "जाँचें और सेव करें", "ధృవీకరించి సేవ్ చేయండి"), size: .captain, enabled: code.count == 6, loading: loading) { verify() }
                }
            }
        }
        .onAppear { if upi.isEmpty { upi = store.upi } }
    }

    private func send() {
        guard valid else { showError = true; return }
        guard !same else { return }
        loading = true
        Task { @MainActor in
            await store.requestUPIChange(upi)
            loading = false; code = ""; wrong = false; stage = .code
        }
    }

    private func verify() {
        guard !loading, code.count == 6 else { return }
        loading = true
        Task { @MainActor in
            let ok = await store.confirmUPIChange(code)
            loading = false
            if ok {
                store.toast = store.t("UPI saved", "UPI सेव हो गया", "UPI సేవ్ అయింది")
                router.pop()
            } else { wrong = true }
        }
    }
}

// MARK: Job cancelled: didn't reach in time

struct WNoShowCancelledScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var body: some View {
        let plate = store.noShowPlate.isEmpty ? store.current.plate : store.noShowPlate
        WScreen(gutter: WSpace.gutterCaptain, scrolls: false) { EmptyView() } content: {
            VStack(spacing: 14) {
                Spacer()
                WStateCircle(icon: .ban, tone: .error, size: 112)
                Text(store.t("Job cancelled", "काम रद्द हुआ", "పని రద్దయింది")).wText(.section, weight: .semibold, size: 23)
                WPlate(text: plate)
                Text(store.t("You didn’t reach or update the job in the time slot. The owner got a full refund.",
                             "आप समय पर नहीं पहुँचे और काम अपडेट नहीं किया। मालिक को पूरे पैसे वापस मिले।",
                             "మీరు సమయానికి చేరుకోలేదు, పని అప్‌డేట్ చేయలేదు. యజమానికి పూర్తి డబ్బు తిరిగి వచ్చింది."))
                    .wBodyBig().multilineTextAlignment(.center)
                HStack(alignment: .top, spacing: 12) {
                    WIconView(icon: .rupee, size: 17, color: WColor.destructive)
                    Text(store.t("Penalty ₹[NO-SHOW PENALTY] is cut from your next payout.",
                                 "जुर्माना ₹[NO-SHOW PENALTY] अगले पेमेंट से कटेगा।",
                                 "జరిమానా ₹[NO-SHOW PENALTY] తదుపరి చెల్లింపు నుండి తగ్గుతుంది."))
                        .wText(.caption, color: WTone.error.bannerText, size: 14.5)
                    Spacer(minLength: 0)
                }
                .padding(16).background(WTone.error.background, in: RoundedRectangle(cornerRadius: 14))
                Text(store.t("If you can’t reach a job, call support before the slot ends.",
                             "अगर काम पर नहीं पहुँच सकते, तो समय खत्म होने से पहले सपोर्ट को कॉल करें।",
                             "పనికి చేరుకోలేకపోతే, సమయం ముగియక ముందే సపోర్ట్‌కి కాల్ చేయండి."))
                    .wText(.caption).multilineTextAlignment(.center)
                Spacer()
            }
        } footer: {
            WFooter {
                WButton(store.t("Back to jobs", "कामों पर वापस", "పనులకు తిరిగి"), size: .captain) { router.home(); router.tab = 1 }
            }
        }
    }
}
