import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

// 13 Nov (Aman): what the server can't sell yet is greyed out and says "coming soon" at
// the entry point; it can't be chosen, so no journey dead-ends at payment.
final _key = GlobalKey();
const _dir = String.fromEnvironment('SOON_CAPTURE_DIR');

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

  testWidgets('Premium, interior and monthly say coming soon and stay unselected', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = PurchaseSelection()..level = ServiceLevel.premium;
    await t.pumpWidget(RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PurchaseChoiceScreen(
          selection: s,
          onBack: () {},
          onContinue: () {},
          priceFor: (l, c) => 292,
          levelAvailable: (l) => l == ServiceLevel.basic,
          interiorAvailable: false,
          monthlyAvailable: false,
        ),
      ),
    ));
    await t.pump();
    expect(s.level, ServiceLevel.basic); // an unavailable choice is reset
    expect(find.text('Coming soon'), findsNWidgets(2)); // Premium, Extra Premium
    expect(find.text('Interior · coming soon'), findsOneWidget);
    expect(find.text('Monthly · soon'), findsOneWidget);
    await t.tap(find.text('Interior · coming soon'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Interior cleaning is coming soon. We’re working on it.'), findsOneWidget);
    expect(s.coverage, WashCoverage.exterior);
    if (_dir.isNotEmpty) {
      await t.runAsync(() async {
        final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1.5);
        final d = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/coming-soon.png').writeAsBytesSync(d!.buffer.asUint8List());
      });
    }
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.text('Premium'));
    await t.pump(const Duration(milliseconds: 300));
    expect(s.level, ServiceLevel.basic);
    expect(find.text('Premium is coming soon. We’re working on it.'), findsOneWidget);
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.text('Monthly · soon'));
    await t.pump(const Duration(milliseconds: 300));
    expect(s.monthly, isFalse);
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  });
}
