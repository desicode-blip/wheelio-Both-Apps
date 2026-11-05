import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-VEHICLE (6 Nov): the plate is checked when it's typed (same rule as the
// server), so a mistake never surfaces at payment.
void main() {
  test('plate rule matches the server: 6 to 12 letters and digits', () {
    expect(plateProblem('JJJ'), isNotNull);
    expect(plateProblem(''), isNotNull);
    expect(plateProblem('TS 09 EA 4521'), isNull);
    expect(plateProblem('ts-09-ea-4521'), isNull);
    expect(plateProblem('22 BH 1234 AB'), isNull);
    expect(plateProblem('ABCDEFGHIJKLM'), isNotNull);
    expect(plateKey('ts-09 ea.4521'), 'TS09EA4521');
  });

  testWidgets('a too-short plate is explained on the plate screen and does not move on', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..signInAsSample();
    store.startNewBooking();
    store.draft.type = VehicleType.all[2];
    final router = AppRouter()..go(N.vehicleNumber);
    await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const SizedBox(), builder: (r) => r.n == N.vehicleNumber ? const VehicleNumberScreen() : const SizedBox()))))));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'JJJ');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('too short'), findsOneWidget);
    expect(find.text('What’s the number plate?'), findsOneWidget);
    expect(store.draft.plate, isNot('JJJ'));
    await tester.pumpWidget(const SizedBox());
  });
}
