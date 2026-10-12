import SwiftUI

// MARK: What the owner booked, shown with pictures (few words)

extension WashType {
    @MainActor func name(_ s: CaptainStore) -> String {
        switch self {
        case .dryDusting: return s.t("Dry dusting", "सूखी सफ़ाई", "పొడి దుమ్ము తుడుపు")
        case .wetOutside: return s.t("Water wash", "पानी से धुलाई", "నీటి వాష్")
        case .wetOutsideDryInside: return s.t("Water wash + inside", "पानी से धुलाई + अंदर", "నీటి వాష్ + లోపల")
        }
    }
    var symbol: String { water ? "drop.fill" : "wind" }
}

/// Big picture card: the vehicle, then Outside / Water / Inside with ✓ or ✗.
struct BookingVisual: View {
    @Environment(CaptainStore.self) var store
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: job.isBike ? "scooter" : "car.side.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(WColor.primaryStrong)
                        .frame(width: 84, height: 68)
                        .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 16))
                    Image(systemName: job.wash.symbol)
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(job.wash.water ? WColor.primary : WColor.secondary, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 8, y: 8)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t("Owner booked", "मालिक ने बुक किया", "యజమాని బుక్ చేశారు")).wText(.small, color: WColor.secondary)
                    Text(job.wash.name(store)).wText(.section, weight: .semibold, size: 20)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                tile(job.isBike ? "scooter" : "car.side", store.t("Outside", "बाहर", "బయట"), yes: true)
                tile("drop.fill", store.t("Water", "पानी", "నీళ్ళు"), yes: job.wash.water)
                if !job.isBike {
                    tile("carseat.left.fill", store.t("Inside", "अंदर", "లోపల"), yes: job.wash.inside)
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(WColor.border))
        .accessibilityElement(children: .combine)
    }

    func tile(_ symbol: String, _ label: String, yes: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(yes ? WColor.primaryStrong : WColor.muted)
                .frame(width: 58, height: 58)
                .background(yes ? WColor.primaryTint : WColor.canvas, in: Circle())
                .overlay {
                    if !yes {
                        Rectangle().fill(WColor.destructive.opacity(0.7)).frame(width: 64, height: 3).rotationEffect(.degrees(-40))
                    }
                }
            Text(label).wText(.title, color: yes ? WColor.heading : WColor.secondary, size: 15.5)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(yes ? WColor.successTint.opacity(0.5) : WColor.canvas, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Image(systemName: yes ? "checkmark" : "xmark")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(yes ? WColor.success : WColor.destructive, in: Circle())
                .padding(8)
        }
    }
}

/// One-line version: vehicle + wash picture + name (job alert and Go to vehicle).
struct BookingChip: View {
    @Environment(CaptainStore.self) var store
    let job: Job

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: job.wash.symbol)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(job.wash.water ? WColor.primary : WColor.secondary, in: Circle())
            Text(job.wash.name(store)).wText(.title, size: 16)
            if job.wash.inside {
                Image(systemName: "carseat.left.fill").font(.system(size: 15)).foregroundStyle(WColor.primaryStrong)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(WColor.primaryTint, in: Capsule())
    }
}

// MARK: Vehicle photos (from the owner's booking)

/// Placeholder for the owner's photo of one side (0 front, 1 back, 2 left, 3 right).
/// BACKEND: show the owner's real photo for that side.
struct VehiclePhotoView: View {
    let side: Int
    var isBike = false
    var compact = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xDDE6F3), Color(hex: 0xB9C6D8)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color(hex: 0x8D9AAD).opacity(0.35)).frame(height: compact ? 26 : 120)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Group {
                if isBike {
                    Image(systemName: "scooter").font(.system(size: compact ? 54 : 160)).foregroundStyle(Color(hex: 0x3B4A5E))
                } else {
                    switch side {
                    case 0: CarFrontOutline().fill(Color(hex: 0x3B4A5E).opacity(0.85)).frame(width: compact ? 82 : 260, height: compact ? 62 : 195)
                    case 1: CarBackOutline().fill(Color(hex: 0x3B4A5E).opacity(0.85)).frame(width: compact ? 82 : 260, height: compact ? 62 : 195)
                    default: CarSideOutline().fill(Color(hex: 0x3B4A5E).opacity(0.85)).frame(width: compact ? 96 : 320, height: compact ? 36 : 120)
                            .scaleEffect(x: side == 3 ? -1 : 1)
                    }
                }
            }
            .offset(y: compact ? 4 : 30)
        }
    }
}

/// Full-screen viewer: swipe left/right between Front, Back, Left, Right. Front opens first.
struct VehiclePhotosViewer: View {
    @Environment(CaptainStore.self) var store
    @Environment(\.dismiss) var dismiss
    let isBike: Bool
    let plate: String
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(0..<4, id: \.self) { i in
                    VehiclePhotoView(side: i, isBike: isBike)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 16)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t("Vehicle photos", "गाड़ी की फ़ोटो", "వాహనం ఫోటోలు")).wText(.title, color: .white, size: 17)
                    Text("\(sideName(store, index)) · \(index + 1)/4 · \(plate)").wText(.caption, color: .white.opacity(0.75))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }
}
