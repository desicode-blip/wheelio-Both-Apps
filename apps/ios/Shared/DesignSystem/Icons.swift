import SwiftUI

/// Icon names from the design layers ("Icon/left", "Icon/help" …) mapped to SF Symbols.
enum WIcon: String {
    case left, close, help, phone, call, chevron, check, checkCircle, plus, minus
    case bike, car, suv, camera, video, mic, play, pause, trash, image, gallery
    case location, locate, search, home, calendar, clock, shield, rupee, gift, star, starFill
    case bell, user, logout, edit, doc, receipt, flag, zoom, info, warning, error, wifiOff, lock
    case drop, sparkle, refresh, arrowRight, arrowUp, layers, parking, door, whatsapp, chat
    case gear, bellSlash, moon, speakerOff, megaphone
    case bucket, wipe, power, list, translate, languages, bank, idCard, face, sun, battery, eye, ban, stopwatch
    case flash, upload, scratch, download, timer, building

    var symbol: String {
        switch self {
        case .left: return "chevron.left"
        case .close: return "xmark"
        case .help: return "questionmark.circle"
        case .phone, .call: return "phone"
        case .chevron: return "chevron.right"
        case .check: return "checkmark"
        case .checkCircle: return "checkmark.circle.fill"
        case .plus: return "plus"
        case .minus: return "minus"
        case .bike: return "bicycle"
        case .car: return "car"
        case .suv: return "suv.side"
        case .camera: return "camera"
        case .video: return "video"
        case .mic: return "mic"
        case .play: return "play"
        case .pause: return "pause.fill"
        case .trash: return "trash"
        case .image, .gallery: return "photo"
        case .location: return "mappin"
        case .locate: return "location"
        case .search: return "magnifyingglass"
        case .home: return "house"
        case .calendar: return "calendar"
        case .clock: return "clock"
        case .shield: return "checkmark.shield"
        case .rupee: return "indianrupeesign"
        case .gift: return "gift"
        case .star: return "star"
        case .starFill: return "star.fill"
        case .bell: return "bell"
        case .gear: return "gearshape"
        case .bellSlash: return "bell.slash"
        case .moon: return "moon"
        case .speakerOff: return "speaker.slash"
        case .megaphone: return "megaphone"
        case .user: return "person"
        case .logout: return "rectangle.portrait.and.arrow.right"
        case .edit: return "pencil"
        case .doc, .receipt: return "doc.text"
        case .flag: return "flag"
        case .zoom: return "plus.magnifyingglass"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.triangle"
        case .wifiOff: return "wifi.slash"
        case .lock: return "lock"
        case .drop: return "drop"
        case .sparkle: return "sparkle"
        case .refresh: return "arrow.clockwise"
        case .arrowRight: return "arrow.right"
        case .arrowUp: return "arrow.up"
        case .layers: return "square.3.layers.3d"
        case .parking: return "parkingsign.square"
        case .door: return "door.left.hand.open"
        case .whatsapp, .chat: return "message"
        case .bucket: return "waterbottle"
        case .wipe: return "hand.wave"
        case .power: return "power"
        case .list: return "list.bullet"
        case .translate: return "character.bubble"
        case .languages: return "translate"
        case .bank: return "building.columns"
        case .idCard: return "person.text.rectangle"
        case .face: return "faceid"
        case .sun: return "sun.max"
        case .battery: return "battery.25"
        case .eye: return "eye"
        case .ban: return "nosign"
        case .stopwatch: return "stopwatch"
        case .flash: return "bolt"
        case .upload: return "square.and.arrow.up"
        case .scratch: return "scribble"
        case .download: return "square.and.arrow.down"
        case .timer: return "timer"
        case .building: return "building.2"
        }
    }
}

struct WIconView: View {
    let icon: WIcon
    var size: CGFloat = 20
    var color: Color = WColor.heading
    var weight: Font.Weight = .regular

    var body: some View {
        Image(systemName: icon.symbol)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}
