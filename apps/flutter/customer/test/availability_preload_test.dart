import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/availability_cache.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';

// Isolated request fixture: no Firebase account, production capacity or new app
// testing control is created. The actual store preload and screen are exercised.
class PreloadStore extends AppStore {
  PreloadStore() {
    backendReady = true;
    liveSocieties = AppStore.societies;
    liveWindows = [for (var hour = 4; hour < 22; hour += 2) (hour, hour + 2)];
  }
  final cache = BookingAvailabilityCache();
  final requests = <(String, String, DateTime)>[];
  final replies = <Completer<Set<int>>>[];
  String account = 'customer-A';
  bool holdFirstAccount = false, fail = false;
  @override
  bool get isLive => true;
  @override
  String get availabilityContext => '$account:${super.availabilityContext}';
  @override
  Future<Set<int>> availabilityFor(String societyId, DateTime day, {bool fresh = false}) {
    cache.setContext(availabilityContext);
    return cache.load('$societyId:$day', () {
      requests.add((account, societyId, day));
      if (fail) return Future.error(StateError('Offline'));
      if (holdFirstAccount && account == 'customer-A') {
        final reply = Completer<Set<int>>(); replies.add(reply); return reply.future;
      }
      return Future.value({20});
    }, fresh: fresh);
  }
}

void main() {
  test('known saved society preloads before booking navigation, without selecting a place for the user', () async {
    final store = PreloadStore();
    store.set(() => store.savedPlaces = [AppStore.homePlace()]);
    expect(store.requests.length, 3);
    expect(store.requests.map((r) => r.$2).toSet(), {AppStore.societies.first.id});
    expect(store.draft.place, isNull);
    store.set(() => store.toast = 'Unrelated profile update');
    expect(store.requests.length, 3);
    await store.availabilityFor(AppStore.societies.first.id, store.requests.first.$3);
    store.dispose();
  });

  test('unknown or inactive saved society causes no speculative requests', () {
    final store = PreloadStore();
    store.startNewBooking();
    store.set(() => store.savedPlaces = [Place(const Society('inactive', 'Old society', '', '', ''))]);
    expect(store.requests, isEmpty);
    store.dispose();
  });

  test('society selection starts preloading before parking and subsequent steps reuse it', () async {
    final store = PreloadStore();
    store.set(() => store.draft.place = Place(AppStore.societies[1]));
    expect(store.requests.length, 3);
    store.set(() => store.draft.place!.slot = '42');
    store.prefetchAvailability();
    expect(store.requests.length, 3);
    store.set(() => store.draft.place = AppStore.homePlace());
    expect(store.requests.length, 6);
    await store.availabilityFor(AppStore.societies.first.id, store.requests.first.$3);
    store.dispose();
  });

  test('background preload failure stays retryable and does not surface an unhandled error', () async {
    final store = PreloadStore()..fail = true;
    store.set(() => store.draft.place = AppStore.homePlace());
    await Future<void>.delayed(Duration.zero);
    expect(store.requests.length, 3);
    store.fail = false;
    expect(await store.availabilityFor(AppStore.societies.first.id, store.requests.first.$3), {20});
    expect(store.requests.length, 4);
    store.dispose();
  });

  testWidgets('slot screen joins prefetch and an account change cannot apply the old response', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PreloadStore()..holdFirstAccount = true;
    final router = AppRouter();
    store.set(() => store.draft.place = AppStore.homePlace());
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: TimeSlotScreen())));
    expect(store.requests.length, 3, reason: 'The screen must join the prefetch request.');
    await tester.tap(find.text('Tomorrow')); await tester.pump();
    store.set(() => store.account = 'customer-B');
    await tester.pump(); await tester.pump();
    expect(store.requests.length, 6);
    for (final reply in store.replies) { reply.complete({4}); }
    await tester.pump(); await tester.pump();
    await tester.tap(find.text('Next'));
    expect(store.draft.slot?.startHour, 20);
    expect(router.last?.n, N.review);
    await tester.pumpWidget(const SizedBox());
    store.dispose(); router.dispose();
  });
}
