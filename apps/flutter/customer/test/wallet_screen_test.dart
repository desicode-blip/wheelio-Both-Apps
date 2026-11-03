import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_customer/screens/wallet.dart';
import 'package:washkrew_customer/screens/common.dart';
import 'wallet_by_time_test.dart' as proof;

class WalletFixture extends AppStore {
  @override
  bool get isLive => true;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/washkrew_ui/Roboto');
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$name.ttf'),
      );
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  testWidgets('Home wallet entry shows current credits and opens the wallet', (
    tester,
  ) async {
    final s = WalletFixture()
          ..customer = (Customer(id: 'wallet-owner', phone: '')..credit = 74.5),
        r = AppRouter();
    await tester.pumpWidget(
      AppScope(
        store: s,
        router: r,
        child: const MaterialApp(home: Scaffold(body: WalletButton())),
      ),
    );
    expect(find.text('₹74.50'), findsOneWidget);
    await tester.tap(find.byType(WalletButton));
    expect(r.last?.n, N.wallet);
    s.set(() => s.customer!.credit = 149);
    await tester.pump();
    expect(find.text('₹149'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    r.dispose();
  });
  testWidgets(
    'wallet supports paise top-up and rejects invalid amounts in the existing controls',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = WalletFixture()
            ..customer = (Customer(id: 'wallet-owner', phone: '')
              ..credit = 74.5),
          r = AppRouter();
      await tester.pumpWidget(
        RepaintBoundary(
          key: proof.captureKey,
          child: AppScope(
            store: s,
            router: r,
            child: const MaterialApp(home: WalletScreen(shortfallPaise: 7450)),
          ),
        ),
      );
      expect(find.text('₹74.50'), findsOneWidget);
      expect(find.text('Top up ₹74.50'), findsOneWidget);
      await proof.capture(tester, 'wallet');
      await tester.enterText(find.byType(TextField), '0.50');
      await tester.pump();
      final button = tester.widget<WButton>(find.byType(WButton).last);
      expect(button.enabled, false);
      await tester.enterText(find.byType(TextField), '74.501');
      await tester.pump();
      expect(tester.widget<WButton>(find.byType(WButton).last).enabled, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      r.dispose();
    },
  );
  testWidgets(
    'full wallet choice skips Razorpay and explicit gateway choice preserves the full price',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = WalletFixture()
            ..draftFull()
            ..customer = (Customer(id: 'wallet-owner', phone: '')
              ..credit = 200),
          r = AppRouter();
      await tester.pumpWidget(
        AppScope(
          store: s,
          router: r,
          child: const MaterialApp(home: ReviewScreen()),
        ),
      );
      await tester.tap(find.text('Pay by wallet · ₹149'));
      await tester.pumpAndSettle();
      expect(r.path,isEmpty);
      await tester.tap(find.text('Allow AI check'));await tester.pumpAndSettle();
      expect(s.draft.aiPhotoConsent,true);
      expect(s.draft.walletOnly, true);
      expect(s.draft.pricePaise, 0);
      expect(r.last?.n, N.paying);
      r.pop();
      await tester.pump();
      await tester.tap(find.text('Pay via Razorpay · ₹149'));
      await tester.pump();
      expect(find.text('Allow Google AI photo check?'),findsNothing);
      expect(s.draft.walletOnly, false);
      expect(s.draft.pricePaise, 14900);
      expect(r.last?.n, N.paying);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      r.dispose();
    },
  );
}
