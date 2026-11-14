// 14 Nov (Aman): the first open after approval shows "Your account is approved".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/onboarding.dart';

void main() {
  for (final online in [false, true]) {
    testWidgets('approved pop-up (online: $online)', (tester) async {
      tester.view.physicalSize = const Size(360, 780);tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = CaptainStore()..name = 'Raju Yadav'..online = online, r = WRouterC();
      await tester.pumpWidget(CaptainScope(store: s, router: r, child: MaterialApp(home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => showApprovedNotice(c), child: const Text('open'))))))));
      await tester.tap(find.text('open'));await tester.pumpAndSettle();
      expect(find.text('Your account is approved'), findsOneWidget);
      expect(find.textContaining('Welcome to the crew, Raju'), findsOneWidget);
      expect(find.text(online ? 'Start' : 'Go online'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(online ? 'Start' : 'Later'));await tester.pumpAndSettle();
      expect(find.text('Your account is approved'), findsNothing);
      await tester.pumpWidget(const SizedBox());s.dispose();r.dispose();
    });
  }
}
