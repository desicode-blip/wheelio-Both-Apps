import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/washkrew_ui/Roboto');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$weight.ttf'),
      );
    }
    await loader.load();
  });
  for (final width in [320.0, 363.0, 390.0]) {
    for (final completed in [0, 1, 4]) {
      testWidgets('photo tiles fit at $width with $completed uploaded photos', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = AppStore(), router = AppRouter();
        store.draft.type = VehicleType.demoTypes[1];
        for (final angle in PhotoAngle.values.take(completed)) {
          store.draft.photos[angle] = UploadState.done;
        }
        await tester.pumpWidget(
          AppScope(
            store: store,
            router: router,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  padding: const EdgeInsets.only(top: 47, bottom: 24),
                ),
                child: const PhotosScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(WPhotoSlot), findsNWidgets(4));
        if (width == 390) {
          final tile = tester.getSize(find.byType(WPhotoSlot).first);
          expect(tile.height, closeTo(tile.width * (completed == 0 ? 126 : 122) / 154, 0.001));
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        router.dispose();
      });
    }
  }
}
