import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/auth_pay.dart';
import 'package:washkrew_customer/screens/live.dart';

// Server-resolved state without initializing Firebase or a merchant SDK.
class CompletionStore extends AppStore {
  @override
  bool get isLive => true;
}

void main() {
  testWidgets('Firebase confirmation shows assignment and offers the gate pass upload', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = CompletionStore()..sampleOrder(OrderStatus.onTheWay);
    final router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: BookedScreen())));
    expect(find.textContaining('accepted your booking'), findsOneWidget);
    expect(find.textContaining('We’re finding a captain now'), findsNothing);
    // v2 CU-LIVE: the gate pass is uploaded on this screen; no WhatsApp step.
    expect(find.text('Open WhatsApp'), findsNothing);
    expect(find.text('Gate pass'), findsOneWidget);
    // 13 Nov: sharing isn't on the live server yet; the button stays, greyed (toast on tap).
    expect(find.text('Upload gate pass'), findsOneWidget);
    expect(find.textContaining('oming soon'), findsNothing);
    expect(router.last, isNull);
    store.liveConfig['gatePass'] = true;
    store.changed();
    await tester.pump();
    expect(find.text('Upload gate pass'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });

  testWidgets('review and rating approve the Customer payment without claiming a Captain bank transfer', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = CompletionStore()..sampleOrder(OrderStatus.photosReady);
    final router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: LiveOrderScreen())));
    expect(find.text('Approve your ₹149 wash payment'), findsOneWidget);
    expect(find.textContaining('₹149 to Raju'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.sampleOrder(OrderStatus.approved);
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: RateScreen())));
    expect(find.text('Your ₹149 wash payment is approved. Thank you.'), findsOneWidget);
    expect(find.textContaining('released to'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });

  testWidgets('design fixture shows the gate pass card', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..sampleOrder(OrderStatus.onTheWay);
    final router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: BookedScreen())));
    // v2 CU-LIVE: the sample booking already has its pass, so the card shows it as shared.
    expect(find.text('Gate pass'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });
}
