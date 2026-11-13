import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/welcome.dart';

// 13 Nov (Aman): like the Customer login, the 6th digit continues by itself.
void main() {
  testWidgets('Captain log-in code continues as soon as all 6 digits are in', (t) async {
    t.view.physicalSize = const Size(700, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = CaptainStore()..phone = '9876543210';
    await t.pumpWidget(CaptainScope(store: s, router: WRouterC(), child: const MaterialApp(home: WOtpScreen(login: true))));
    await t.pump();
    await t.enterText(find.byType(TextField).first, '12345');
    await t.pump();
    expect(s.registered, isFalse);
    await t.enterText(find.byType(TextField).first, '123456');
    await t.pump();
    expect(s.registered, isTrue); // no tap on Next needed
    expect(s.signedUp, isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 70)); // let the screen's timers finish
  });
}
