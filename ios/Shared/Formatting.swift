import Foundation
import UIKit

/// Formatting helpers (Indian English). Money is whole rupees.
enum Fmt {
    static func rupees(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        return "₹" + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func hour12(_ h: Int) -> Int { h % 12 == 0 ? 12 : h % 12 }
    private static func ampm(_ h: Int) -> String { (h % 24) < 12 ? "AM" : "PM" }

    /// "8 – 10 AM" when both ends share AM/PM, otherwise "10 AM – 12 PM".
    static func window(_ start: Int, _ end: Int) -> String {
        if ampm(start) == ampm(end) {
            return "\(hour12(start)) – \(hour12(end)) \(ampm(end))"
        }
        return "\(hour12(start)) \(ampm(start)) – \(hour12(end)) \(ampm(end))"
    }

    /// "8:40 AM"
    static func time(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%d:%02d %@", hour12(c.hour ?? 0), c.minute ?? 0, ampm(c.hour ?? 0))
    }

    /// "Mon, 12 Oct"
    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_IN")
        f.dateFormat = "EEE, d MMM"
        return f.string(from: d)
    }

    /// "Today", "Tomorrow" or "Mon, 12 Oct".
    static func day(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        if diff == 0 { return "Today" }
        if diff == 1 { return "Tomorrow" }
        if diff == -1 { return "Yesterday" }
        return date(d)
    }

    /// "+91 98480 11223"
    static func phone(_ tenDigits: String) -> String {
        guard tenDigits.count == 10 else { return "+91 \(tenDigits)" }
        return "+91 \(tenDigits.prefix(5)) \(tenDigits.suffix(5))"
    }

    /// "98480 11223"
    static func phoneShort(_ tenDigits: String) -> String {
        guard tenDigits.count == 10 else { return tenDigits }
        return "\(tenDigits.prefix(5)) \(tenDigits.suffix(5))"
    }
}

/// Input rules shared by both apps.
enum Validators {
    /// "ts 09 ea 4521" → "TS09EA4521"
    static func normalisePlate(_ s: String) -> String {
        s.uppercased().filter { $0.isLetter || $0.isNumber }.filter { $0.isASCII }
    }

    /// Indian registration numbers (TS 09 EA 4521, KA 01 A 1234) and Bharat series (22 BH 1234 AA).
    static func isValidPlate(_ s: String) -> Bool {
        let p = normalisePlate(s)
        let standard = p.range(of: "^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$", options: .regularExpression) != nil && p.count >= 6
        let bharat = p.range(of: "^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$", options: .regularExpression) != nil
        return standard || bharat
    }

    /// "TS09EA4521" → "TS 09 EA 4521"
    static func formatPlate(_ s: String) -> String {
        let p = normalisePlate(s)
        guard let re = try? NSRegularExpression(pattern: "^([A-Z]{2})([0-9]{1,2})([A-Z]{0,3})([0-9]{1,4})$"),
              let m = re.firstMatch(in: p, range: NSRange(p.startIndex..., in: p)) else { return p }
        var parts: [String] = []
        for i in 1...4 {
            if let r = Range(m.range(at: i), in: p), !p[r].isEmpty { parts.append(String(p[r])) }
        }
        return parts.joined(separator: " ")
    }

    /// Digits only, nothing else.
    static func digitsOnly(_ s: String) -> String {
        s.filter { $0.isASCII && $0.isNumber }
    }

    /// The only phone check: exactly 10 digits (the first 10 the person typed).
    static func isValidMobile(_ s: String) -> Bool {
        digitsOnly(s).count == 10
    }

    /// UPI ID like name@okhdfc or 9876543210@ybl.
    static func isValidUPI(_ s: String) -> Bool {
        s.trimmingCharacters(in: .whitespaces)
            .range(of: "^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9]{1,63}$", options: .regularExpression) != nil
    }

    static func isValidName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.count >= 2 && t.count <= 40
    }
}

/// Support details (placeholders until the real numbers exist).
enum Support {
    static let phone = "+910000000000"
    static let hours = "7 AM – 9 PM, every day. Calls in English, Hindi or Telugu."

    static func call(_ number: String = phone) {
        if let url = URL(string: "tel:\(number)") { UIApplication.shared.open(url) }
    }
}

