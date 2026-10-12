import SwiftUI

// MARK: W57 Where I work: which jobs ring for this captain

/// Four simple choices: all jobs, a distance, chosen societies, or one place.
/// The society the phone is in right now is suggested first.
struct WorkAreaScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    @State private var mode: WorkMode = .all
    @State private var radius = 3
    @State private var picked: Set<String> = []
    @State private var place = "Narsingi"
    @State private var loaded = false

    var body: some View {
        WScreen(canvas: true, gutter: WSpace.gutterCaptain) {
            WHeader(title: store.t("Where I work", "मैं कहाँ काम करूँ", "నేను ఎక్కడ పని చేస్తాను"), help: false)
        } content: {
            Text(store.t("Which jobs should ring?", "कौन से काम बजें?", "ఏ పనులు మోగాలి?")).wTitle().padding(.top, 10)
            Text(store.t("You can change this any time.", "इसे कभी भी बदल सकते हैं।", "ఎప్పుడైనా మార్చవచ్చు.")).wBodyBig().padding(.top, 4).padding(.bottom, 16)

            VStack(spacing: 12) {
                choice(.all, .layers, store.t("All jobs", "सभी काम", "అన్ని పనులు"),
                       store.t("Any job near you", "आपके आस-पास का कोई भी काम", "మీ దగ్గర ఏ పనైనా"))
                choice(.societies, .building, store.t("My societies", "मेरी सोसाइटी", "నా సొసైటీలు"),
                       store.t("Only buildings you pick", "सिर्फ़ आपकी चुनी बिल्डिंग", "మీరు ఎంచుకున్న భవనాలు మాత్రమే"))
                if mode == .societies { societies }
                choice(.radius, .locate, store.t("Distance", "दूरी", "దూరం"),
                       store.t("Jobs within a few km", "कुछ km के अंदर के काम", "కొన్ని కి.మీ లోపు పనులు"))
                if mode == .radius { radiusPicker }
                choice(.place, .location, store.t("A place I choose", "मेरी चुनी जगह", "నేను ఎంచుకున్న ప్రదేశం"),
                       store.t("Jobs in one area", "एक इलाके के काम", "ఒక ప్రాంతంలో పనులు"))
                if mode == .place { placePicker }
            }
            .padding(.bottom, 24)
        } footer: {
            WFooter {
                WButton(store.t("Save", "सेव करें", "సేవ్ చేయండి"), size: .captain,
                        enabled: mode != .societies || !picked.isEmpty) { save() }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            mode = store.workMode; radius = store.radiusKm; picked = store.chosenSocieties; place = store.workPlace
        }
    }

    func choice(_ m: WorkMode, _ icon: WIcon, _ title: String, _ sub: String) -> some View {
        WSelectionTile(icon: icon, title: title, subtitle: sub, selected: mode == m, radio: true) {
            withAnimation(.spring(duration: 0.3)) {
                mode = m
                if m == .societies && picked.isEmpty { picked = [Society.current.name] }
            }
        }
    }

    // Societies: "you're here now" first, then the rest with distance.
    var societies: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                WIconView(icon: .locate, size: 18, color: WColor.primaryStrong)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.t("You’re at \(Society.current.name) now", "आप अभी \(Society.current.name) में हैं", "మీరు ఇప్పుడు \(Society.current.name) లో ఉన్నారు"))
                        .wText(.title, size: 16)
                    WLink(store.t("Only jobs here", "सिर्फ़ यहाँ के काम", "ఇక్కడి పనులు మాత్రమే"), type: .caption) {
                        picked = [Society.current.name]
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14).background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
            VStack(spacing: 0) {
                ForEach(Society.all) { s in
                    Button {
                        if picked.contains(s.name) { picked.remove(s.name) } else { picked.insert(s.name) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: picked.contains(s.name) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 24))
                                .foregroundStyle(picked.contains(s.name) ? WColor.primary : WColor.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).wText(.rowTitle, size: 16.5)
                                Text("\(s.area) · \(String(format: s.km < 1 ? "%.0f m" : "%.1f km", s.km < 1 ? s.km * 1000 : s.km))").wText(.caption)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if s.id != Society.all.last?.id { WDivider(inset: 36) }
                }
            }
            .wCard(padding: 14)
        }
        .transition(.opacity)
    }

    var radiusPicker: some View {
        HStack(spacing: 8) {
            ForEach([1, 3, 5, 10], id: \.self) { k in
                WChip(title: "\(k) km", selected: radius == k, height: 48, fill: true) { radius = k }
            }
        }
        .transition(.opacity)
    }

    var placePicker: some View {
        WFlow(spacing: 8) {
            ForEach(Society.places, id: \.self) { p in
                WChip(title: p, selected: place == p, height: 44) { place = p }
            }
        }
        .transition(.opacity)
    }

    func save() {
        store.workMode = mode
        store.radiusKm = radius
        store.chosenSocieties = picked
        store.workPlace = place
        store.toast = store.t("Saved: \(store.workSummary)", "सेव हुआ: \(store.workSummary)", "సేవ్ అయింది: \(store.workSummary)")
        router.pop()
    }
}

/// "📍 Jobs from: … · Change" — shown on Home and under the job alert.
struct WorkAreaChip: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    var onDark = false

    var body: some View {
        Button { router.push(.workArea) } label: {
            HStack(spacing: 8) {
                WIconView(icon: .location, size: 14, color: onDark ? .white : WColor.primaryStrong)
                (Text(store.t("Jobs from: ", "काम: ", "పనులు: ")) + Text(store.workSummary).bold())
                    .wText(.caption, color: onDark ? .white : WColor.heading, size: 14.5)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(store.t("Change", "बदलें", "మార్చండి")).wText(.label, color: onDark ? .white : WColor.primaryStrong)
                WIconView(icon: .chevron, size: 11, color: onDark ? .white : WColor.primaryStrong)
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(onDark ? Color.white.opacity(0.16) : .white, in: Capsule())
            .overlay(Capsule().strokeBorder(onDark ? .clear : WColor.border))
        }
        .buttonStyle(.plain)
    }
}
