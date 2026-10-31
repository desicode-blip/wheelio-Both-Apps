import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/place_search.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

const nearby = PlaceSuggestion(
  'example_place',
  'Example Society',
  'Example area, Hyderabad',
);

class SearchStore extends AppStore {
  @override
  bool get isLive => true;
  @override
  bool get placeSearchEnabled => true;
  @override
  bool get hasSearchOrigin => true;
  int gpsPrompts = 0, selections = 0;
  String? lookupQuery;
  bool served = true;
  Completer<Map<String, dynamic>>? pendingSelection;
  Completer<(double, double)?>? pendingGps;
  @override
  Future<(double, double)?> locateForSearch({
    bool requestPermission = true,
  }) async {
    if (requestPermission) gpsPrompts++;
    if (pendingGps != null) return pendingGps!.future;
    return (17.4, 78.35);
  }

  @override
  Future<List<PlaceSuggestion>> searchPlaceSuggestions(
    String query,
    String token,
  ) async {
    lookupQuery = query;
    return [nearby];
  }

  @override
  Future<Map<String, dynamic>> selectPlaceSuggestion(
    String id,
    String token,
  ) async {
    selections++;
    if (pendingSelection != null) return pendingSelection!.future;
    return {
      'societyId': served ? 'served' : null,
      'place': {
        'name': nearby.name,
        'area': 'Example area',
        'city': 'Hyderabad',
        'pincode': '500001',
        'latitude': 17.4,
        'longitude': 78.35,
      },
    };
  }
}

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
  testWidgets(
    'nearby list filters immediately and typing is debounced; stale replies cannot replace current results',
    (tester) async {
      final pending = <String, Completer<List<PlaceSuggestion>>>{},
          calls = <String>[];
      final session = PlaceSearchSession((q, t) {
        calls.add(q);
        return (pending[q] = Completer<List<PlaceSuggestion>>()).future;
      });
      session.search('', immediate: true);
      pending['']!.complete([nearby]);
      await tester.pump();
      expect(session.results, [nearby]);
      session.search('E');
      expect(session.results, [nearby]);
      expect(calls, ['']);
      session.search('Ex');
      await tester.pump(const Duration(milliseconds: 200));
      session.search('Exam');
      await tester.pump(const Duration(milliseconds: 350));
      expect(calls, ['', 'Exam']);
      session.search('Other');
      await tester.pump(const Duration(milliseconds: 350));
      pending['Other']!.complete([
        const PlaceSuggestion('other', 'Other Society', 'Delhi'),
      ]);
      await tester.pump();
      pending['Exam']!.complete([nearby]);
      await tester.pump();
      expect(session.results.single.name, 'Other Society');
      expect(session.loading, false);
      final token = session.token;
      session.completeSelection();
      expect(session.token, isNot(token));
      session.dispose();
    },
  );
  testWidgets(
    'errors are retryable and leaving the screen discards in-flight lookup',
    (tester) async {
      final pending = Completer<List<PlaceSuggestion>>();
      var fail = true;
      final session = PlaceSearchSession((q, t) async {
        if (fail) throw StateError('Offline');
        return pending.future;
      });
      session.search('Society', immediate: true);
      await tester.pump();
      expect(session.error, isNotNull);
      expect(session.loading, false);
      fail = false;
      session.search('Society', immediate: true);
      session.dispose();
      pending.complete([nearby]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  for (final served in [true, false]) {
    testWidgets(
      'GPS suggestions are selectable; served=$served keeps coverage server-controlled',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = SearchStore()
          ..served = served
          ..liveSocieties = [
            const Society(
              'served',
              'Example Society',
              'Example area',
              'Hyderabad',
              '500001',
            ),
          ];
        final router = AppRouter();
        await tester.pumpWidget(
          AppScope(
            store: store,
            router: router,
            child: const MaterialApp(home: AddressSearchScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Example Society'), findsOneWidget);
        expect(find.text('Google Maps'), findsOneWidget);
        expect(store.lookupQuery, '');
        expect(store.gpsPrompts, 0);
        await tester.tap(find.text('Example Society'));
        await tester.pumpAndSettle();
        expect(store.selections, 1);
        expect(router.last!.n, served ? N.floorSlot : N.manualAddress);
        if (served) {
          expect(store.draft.place!.society.id, 'served');
          expect(store.draft.place!.latitude, 17.4);
        } else {
          expect(store.draft.place, isNull);
          await tester.pumpWidget(
            AppScope(
              store: store,
              router: router,
              child: const MaterialApp(home: ManualAddressScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.widgetWithText(WTextField, '500001'), findsOneWidget);
          expect(store.searchedAddress!['city'], 'Hyderabad');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        router.dispose();
      },
    );
  }
  testWidgets('editing the query invalidates an in-flight selected address', (
    tester,
  ) async {
    final store = SearchStore()
          ..pendingSelection = Completer<Map<String, dynamic>>(),
        router = AppRouter();
    await tester.pumpWidget(
      AppScope(
        store: store,
        router: router,
        child: const MaterialApp(home: AddressSearchScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(nearby.name));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Another Society');
    await tester.pump(const Duration(milliseconds: 400));
    store.pendingSelection!.complete({
      'societyId': 'served',
      'place': {'name': nearby.name, 'latitude': 17.4, 'longitude': 78.35},
    });
    await tester.pumpAndSettle();
    expect(router.last, isNull);
    expect(store.draft.place, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });
  testWidgets(
    'waiting for GPS shows feedback and does not block typed suggestions',
    (tester) async {
      final store = SearchStore()..pendingGps = Completer<(double, double)?>(),
          router = AppRouter();
      await tester.pumpWidget(
        AppScope(
          store: store,
          router: router,
          child: const MaterialApp(home: AddressSearchScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Example');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(store.lookupQuery, 'Example');
      expect(find.text(nearby.name), findsOneWidget);
      store.pendingGps!.complete((17.4, 78.35));
      await tester.pumpAndSettle();
      expect(store.gpsPrompts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      router.dispose();
    },
  );
}
