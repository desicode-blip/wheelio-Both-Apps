import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/booking_availability.dart';

void main() {
  test('an approval or new working hours becomes visible on refresh', () async {
    final s = BookingAvailability();
    await s.load('soc:today', () async => {});
    expect(s.available, isEmpty);
    await s.load('soc:today', () async => {4, 20}, refresh: true);
    expect(s.available, {4, 20});
    s.toggleAll();
    expect(s.selected, {4, 20});
    s.dispose();
  });
  test('old date responses cannot overwrite a later date, including A-B-A', () async {
    final s = BookingAvailability(), old = Completer<Set<int>>();
    final pending = s.load('A', () => old.future);
    await s.load('B', () async => {8});
    await s.load('A', () async => {20});
    old.complete({4}); await pending;
    expect(s.selected, {20});
    s.dispose();
  });
  test('refresh preserves selected windows and all-day intent as capacity changes', () async {
    final s = BookingAvailability();
    await s.load('today', () async => {4, 8, 20}, initial: {8});
    await s.load('today', () async => {4, 8, 18, 20}, refresh: true);
    expect(s.selected, {8});
    s.toggleAll();
    await s.load('today', () async => {8, 20}, refresh: true);
    expect(s.selected, {8, 20});
    await s.load('today', () async => {4, 8, 20}, refresh: true);
    expect(s.selected, {4, 8, 20});
    s.dispose();
  });
  test('lost capacity never silently substitutes an unchosen time', () async {
    final s = BookingAvailability();
    await s.load('today', () async => {8, 20});
    await s.load('today', () async => {20}, refresh: true);
    expect(s.selected, isEmpty);
    s.dispose();
  });
  test('failed refresh cannot leave stale windows bookable; retry recovers', () async {
    final s = BookingAvailability();
    await s.load('today', () async => {8});
    await s.load('today', () async => throw 'Offline', refresh: true);
    expect(s.error, 'Offline'); expect(s.available, isEmpty);
    await s.load('today', () async => {20}, refresh: true);
    expect(s.error, isNull); expect(s.available, {20});
    s.dispose();
  });
  test('background refresh leaves controls visible and ignores duplicate refreshes', () async {
    final s = BookingAvailability(), result = Completer<Set<int>>();
    await s.load('today', () async => {8});
    final pending = s.load('today', () => result.future, refresh: true);
    expect(s.loading, isFalse); expect(s.available, {8});
    await s.load('today', () async => throw 'Duplicate', refresh: true);
    result.complete({8, 20}); await pending;
    expect(s.error, isNull); expect(s.available, {8, 20});
    s.dispose();
  });
}
