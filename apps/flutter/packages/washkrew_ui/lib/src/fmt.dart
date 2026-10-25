// Formatting helpers (Indian English), ported from apps/ios/Shared/Formatting.swift. Money is whole rupees.

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute, d.second);
int dayDiff(DateTime from, DateTime to) => (startOfDay(to).difference(startOfDay(from)).inHours / 24).round();
bool isToday(DateTime d) => dayDiff(DateTime.now(), d) == 0;
bool isYesterday(DateTime d) => dayDiff(DateTime.now(), d) == -1;

int _h12(int h) => h % 12 == 0 ? 12 : h % 12;
String _ampm(int h) => (h % 24) < 12 ? 'AM' : 'PM';

/// Indian digit grouping: 1,23,456.
String _inr(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

class Fmt {
  /// Indian number plate, tidied for display: "ts09ea4521" → "TS 09 EA 4521".
  /// Anything that doesn't look like a standard plate is only upper-cased.
  static String plate(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final m = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{0,3})(\d{1,4})$').firstMatch(s);
    if (m == null) return raw.trim().toUpperCase();
    return [m[1], m[2]!.padLeft(2, '0'), if (m[3]!.isNotEmpty) m[3], m[4]].join(' ');
  }

  static String rupees(int amount) => '${amount < 0 ? '−₹' : '₹'}${_inr(amount.abs())}';
  static String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// "8 – 10 AM" when both ends share AM/PM, otherwise "10 AM – 12 PM".
  static String window(int start, int end) => _ampm(start) == _ampm(end)
      ? '${_h12(start)} – ${_h12(end)} ${_ampm(end)}'
      : '${_h12(start)} ${_ampm(start)} – ${_h12(end)} ${_ampm(end)}';

  /// "8:40 AM"
  static String time(DateTime d) => '${_h12(d.hour)}:${d.minute.toString().padLeft(2, '0')} ${_ampm(d.hour)}';

  /// "Mon, 12 Oct"
  static String date(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  /// "Today", "Tomorrow" or "Mon, 12 Oct".
  static String day(DateTime d) {
    final diff = dayDiff(DateTime.now(), d);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return date(d);
  }

  /// "+91 98480 11223"
  static String phone(String ten) => ten.length == 10 ? '+91 ${ten.substring(0, 5)} ${ten.substring(5)}' : '+91 $ten';

  /// "98480 11223"
  static String phoneShort(String ten) => ten.length == 10 ? '${ten.substring(0, 5)} ${ten.substring(5)}' : ten;
}

/// Input rules shared by both apps.
class Validators {
  static String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// The only phone check: exactly 10 digits.
  static bool isValidMobile(String s) => digitsOnly(s).length == 10;

  /// UPI ID like name@okhdfc or 9876543210@ybl.
  static bool isValidUPI(String s) => RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9]{1,63}$').hasMatch(s.trim());

  static bool isValidName(String s) {
    final t = s.trim();
    return t.length >= 2 && t.length <= 40;
  }
}

int _uid = 0;
String newId([String prefix = 'id']) => '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_uid++).toRadixString(36)}';

/// Cancellable async work, like a Swift Task.
class WTask {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

WTask runTask(Future<void> Function(WTask task) fn) {
  final j = WTask();
  fn(j);
  return j;
}

Future<void> sleepMs(int ms) => Future.delayed(Duration(milliseconds: ms));
