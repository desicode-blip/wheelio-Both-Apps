import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart' show ServiceLevel, WashCoverage;

// 13 Nov (Aman): log in comes first; a choice the server can't take yet shows one clear
// way to fix it instead of a grey Pay button.
class LiveFixture extends AppStore {
  @override
  bool get isLive => true;
}

Future<LiveFixture> _open(WidgetTester t, {required bool loggedIn}) async {
  t.view.physicalSize = const Size(430, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final s = LiveFixture()..draftFull();
  if (loggedIn) s.customer = Customer(id: 'owner', phone: '');
  s.draft.serviceLevel = ServiceLevel.premium;
  s.draft.coverage = WashCoverage.exterior;
  await t.pumpWidget(AppScope(store: s, router: AppRouter(), child: const MaterialApp(home: ReviewScreen())));
  await t.pump();
  return s;
}

void main() {
  test('any customer window books the server slots inside it (or the one it overlaps most)', () {
    final s = LiveFixture()..liveWindows = [(4, 6), (6, 8), (8, 10), (10, 12), (12, 14), (14, 16), (16, 18), (18, 20), (20, 22)];
    final day = DateTime(2026, 11, 13);
    expect(s.serverWindowsFor(TimeSlot(day, 8, 23, minuteWindows: const [(495, 1380)])), [(10, 12), (12, 14), (14, 16), (16, 18), (18, 20), (20, 22)]);
    expect(s.serverWindowsFor(TimeSlot(day, 8, 10, minuteWindows: const [(495, 570)])), [(8, 10)]);
    expect(s.serverWindowsFor(TimeSlot(day, 9, 11, minuteWindows: const [(540, 660)])), [(8, 10)]); // equal overlap: earlier slot
    s.draft.slot = TimeSlot(day, 8, 23, minuteWindows: const [(495, 1380)]);
    expect(s.washChoiceBlockedByTime, isFalse);
    s.dispose();
  });


  testWidgets('logged out: Make payment asks to log in, then carries on to payment', (t) async {
    final s = await _open(t, loggedIn: false);
    expect(find.text('Make payment'), findsOneWidget);
    s.draft.serviceLevel = ServiceLevel.basic;
    await t.tap(find.text('Make payment'));
    await t.pump();
    expect(s.payAfterLogin, isTrue);
    expect(find.text('Change wash'), findsNothing);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('logged in with Premium before the server takes it: Change wash', (t) async {
    final s = await _open(t, loggedIn: true);
    expect(find.textContaining('Premium opens for booking soon'), findsOneWidget);
    expect(find.textContaining('Nothing was charged'), findsNothing);
    expect(find.text('Change wash'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
