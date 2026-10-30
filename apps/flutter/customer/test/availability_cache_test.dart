import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/availability_cache.dart';

void main() {
  test('prefetch, screen and explicit refresh share one pending request even after 45 seconds', () async {
    var now = DateTime(2026, 11, 1), calls = 0;
    final cache = BookingAvailabilityCache(now: () => now), reply = Completer<Set<int>>();
    Future<Set<int>> request() { calls++; return reply.future; }
    final prefetch = cache.load('soc:today', request);
    now = now.add(const Duration(minutes: 1));
    expect(identical(prefetch, cache.load('soc:today', request)), isTrue);
    expect(identical(prefetch, cache.load('soc:today', request, fresh: true)), isTrue);
    expect(calls, 1);
    reply.complete({4, 20});
    expect(await prefetch, {4, 20});
    expect(await cache.load('soc:today', request), {4, 20});
    expect(calls, 1);
  });

  test('completed results expire and refresh reads new capacity without restoring a failed result', () async {
    var now = DateTime(2026, 11, 1), calls = 0;
    final cache = BookingAvailabilityCache(now: () => now);
    Future<Set<int>> request() async { calls++; return {calls == 1 ? 4 : 20}; }
    expect(await cache.load('soc:today', request), {4});
    now = now.add(const Duration(seconds: 44));
    expect(await cache.load('soc:today', request), {4});
    expect(calls, 1);
    now = now.add(const Duration(seconds: 1));
    expect(await cache.load('soc:today', request), {20});
    expect(calls, 2);
    await expectLater(cache.load('soc:today', () async => throw StateError('Offline'), fresh: true), throwsStateError);
    expect(await cache.load('soc:today', request), {20});
    expect(calls, 3);
  });

  test('an account, mode or catalog change rejects old in-flight capacity and preserves the replacement', () async {
    final cache = BookingAvailabilityCache();
    for (final context in ['customer-A:live:1', 'customer-B:live:1', 'customer-B:test:1', 'customer-B:test:2']) {
      final old = Completer<Set<int>>();
      final pending = cache.load('soc:today', () => old.future, fresh: true);
      final rejected = expectLater(pending, throwsStateError);
      cache.setContext(context);
      expect(await cache.load('soc:today', () async => {20}), {20});
      old.complete({4});
      await rejected;
      expect(await cache.load('soc:today', () async => throw StateError('Must use replacement')), {20});
    }
  });

  test('societies and dates never borrow each other’s capacity; failed prefetch can retry immediately', () async {
    final cache = BookingAvailabilityCache();
    expect(await cache.load('soc-A:today', () async => {4}), {4});
    expect(await cache.load('soc-A:tomorrow', () async => {8}), {8});
    expect(await cache.load('soc-B:today', () async => {20}), {20});
    await expectLater(cache.load('soc-B:tomorrow', () => throw StateError('Network')), throwsStateError);
    expect(await cache.load('soc-B:tomorrow', () async => {6}), {6});
    expect(await cache.load('soc-A:today', () async => {}), {4});
  });

  test('clearing for disposal invalidates pending work', () async {
    final cache = BookingAvailabilityCache(), reply = Completer<Set<int>>();
    final pending = cache.load('soc:today', () => reply.future);
    final rejected = expectLater(pending, throwsStateError);
    cache.clear(); reply.complete({4});
    await rejected;
  });
}
