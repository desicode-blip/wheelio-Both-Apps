// Browser versions of the device services (Web Audio, Notifications, Speech Synthesis).

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'device.dart' show Permission;
Future<void> downloadDocument(Future<String> url) async {
  final tab=web.window.open('','_blank');
  try{final target=await url;if(tab!=null){tab.opener=null;tab.location.href=target;}else{web.window.location.href=target;}}
  catch(_){tab?.close();rethrow;}
}

web.AudioContext? _audio;

/// Two-tone chime.
void ding() {
  try {
    final a = _audio ??= web.AudioContext();
    final t = a.currentTime;
    for (var i = 0; i < 2; i++) {
      final o = a.createOscillator();
      final g = a.createGain();
      o.frequency.value = i == 0 ? 880 : 1320;
      g.gain.setValueAtTime(0.0001, t + i * 0.12);
      g.gain.exponentialRampToValueAtTime(0.18, t + i * 0.12 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + i * 0.12 + 0.3);
      o.connect(g);
      g.connect(a.destination);
      o.start(t + i * 0.12);
      o.stop(t + i * 0.12 + 0.32);
    }
  } catch (_) {}
}

Permission _map(String p) => p == 'granted' ? Permission.allowed : p == 'denied' ? Permission.denied : Permission.unknown;

Permission notificationPermission() {
  try {
    return _map(web.Notification.permission);
  } catch (_) {
    return Permission.unknown;
  }
}

Future<Permission> requestNotifications() async {
  try {
    final p = await web.Notification.requestPermission().toDart;
    return _map(p.toDart);
  } catch (_) {
    return Permission.unknown;
  }
}

void systemNotify(String title, String body, bool silent) {
  try {
    if (web.Notification.permission == 'granted') web.Notification(title, web.NotificationOptions(body: body, silent: silent));
  } catch (_) {}
}

bool appIsActive() => web.document.visibilityState == 'visible';

bool isTouchDevice() => web.window.matchMedia('(pointer: coarse)').matches;

void Function() speak(String text, String lang, void Function() onEnd) {
  var done = false;
  Timer? fallback;
  final started = DateTime.now();
  void finish() {
    if (done) return;
    done = true;
    fallback?.cancel();
    onEnd();
  }

  // Without a voice (or if speech is blocked), the note "plays" for 12 seconds on a timer.
  void useTimer() {
    final left = 12000 - DateTime.now().difference(started).inMilliseconds;
    fallback = Timer(Duration(milliseconds: left < 0 ? 0 : left), finish);
  }

  try {
    final s = web.window.speechSynthesis;
    s.cancel();
    final u = web.SpeechSynthesisUtterance(text);
    u.lang = lang;
    u.rate = 0.9;
    u.onend = ((web.Event _) {
      if (DateTime.now().difference(started).inMilliseconds < 1500) {
        useTimer();
      } else {
        finish();
      }
    }).toJS;
    u.onerror = ((web.Event _) => useTimer()).toJS;
    s.speak(u);
  } catch (_) {
    useTimer();
  }
  return () {
    done = true;
    fallback?.cancel();
    try {
      web.window.speechSynthesis.cancel();
    } catch (_) {}
  };
}
