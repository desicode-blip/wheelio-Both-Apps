import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/money.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

class DeletionFixture extends CaptainStore {
  DeletionFixture() {
    registered = true;
    name = 'Test';
  }
  int calls = 0;
  Completer<String?> pending = Completer<String?>();
  @override
  bool get isLive => true;
  @override
  Future<String?> deleteAccount() {
    calls++;
    return pending.future;
  }
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('packages/washkrew_ui/Roboto');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(
        rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$weight.ttf'),
      );
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'Captain requires two confirmations, no OTP, one pending delete and retryable error',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DeletionFixture(), router = WRouterC();
      await tester.pumpWidget(
        CaptainScope(
          store: store,
          router: router,
          child: const MaterialApp(home: Scaffold(body: MeTab())),
        ),
      );
      await tester.ensureVisible(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(store.calls, 0);
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.text('Yes, continue'));
      await tester.tap(find.text('Yes, continue'));
      expect(store.calls, 0);
      await tester.pumpAndSettle();
      expect(find.text('Are you absolutely sure?'), findsOneWidget);
      await tester.tap(find.widgetWithText(WButton, 'Delete account'));
      await tester.pump();
      expect(store.calls, 1);
      expect(find.byType(WOtpField), findsNothing);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is WButton && w.kind == ButtonKind.danger && w.loading,
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(store.calls, 1);
      store.pending.complete('Finish your open job first.');
      await tester.pumpAndSettle();
      expect(find.text('Finish your open job first.'), findsOneWidget);
      store.pending = Completer<String?>();
      await tester.tap(find.widgetWithText(WButton, 'Delete account'));
      await tester.pump();
      expect(store.calls, 2);
      store.pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Are you absolutely sure?'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      router.dispose();
    },
  );
}
