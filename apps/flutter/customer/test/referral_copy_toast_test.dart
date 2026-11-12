import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/features/preview_features.dart';

// 13 Nov (Aman): Copy shows a toast that fades away — at the top for the code's Copy,
// just above the button for Copy invite link.
final _key = GlobalKey();
const _dir = String.fromEnvironment('TOAST_CAPTURE_DIR');
Future<void> _shot(WidgetTester t, String name) async {
  if (_dir.isEmpty) return;
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.5);
    final d = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (_dir.isEmpty) return;
    final l = FontLoader('packages/washkrew_ui/Roboto');
    for (final n in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      l.addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$n.ttf'));
    }
    await l.load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('Copy shows a toast at the top; Copy invite link shows one above the button', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = AppStore()..signInAsSample();
    await t.pumpWidget(RepaintBoundary(key: _key, child: AppScope(store: s, router: AppRouter(), child: const MaterialApp(debugShowCheckedModeBanner: false, home: CustomerReferralsScreen()))));
    await t.pumpAndSettle();

    await t.tap(find.text('Copy'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Referral code copied'), findsOneWidget);
    expect(t.getTopLeft(find.text('Referral code copied')).dy, lessThan(200));
    await _shot(t, 'toast-top');
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Referral code copied'), findsNothing); // faded and gone

    await t.tap(find.text('Copy invite link'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final toast = t.getBottomLeft(find.text('Invite link copied')).dy, button = t.getTopLeft(find.text('Copy invite link')).dy;
    expect(toast, lessThan(button));
    expect(toast, greaterThan(button - 120));
    await _shot(t, 'toast-bottom');
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Invite link copied'), findsNothing);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
