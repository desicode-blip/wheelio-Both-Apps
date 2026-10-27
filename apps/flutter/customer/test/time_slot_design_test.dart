import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';

void main() {
  testWidgets('original C12 all-day card and multiple windows retain their booking intent', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(), router = AppRouter();
    await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:TimeSlotScreen())));
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(find.text('Any time of the day'),findsOneWidget);
    expect(find.text('No time preference. The captain picks when to come.'),findsOneWidget);
    await tester.tap(find.text('Any time of the day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    expect(store.draft.slot!.anyTime,isTrue);
    expect(store.draft.slot!.windows.length,6);
    expect(router.last?.n,N.review);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
  test('restored any-time labels show the chosen span rather than just its current dispatch window', () {
    final s=TimeSlot(DateTime(2026,11,1),8,10,windows:const[(4,6),(8,10),(20,22)],anyTime:true);
    expect(s.label,'Any time (4 AM – 10 PM)');
  });
}
