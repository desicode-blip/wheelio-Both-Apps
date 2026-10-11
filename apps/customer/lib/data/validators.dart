/// Input rules shared by the screens and unit tests.
abstract final class Validators {
  /// Normalises "ts 09 ea 4521" → "TS09EA4521".
  static String normalisePlate(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Indian registration numbers: state + RTO + series + number
  /// (TS 09 EA 4521, KA 01 A 1234, DL 3C AB 1234) and Bharat series (22 BH 1234 AA).
  static bool isValidPlate(String input) {
    final p = normalisePlate(input);
    final standard = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$');
    final bharat = RegExp(r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$');
    return (standard.hasMatch(p) && p.length >= 6) || bharat.hasMatch(p);
  }

  /// "TS09EA4521" → "TS 09 EA 4521"
  static String formatPlate(String input) {
    final p = normalisePlate(input);
    final m = RegExp(r'^([A-Z]{2})([0-9]{1,2})([A-Z]{0,3})([0-9]{1,4})$').firstMatch(p);
    if (m == null) return p;
    return [m[1], m[2], m[3], m[4]].where((s) => s != null && s.isNotEmpty).join(' ');
  }

  /// 10-digit Indian mobile number starting 6–9.
  static bool isValidMobile(String input) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(digitsOnly(input));

  static String digitsOnly(String input) {
    final d = input.replaceAll(RegExp(r'[^0-9]'), '');
    // Accept numbers pasted with the country code.
    if (d.length == 12 && d.startsWith('91')) return d.substring(2);
    if (d.length == 11 && d.startsWith('0')) return d.substring(1);
    return d;
  }

  static bool isValidName(String input) => input.trim().length >= 2 && input.trim().length <= 40;
}
