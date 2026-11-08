import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

// v2 CU-WASHCHOICE (8 Nov, Aman): at least 1 hour per window; nothing after 11 PM;
// nothing before 4 AM. Each case says what to do instead.
WashTimeWindow w(int start, int end) => WashTimeWindow(startMinute: start, endMinute: end);

void main() {
  test('a window shorter than 1 hour asks for at least 1 hour', () {
    final m = validateWashWindows([w(8 * 60, 8 * 60 + 45)]);
    expect(m, contains('shorter than 1 hour'));
    expect(m, contains('at least 1 hour'));
    expect(validateWashWindows([w(8 * 60, 9 * 60)]), isNull);
  });

  test('ending after 11 PM says we don’t wash after 11 PM', () {
    expect(validateWashWindows([w(22 * 60, 23 * 60 + 30)]), 'We don’t wash after 11 PM. Choose an end time by 11 PM.');
    expect(validateWashWindows([w(23 * 60 + 15, 23 * 60 + 50)]), contains('after 11 PM'));
    expect(validateWashWindows([w(22 * 60, 23 * 60)]), isNull, reason: '10–11 PM is fine');
  });

  test('starting before 4 AM says when we start', () {
    expect(validateWashWindows([w(3 * 60, 5 * 60)]), contains('We start at 4 AM'));
  });

  test('server hours replace the defaults', () {
    expect(validateWashWindows([w(21 * 60, 22 * 60 + 30)], latest: 22 * 60), contains('after 10 PM'));
  });

  test('the second window is named when there are two', () {
    expect(validateWashWindows([w(8 * 60, 10 * 60), w(19 * 60, 19 * 60 + 30)]), startsWith('Window 2 is shorter'));
  });
}
