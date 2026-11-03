import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/screens/home.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

class DeletionFixture extends AppStore {
  int calls = 0;
  Completer<bool> pending = Completer<bool>();
  @override
  bool get isLive => true;
  @override
  Future<bool> deleteAccount() {
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
    'Customer requires two confirmations, no OTP, one pending delete and retryable error',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DeletionFixture()
            ..customer = Customer(id: 'owner', phone: '', name: 'Test'),
          router = AppRouter();
      await tester.pumpWidget(
        AppScope(
          store: store,
          router: router,
          child: const MaterialApp(home: Scaffold(body: ProfileTab())),
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
      store.pending.completeError(
        StateError('Finish your open booking first.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Finish your open booking first.'), findsOneWidget);
      expect(find.text('Are you absolutely sure?'), findsOneWidget);
      store.pending = Completer<bool>();
      await tester.tap(find.widgetWithText(WButton, 'Delete account'));
      await tester.pump();
      expect(store.calls, 2);
      store.pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Are you absolutely sure?'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      router.dispose();
    },
  );
}
