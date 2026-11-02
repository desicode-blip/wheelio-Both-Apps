import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/presence.dart';

void main() {
  test('online startup and resume refresh immediately, profile echoes do not loop', () async {
    final sent = <String>[];
    final presence = CaptainPresence((uid) async => sent.add(uid));
    presence.profile('captain', online: true);
    await presence.refresh();
    expect(sent, ['captain']);
    presence.profile('captain', online: true);
    presence.foreground(true);
    await Future<void>.delayed(Duration.zero);
    expect(sent.length, 1);
    presence.foreground(false);
    presence.foreground(true);
    await presence.refresh();
    expect(sent, ['captain', 'captain']);
  });

  test('concurrent resumes share a request; failure allows the next retry', () async {
    final pending = Completer<void>();
    var count = 0;
    final presence = CaptainPresence((_) {
      count++;
      return count == 1 ? pending.future : Future.value();
    });
    presence.profile('captain', online: true);
    presence.foreground(false);
    presence.foreground(true);
    final refresh = presence.refresh();
    expect(count, 1);
    pending.completeError(StateError('network unavailable'));
    await refresh;
    await Future<void>.delayed(Duration.zero);
    await presence.refresh();
    expect(count, 2);
  });

  test('offline, sign-out and replacement accounts keep presence isolated', () async {
    final sent = <String>[];
    final pending = Completer<void>();
    final presence = CaptainPresence((uid) {
      sent.add(uid);
      return uid == 'first' ? pending.future : Future.value();
    });
    presence.profile('first', online: false);
    await presence.refresh();
    expect(sent, isEmpty);
    presence.profile('first', online: true);
    presence.clear();
    presence.foreground(false);
    presence.foreground(true);
    await presence.refresh();
    expect(sent, ['first']);
    presence.profile('second', online: true);
    await presence.refresh();
    expect(sent, ['first', 'second']);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    presence.profile('second', online: false);
    presence.foreground(false);
    presence.foreground(true);
    await presence.refresh();
    expect(sent.length, 2);
  });
}
