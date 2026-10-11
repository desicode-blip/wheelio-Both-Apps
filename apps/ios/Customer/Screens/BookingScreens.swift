import SwiftUI

/// Header used by every booking step: app bar + "Step n of 5 · Label".
struct BookingHeader: View {
    @Environment(Router.self) var router
    @Environment(\.stepTotal) var total
    let step: Int
    let label: String
    var title = "Book a wash"
    var fraction: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WAppBar(title: title, onLeading: { router.pop() }, onTrailing: { router.push(.help) })
                .padding(.horizontal, 14)
            WProgress(step: Int(((fraction ?? Double(step) / Double(total)) * 100).rounded()), of: 100, label: "Step \(step) of \(total) · \(label)")
                .padding(.horizontal, WSpace.gutter)
        }
        .padding(.top, 4)
    }
}

// MARK: C05 Vehicle type (C52: 200% text)

struct VehicleTypeScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var largeText = false

    var body: some View {
        WScreen {
            BookingHeader(step: 1, label: "Vehicle", fraction: 0.2)
        } content: {
            WTitleBlock(title: "What are we washing?", subtitle: largeText ? nil : "Pick your vehicle. You choose the wash next.")
            VStack(spacing: 12) {
                ForEach(largeText ? Array(VehicleType.all.prefix(2)) : VehicleType.all) { t in
                    if largeText {
                        largeTile(t)
                    } else {
                        WSelectionTile(icon: t.icon, title: t.name, subtitle: "About \(t.minutes) min",
                                       trailing: Fmt.rupees(t.price), selected: store.draft.type == t) {
                            store.draft.type = t
                        }
                    }
                }
            }
        } footer: {
            if largeText {
                VStack(spacing: 0) {
                    WDivider()
                    WButton("Next", enabled: store.draft.type != nil) { router.push(.washType) }
                        .padding(.horizontal, WSpace.gutter).padding(.vertical, 12)
                }
            } else {
                WFooterBar(showCall: false) {
                    WButton("Next", enabled: store.draft.type != nil) { router.push(.washType) }
                }
            }
        }
        .onAppear { if store.draft.type == nil && !largeText { store.draft.type = VehicleType.all[1] } }
        .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
    }

    /// C52: at 200% text the tile stacks so nothing is cut off.
    private func largeTile(_ t: VehicleType) -> some View {
        let sel = store.draft.type == t
        return Button { store.draft.type = t } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.name).wText(.section, weight: .semibold)
                Text("About \(t.minutes) min").wText(.body)
                Text(Fmt.rupees(t.price)).wText(.section, weight: .bold)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sel ? WColor.primaryTint : .white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(sel ? WColor.primary : WColor.border, lineWidth: sel ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Wash type (after C05)

struct WashTypeScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var showVideoSoon = false
    @State private var showNotAvailable = false

    private var isBike: Bool { store.draft.type?.kind == .bike }
    private var options: [WashKind] { WashKind.options(for: store.draft.type?.kind) }

    var body: some View {
        WScreen {
            BookingHeader(step: 1, label: "Vehicle", fraction: 0.2)
        } content: {
            WTitleBlock(title: "What kind of wash?",
                        subtitle: "Same price for every option\(store.draft.type.map { ": \(Fmt.rupees($0.price))" } ?? "").")
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { w in tile(w) }
            }
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Next", enabled: store.draft.wash != nil) { router.push(.vehicleNumber) }
            }
        }
        .onAppear {
            if let w = store.draft.wash, options.contains(w), w.available { return }
            store.draft.wash = .wetOutside
        }
        .alert("Video coming soon", isPresented: $showVideoSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We’re making a short video that shows this wash. For now, pick the one you like and carry on.")
        }
        .alert("Not available in your society yet", isPresented: $showNotAvailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Inside cleaning isn’t offered in your society right now. We’ll let you know when it is.")
        }
    }

    private func tile(_ w: WashKind) -> some View {
        let selected = store.draft.wash == w
        return HStack(spacing: 14) {
            WIconBox(icon: w.icon, size: 48, tone: w.available ? .info : .mute)
            VStack(alignment: .leading, spacing: 2) {
                Text(w.name(bike: isBike)).wText(.title).fixedSize(horizontal: false, vertical: true)
                Text(w.detail(bike: isBike)).wText(.caption).fixedSize(horizontal: false, vertical: true)
                if !w.available {
                    Text("Not in your society yet").wText(.label, color: WColor.secondary).padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            Button { showVideoSoon = true } label: {
                WIconView(icon: .eye, size: 18, color: WColor.primaryStrong)
                    .frame(width: 44, height: 44)
                    .background(WColor.primaryTint.opacity(selected ? 0 : 1), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See what \(w.name(bike: isBike)) means")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? WColor.primaryTint : WColor.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(selected ? WColor.primary : WColor.border, lineWidth: selected ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .opacity(w.available ? 1 : 0.7)
        .onTapGesture {
            if w.available { store.draft.wash = w } else { showNotAvailable = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}


// MARK: C06 Vehicle number
// Any number is accepted as typed (no format check), so customers never hit an error here.

struct VehicleNumberScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var plate = ""

    private var trimmed: String { plate.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        WScreen {
            BookingHeader(step: 1, label: "Vehicle", fraction: 0.2)
        } content: {
            WTitleBlock(title: "What’s the number plate?", subtitle: "So the captain finds the right vehicle.")
            WTextField(label: "Vehicle number", text: $plate, placeholder: "TS 09 EA 4521",
                       helper: "Use the number on your plate",
                       capitalization: .characters, focusOnAppear: true, onSubmit: next)
            if let t = store.draft.type {
                HStack(spacing: 10) {
                    WIconBox(icon: t.icon, size: 38, radius: 10)
                    (Text("\(t.shortName) · \(Fmt.rupees(t.price)) · ")
                     + Text("Change").underline().foregroundColor(WColor.primaryStrong))
                        .wText(.caption)
                }
                .onTapGesture { router.pop() }
                .padding(.top, 22)
            }
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Next", enabled: !trimmed.isEmpty, action: next)
            }
        }
        .onAppear {
            if plate.isEmpty { plate = store.draft.plate }
        }
    }

    private func next() {
        guard !trimmed.isEmpty else { return }
        store.draft.plate = trimmed.uppercased()
        router.push(.photos)
    }
}

// MARK: C07 Photos (C07b partial, C07c done)

struct PhotosScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State private var showSkipWarning = false

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        let d = store.draft
        WScreen {
            BookingHeader(step: 2, label: "Photos", fraction: 0.4)
        } content: {
            if d.photosComplete {
                WTitleBlock(title: "Looking good", subtitle: "4 photos\(d.videoSeconds != nil ? " and a video" : ""). Tap any photo to retake.")
            } else if d.photos.isEmpty {
                WTitleBlock(title: "Take 4 quick photos", subtitle: "They help the captain find your vehicle. The captain takes the official before photos.")
            } else {
                WTitleBlock(title: "Take 4 quick photos", subtitle: "\(d.photosDone) of 4 done")
            }
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(PhotoAngle.allCases, id: \.self) { a in
                    WPhotoSlot(label: a.label, state: slotState(d.photos[a]), height: d.photos.isEmpty ? 126 : 98) {
                        if d.photos[a] == .failed {
                            Task { await store.uploadPhoto(a) }
                        } else {
                            router.push(.camera(a, denied: false))
                        }
                    }
                }
            }
            if d.hasFailedPhoto {
                WBanner(tone: .error, icon: .wifiOff, text: "Back photo didn’t upload. It’s saved on your phone.", actionTitle: "Retry") {
                    if let a = PhotoAngle.allCases.first(where: { d.photos[$0] == .failed }) { Task { await store.uploadPhoto(a) } }
                }
                .padding(.top, 20)
            }
            if let v = d.videoSeconds, d.photosComplete {
                HStack(spacing: 12) {
                    WIconView(icon: .video, size: 17, color: WColor.primaryStrong)
                    Text("Walk-around video · \(Fmt.clock(v))").wText(.bodyStrong, color: WColor.heading)
                    Spacer()
                    WIconView(icon: .check, size: 15, color: WColor.heading)
                }
                .padding(.horizontal, 16).frame(height: 46)
                .background(WColor.canvas, in: Capsule())
                .padding(.top, 20)
            } else if !d.hasFailedPhoto {
                Button { store.draft.videoSeconds = 14 } label: {
                    HStack(spacing: 10) {
                        WIconView(icon: .video, size: 17, color: WColor.primaryStrong)
                        Text("Walk-around video · optional, 15 sec").wText(.bodyStrong, color: WColor.primaryStrong, weight: .medium)
                    }
                    .frame(maxWidth: .infinity).frame(height: 62)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WColor.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
        } footer: {
            WFooterBar(showCall: false) {
                VStack(spacing: 2) {
                    WButton("Next", enabled: d.photosComplete) { goNext() }
                    if !d.photosComplete {
                        // Photos are optional for the customer: the captain takes the official before photos.
                        WLink("Skip for now", color: WColor.secondary, type: .caption) { showSkipWarning = true }
                    }
                }
            }
        }
        .alert("Skip the photos?", isPresented: $showSkipWarning) {
            Button("Take photos", role: .cancel) {}
            Button("Skip anyway") { goNext() }
        } message: {
            Text("Without your photos from before the wash, we won’t be able to take up any claim if something goes wrong later.")
        }
    }

    private func goNext() {
        router.push(store.draft.place == nil ? .location(off: false) : .floorSlot)
    }

    private func slotState(_ s: UploadState?) -> WPhotoState {
        switch s {
        case .none: return .empty
        case .some(.uploading): return .uploading
        case .some(.done): return .done
        case .some(.failed): return .failed
        }
    }
}

// MARK: C08 Camera (C08b access needed)

struct CameraScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let angle: PhotoAngle
    var forceDenied = false
    @State var denied = false
    @State var current: PhotoAngle = .front

    var body: some View {
        Group {
            if denied || forceDenied {
                WScreen {
                    WAppBar(onLeading: { router.pop() }, onTrailing: { router.push(.help) }).padding(.horizontal, 14)
                } content: {
                    WFullState(icon: .camera, tone: .wait, title: "Camera access needed",
                               message: "Photos help the captain find your vehicle. Allow camera to continue.",
                               primary: "Allow camera", secondary: "Skip photos for now",
                               onPrimary: { denied = false },
                               onSecondary: {
                                   for a in PhotoAngle.allCases { store.draft.photos[a] = .done }
                                   router.pop()
                               })
                    .frame(minHeight: 600)
                }
            } else {
                camera
            }
        }
        .onAppear { current = angle }
    }

    private var index: Int { PhotoAngle.allCases.firstIndex(of: current)! }

    private var camera: some View {
        VStack(spacing: 0) {
            WAppBar(title: "\(current.label) · \(index + 1) of 4", leading: .close, trailing: nil, dark: true,
                    onLeading: { router.pop() })
                .padding(.horizontal, 14)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 20).fill(WColor.cameraPanel)
                CarOutline()
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, dash: [9, 7]))
                    .frame(width: 250, height: 160)
                    .frame(maxHeight: .infinity)
                Text("Fit the \(current.label.lowercased()) of the vehicle in the outline")
                    .wText(.body, color: .white.opacity(0.9))
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            HStack {
                Spacer().frame(width: 60)
                Spacer()
                Button(action: shoot) {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 5).frame(width: 78, height: 78)
                        Circle().fill(.white).frame(width: 62, height: 62)
                    }
                }
                .accessibilityLabel("Take photo")
                Spacer()
                WIconView(icon: .flash, size: 20, color: .white.opacity(0.5)).frame(width: 60)
            }
            .padding(.vertical, 24)
        }
        .background(WColor.camera.ignoresSafeArea())
    }

    private func shoot() {
        let a = current
        Task { await store.uploadPhoto(a) }
        if let next = PhotoAngle.allCases.first(where: { store.draft.photos[$0] == nil && $0 != a }) {
            current = next
        } else {
            router.pop()
        }
    }
}

/// Dashed car outline for the guided camera.
struct CarOutline: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        // body
        p.addRoundedRect(in: CGRect(x: r.minX, y: r.minY + h * 0.28, width: w, height: h * 0.52), cornerSize: CGSize(width: 22, height: 22))
        // cabin
        p.addRoundedRect(in: CGRect(x: r.minX + w * 0.2, y: r.minY, width: w * 0.56, height: h * 0.3), cornerSize: CGSize(width: 10, height: 10))
        // wheels
        p.addEllipse(in: CGRect(x: r.minX + w * 0.12, y: r.minY + h * 0.66, width: h * 0.3, height: h * 0.3))
        p.addEllipse(in: CGRect(x: r.maxX - w * 0.12 - h * 0.3, y: r.minY + h * 0.66, width: h * 0.3, height: h * 0.3))
        return p
    }
}

// MARK: C09 Location (C09b off)

struct LocationScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    var forceOff = false
    @State var place: Place = AppStore.homePlace
    @State var off = false

    var body: some View {
        WScreen(gutter: 0) {
            BookingHeader(step: 3, label: "Place", fraction: 0.6)
        } content: {
            if off || forceOff {
                WFullState(icon: .location, tone: .wait, title: "Location is off",
                           message: "We use it only to find captains in your society. You can also type your address.",
                           primary: "Turn on location", secondary: "Type address",
                           onPrimary: { off = false }, onSecondary: { router.push(.addressSearch) })
                    .frame(minHeight: 560)
            } else {
                WTitleBlock(title: "Is your vehicle here?", subtitle: "Drag the map to move the pin.")
                    .padding(.horizontal, WSpace.gutter)
                MapPlaceholder()
                    .frame(height: 330)
                VStack {
                    HStack(spacing: 14) {
                        WIconBox(icon: .home, size: 44, radius: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(place.society.name), \(place.tower)").wText(.title)
                            Text(place.addressLine).wText(.caption)
                        }
                        Spacer(minLength: 4)
                        WLink("Change") { router.push(.addressSearch) }
                    }
                    .wOutlined(padding: 16)
                }
                .padding(.horizontal, WSpace.gutter)
                .padding(.top, 18)
            }
        } footer: {
            if !(off || forceOff) {
                WFooterBar(showCall: false) {
                    WButton("Yes, it’s here") {
                        store.draft.place = Place(society: place.society, tower: place.tower)
                        router.push(.floorSlot)
                    }
                }
            }
        }
    }
}

/// Simple drawn map (blocks, roads and a pin) until Google Maps is connected.
struct MapPlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                WColor.map
                ForEach(0..<9, id: \.self) { i in
                    let col = CGFloat(i % 3), row = CGFloat(i / 3)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(i == 1 || i == 5 ? WColor.mapGreen : WColor.mapBlock)
                        .frame(width: w * 0.28, height: h * 0.25)
                        .offset(x: w * 0.05 + col * w * 0.36, y: h * 0.06 + row * h * 0.33)
                }
                VStack(spacing: 2) {
                    ZStack {
                        Circle().fill(WColor.primary).frame(width: 30, height: 30)
                        Circle().fill(.white).frame(width: 11, height: 11)
                    }
                    Ellipse().fill(.black.opacity(0.18)).frame(width: 16, height: 6)
                }
                .position(x: w * 0.51, y: h * 0.43)
                WIconButton(icon: .locate, label: "My location") {}
                    .position(x: w - 50, y: h - 40)
            }
        }
        .clipped()
    }
}

// MARK: C09c Address search

struct AddressSearchScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var query = "my home av"
    @State var picked: Society? = nil

    var body: some View {
        WScreen {
            BookingHeader(step: 3, label: "Place", fraction: 0.6)
        } content: {
            Text("Where is your vehicle?").wText(.screen).padding(.top, 20).padding(.bottom, 18)
            WTextField(label: "Society or building", text: $query, leadingIcon: .search, focusOnAppear: true)
            VStack(spacing: 0) {
                ForEach(store.searchSocieties(query)) { s in
                    Button {
                        picked = s
                        store.draft.place = Place(society: s, tower: "Tower 3")
                        router.push(.floorSlot)
                    } label: {
                        HStack(spacing: 14) {
                            WIconBox(icon: .location, size: 40, radius: 10)
                            VStack(alignment: .leading, spacing: 1) {
                                highlighted(s.name).wText(.rowTitle)
                                Text("\(s.area), \(s.city)").wText(.caption)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    WDivider()
                }
            }
            .padding(.top, 14)
            HStack(spacing: 4) {
                Text("Can’t find it?").wText(.caption)
                WLink("Enter address by hand", type: .caption) {}
            }
            .padding(.top, 14)
        } footer: {
            WFooterBar(showCall: false) { WButton("Next", enabled: picked != nil) { router.push(.floorSlot) } }
        }
    }

    /// Bold the part of the name that matches the search.
    private func highlighted(_ name: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let r = name.range(of: q, options: .caseInsensitive) else { return Text(name) }
        return Text(String(name[..<r.upperBound])) + Text(String(name[r.upperBound...])).bold()
    }
}

// MARK: C10 Floor and slot

struct FloorSlotScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var floor: String? = nil
    @State var slot = ""

    private let floors = ["B3", "B2", "B1", "Ground", "Open"]

    var body: some View {
        WScreen {
            BookingHeader(step: 3, label: "Place", fraction: 0.6)
        } content: {
            WTitleBlock(title: "Where is it parked?", subtitle: store.draft.place?.title ?? "")
            WSectionLabel(text: "Parking floor")
            WFlow(spacing: 10) {
                ForEach(floors, id: \.self) { f in
                    WChip(title: f, selected: floor == f) { floor = f }
                }
            }
            .padding(.bottom, 26)
            WTextField(label: "Slot number", text: $slot, placeholder: "Slot number", helper: "Optional, but it saves the captain time",
                       leadingIcon: .parking, keyboard: .numbersAndPunctuation, capitalization: .characters)
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Next", enabled: floor != nil) {
                    store.draft.place?.floor = floor
                    store.draft.place?.slot = slot.trimmingCharacters(in: .whitespaces)
                    router.push(.entryNotes)
                }
            }
        }
        .onAppear {
            floor = store.draft.place?.floor ?? "B2"
            slot = store.draft.place?.slot.isEmpty == false ? store.draft.place!.slot : "41"
        }
    }
}

// MARK: C11 Notes for the captain

struct EntryNotesScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var text = ""
    @State var voice: Int? = nil
    @State var playing = false

    var body: some View {
        WScreen {
            BookingHeader(step: 3, label: "Place", fraction: 0.8)
        } content: {
            WTitleBlock(title: "Anything the captain should know?", subtitle: "Optional. Gate, lift, landmarks.")
            WTextArea(text: $text, placeholder: "Example: use the B2 ramp near the gym, white car next to the pillar")
            Text("Or record it").wText(.label).padding(.top, 22).padding(.bottom, 8)
            HStack(spacing: 12) {
                recordButton(.mic, "Voice note") { voice = 12 }
                recordButton(.video, "Video") { store.draft.note.videoSeconds = 10 }
            }
            if let v = voice {
                HStack(spacing: 12) {
                    Button { playing.toggle() } label: {
                        WIconView(icon: playing ? .pause : .play, size: 15, color: WColor.primaryStrong)
                            .frame(width: 40, height: 40).background(WColor.primaryTint, in: Circle())
                    }
                    .buttonStyle(.plain)
                    Capsule().fill(WColor.border).frame(height: 3)
                    Text(Fmt.clock(v)).wText(.caption).wMoney()
                    Button { voice = nil } label: { WIconView(icon: .trash, size: 17, color: WColor.destructive) }
                        .buttonStyle(.plain).accessibilityLabel("Delete voice note")
                }
                .padding(.horizontal, 14).frame(height: 62)
                .background(WColor.canvas, in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 20)
            }
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Next") {
                    store.draft.note.text = text
                    store.draft.note.voiceSeconds = voice
                    router.push(.timeSlot)
                }
            }
        }
        .onAppear {
            text = store.draft.note.text
            voice = store.draft.note.voiceSeconds ?? 12
        }
    }

    private func recordButton(_ icon: WIcon, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                WIconView(icon: icon, size: 16, color: WColor.heading)
                Text(title).wText(.bodyStrong, color: WColor.heading, weight: .medium)
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(WColor.border))
        }
        .buttonStyle(WPressStyle())
    }
}

// MARK: C12 Time slot (C12b no captains today)

struct TimeSlotScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @State var dayIndex = 0
    @State var picked: TimeSlot? = nil

    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<3).map { Calendar.current.date(byAdding: .day, value: $0, to: today)! }
    }

    var body: some View {
        let slots = store.timeSlots(for: days[dayIndex])
        let noneFree = !slots.contains { $0.available }
        WScreen {
            BookingHeader(step: 4, label: "Time", fraction: 0.8)
        } content: {
            WTitleBlock(title: "When should we come?", subtitle: noneFree ? nil : "The captain arrives any time in this window.")
            WSegmented(options: days.map { Fmt.day($0) }, selection: $dayIndex)
                .padding(.bottom, 20)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(slots, id: \.self) { s in
                    WChip(title: s.label, selected: picked == s, enabled: s.available, strike: !s.available, height: 54, fill: true) {
                        picked = s
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if noneFree {
                WBanner(tone: .wait, icon: .search, text: "No captains free today in your society. Tomorrow has slots from 6 AM.",
                        actionTitle: "See tomorrow") { dayIndex = 1 }
                    .padding(.top, 20)
            } else {
                Text("No need to be home. A captain comes in your slot and cleans your vehicle just the way you asked.").wText(.caption).padding(.top, 18)
            }
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Next", enabled: picked != nil && !noneFree) {
                    store.draft.slot = picked
                    router.push(.review)
                }
            }
        }
        .onAppear {
            if let s = store.draft.slot, s.available { picked = s }
            else { picked = slots.first { $0.available } }
        }
        .onChange(of: dayIndex) { _, _ in picked = store.timeSlots(for: days[dayIndex]).first { $0.available } }
    }
}

// MARK: C13 Check and pay (+ C17 pay sheet)

struct ReviewScreen: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router

    var body: some View {
        @Bindable var router = router
        let d = store.draft
        let price = d.price
        WScreen {
            BookingHeader(step: 5, label: "Pay", fraction: 1)
        } content: {
            WTitleBlock(title: "Check and pay")
            Button { router.pop() } label: {
                HStack(spacing: 14) {
                    WIconBox(icon: d.type?.icon ?? .car, size: 48, radius: 12)
                    VStack(alignment: .leading, spacing: 6) {
                        WPlate(text: d.plate.isEmpty ? "TS 09 EA 4521" : d.plate)
                        Text("\(d.type?.shortName ?? "")\(d.wash.map { " · \($0.shortName)" } ?? "") · \(d.place?.tower ?? "") · \(d.place?.parkingShort ?? "")").wText(.caption)
                    }
                    Spacer()
                    WIconView(icon: .chevron, size: 13, color: WColor.secondary)
                }
                .wCard(padding: 16, radius: 16)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
            WKeyValueCard(rows: [
                ("When", d.slot?.full ?? ""),
                ("Wash", "Exterior · water and cloth"),
                ("Notes", d.note.summary),
                ("Total", Fmt.rupees(price)),
            ], boldLast: true)
            if (store.customer?.freeWashes ?? 0) > 0 {
                Toggle(isOn: Binding(get: { store.draft.useFreeWash }, set: { store.draft.useFreeWash = $0 })) {
                    Text("Use a free wash (\(store.customer?.freeWashes ?? 0) left)").wText(.bodyStrong)
                }
                .tint(WColor.success)
                .padding(.top, 14)
            }
            HeldSafelyBanner(amount: price).padding(.top, 18)
        } footer: {
            WFooterBar(showCall: false) {
                WButton("Continue to pay") {
                    if store.isLoggedIn {
                        router.showPaySheet = true
                    } else {
                        router.push(.login(error: false))
                    }
                }
            }
        }
        .wSheet(isPresented: $router.showPaySheet, height: 520) {
            PayMethodSheet()
        }
    }
}

/// "₹149 is held safely. It's released to the captain only after you approve the after-photos."
struct HeldSafelyBanner: View {
    let amount: Int
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WIconView(icon: .shield, size: 16, color: WColor.heading).padding(.top, 2)
            (Text("\(Fmt.rupees(amount)) is held safely. ").font(WFont.of(.body, weight: .semibold, size: 14))
             + Text("It’s released to the captain only after you approve the after-photos."))
                .wText(.caption, color: WColor.inverse, size: 14)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
    }
}
