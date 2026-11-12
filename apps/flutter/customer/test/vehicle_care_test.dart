import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/features/vehicle_care_screens.dart';
import 'package:washkrew_customer/features/vehicle_profile.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart' show WashCoverage;
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-CARE (12 Nov): photos → Is this your vehicle? (AI) → optional details → care routine.
Widget _screen(R r) => switch (r.n) {
  N.photos => const PhotosScreen(),
  N.vehicleCheck => const VehicleCheckScreen(),
  N.careRoutine => const CareRoutineScreen(),
  _ => WText('route:${r.n.name}', WType.body),
};

final _key = GlobalKey();
const _dir = String.fromEnvironment('CARE_CAPTURE_DIR');
Future<void> _shot(WidgetTester t, String name) async {
  if (_dir.isEmpty) return;
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final d = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<(AppStore, AppRouter)> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = AppStore()..signInAsSample()..draftBasics();
  for (final a in PhotoAngle.values) {
    store.draft.photos[a] = UploadState.done;
  }
  final router = AppRouter()..go(N.photos);
  await t.pumpWidget(RepaintBoundary(
    key: _key,
    child: AppScope(store: store, router: router, child: MaterialApp(debugShowCheckedModeBanner: false, home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const SizedBox(), builder: _screen))))),
  ));
  await _settle(t);
  return (store, router);
}

void main() {
  setUp(LocalFlags.resetForTest);
  setUpAll(() async {
    final l = FontLoader('packages/washkrew_ui/Roboto');
    for (final n in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      l.addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$n.ttf'));
    }
    await l.load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('AI result confirmed in one tap, then the care routine, then on to the place', (t) async {
    final (store, router) = await _open(t);
    await t.tap(find.text('Next'));
    await t.pump();
    expect(find.text('Checking your photos'), findsOneWidget);
    await _shot(t, 'care-1-checking');
    await _settle(t);
    expect(find.text('Is this your vehicle?'), findsOneWidget);
    expect(find.text('Hyundai Creta'), findsOneWidget);
    expect(find.text('Glossy'), findsOneWidget);
    await _shot(t, 'care-2-found');
    await t.tap(find.text('Yes, that’s it'));
    await _settle(t);
    expect(find.text('Your care routine'), findsOneWidget);
    expect(find.text('For your Hyundai Creta'), findsOneWidget);
    expect(find.text('Gloss kept bright'), findsOneWidget);
    await _shot(t, 'care-4-routine');
    expect(store.draft.vehicleProfile?['source'], 'ai');
    expect(store.draft.careRoutine.length, inInclusiveRange(2, 3));
    await t.tap(find.text('Next'));
    await _settle(t);
    expect(router.last?.n, N.location);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Not right: optional form (skippable), matte and leather change the routine', (t) async {
    final (store, router) = await _open(t);
    store.draft.coverage = WashCoverage.exteriorInterior;
    await t.tap(find.text('Next'));
    await _settle(t);
    await t.tap(find.text('No, edit details'));
    await _settle(t);
    expect(find.text('Tell us about your vehicle'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), 'Verna');
    await t.tap(find.text('Matte'));
    await t.ensureVisible(find.text('Leather'));
    await t.tap(find.text('Leather'));
    await _settle(t);
    await _shot(t, 'care-3-form');
    await t.tap(find.text('Continue'));
    await _settle(t);
    expect(find.text('For your Hyundai Verna'), findsOneWidget);
    expect(find.text('Matte-safe wash'), findsOneWidget);
    expect(find.text('Leather seats: no water'), findsOneWidget);
    expect(store.draft.vehicleProfile?['source'], 'customer');
    await _shot(t, 'care-5-routine-matte');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Skip goes straight on with nothing sent', (t) async {
    final (store, router) = await _open(t);
    await t.tap(find.text('Next'));
    await _settle(t);
    await t.tap(find.text('No, edit details'));
    await _settle(t);
    await t.tap(find.text('Skip'));
    await _settle(t);
    expect(router.last?.n, N.location);
    expect(store.draft.vehicleProfile, isNull);
    expect(store.draft.careRoutine, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  test('care rules: bike keeps electrics dry, dark paint avoids swirls, at most 3', () {
    final bike = careRoutineFor(VehicleProfile(color: 'Matte black', finish: PaintFinish.matte), VehicleKind.bike);
    expect(bike.map((s) => s.title), ['Matte-safe wash', 'Electrics kept dry', 'No swirl marks']);
    final plain = careRoutineFor(VehicleProfile(make: 'Tata'), VehicleKind.hatchback);
    expect(plain.map((s) => s.title), ['Spot-free finish']);
  });
}
