// Device services used by both apps: sounds, haptics, notification permission, system
// notifications, calls, speech and photo picking. Web and mobile have their own versions.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'device_stub.dart' if (dart.library.js_interop) 'device_web.dart' as impl;

enum Permission { unknown, allowed, denied }

/// Placeholder until the real support number exists.
class Support {
  static const phone = '+910000000000';
  static const hours = '7 AM – 9 PM, every day. Calls in English, Hindi or Telugu.';

  /// Shown instead of dialling on a laptop (no phone to call from).
  static void Function(String number)? onCallUnavailable;

  static Future<void> call([String number = phone]) async {
    if (kIsWeb && !impl.isTouchDevice()) {
      onCallUnavailable?.call(number);
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: number));
  }
}

class Device {
  /// Short chime for a new update (iOS system sound 1007).
  static void ding() {
    if (kIsWeb) {
      impl.ding();
    } else {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  static void buzz([bool strong = false]) => strong ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();

  static Permission get notificationPermission => impl.notificationPermission();
  static Future<Permission> requestNotifications() => impl.requestNotifications();

  /// Notification while the app is in the background.
  static void systemNotify(String title, String body, {bool silent = false}) => impl.systemNotify(title, body, silent);

  static bool get appIsActive => impl.appIsActive();

  /// True when the app runs in a browser on a phone or tablet (touch screen).
  static bool get isTouch => !kIsWeb || impl.isTouchDevice();

  /// Speak text in a language; returns a function that stops it. [onEnd] runs when done.
  static void Function() speak(String text, String lang, void Function() onEnd) => impl.speak(text, lang, onEnd);

  /// Pick a photo from the library; returns its bytes.
  static Future<Uint8List?> pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    return f?.readAsBytes();
  }
  /// Directions to a typed address in Google Maps.
  static Future<bool> openMapsSearch(String address) => launchUrl(
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': address}),
    mode: LaunchMode.externalApplication,
  );
  static Future<bool> openLocation(num latitude, num longitude) => launchUrl(
    Uri.https('www.google.com','/maps/search/',{'api':'1','query':'$latitude,$longitude'}),
    mode: LaunchMode.externalApplication,
  );
}
