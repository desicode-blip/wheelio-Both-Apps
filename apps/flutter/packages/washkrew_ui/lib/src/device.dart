// Device services used by both apps: sounds, haptics, notification permission, system
// notifications, calls, speech and photo picking. Web and mobile have their own versions.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tokens.dart';

import 'device_stub.dart'
    if (dart.library.js_interop) 'device_web.dart'
    as impl;

enum Permission { unknown, allowed, denied }

class MediaAccessException implements Exception {
  const MediaAccessException(this.message, {this.settings = false});
  final String message;
  final bool settings;
  @override
  String toString() => message;
}

/// Published operations configuration, shared by the existing support controls.
class Support {
  static String phone='',hours='Support hours will be confirmed.',email='',policiesUrl='';
  static void configure(Map<String,dynamic> config){
    final support=config['support'] as Map? ?? {},legal=config['legal'] as Map? ?? {};
    phone=support['phone'] as String? ?? '';hours=support['hours'] as String? ?? 'Support hours will be confirmed.';
    email=support['email'] as String? ?? '';policiesUrl=legal['termsPrivacyUrl'] as String? ?? '';
  }
  static void Function(String message)? onUnavailable;
  static Future<void> openPolicies() async {
    final url=Uri.tryParse(policiesUrl);
    if(url?.scheme!='https'||url!.host.isEmpty){onUnavailable?.call('Terms and privacy are awaiting publication.');return;}
    if(!await launchUrl(url,mode:LaunchMode.externalApplication))onUnavailable?.call('The policies could not open. Try again.');
  }

  /// Shown instead of dialling on a laptop (no phone to call from).
  static void Function(String number)? onCallUnavailable;

  static Future<void> call([String? target]) async {
    final number=target??phone;
    if(!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(number)){onUnavailable?.call('The support number is awaiting publication. Send a help request in the app.');return;}
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

  static void buzz([bool strong = false]) =>
      strong ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();

  static Permission get notificationPermission => impl.notificationPermission();
  static Future<Permission> requestNotifications() =>
      impl.requestNotifications();

  /// Notification while the app is in the background.
  static void systemNotify(String title, String body, {bool silent = false}) =>
      impl.systemNotify(title, body, silent);

  static bool get appIsActive => kIsWeb ? impl.appIsActive() : WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// True when the app runs in a browser on a phone or tablet (touch screen).
  static bool get isTouch => !kIsWeb || impl.isTouchDevice();

  /// Speak text in a language; returns a function that stops it. [onEnd] runs when done.
  static void Function() speak(
    String text,
    String lang,
    void Function() onEnd,
  ) => impl.speak(text, lang, onEnd);

  static bool _pickingImage = false;

  /// Capture and library are deliberately separate: opening the library never
  /// requests camera access and a cancelled picker never invents a photo.
  static Future<Uint8List?> pickImage({
    bool camera = false,
    bool front = false,
  }) async {
    if (_pickingImage) {
      throw const MediaAccessException(
        'A photo picker is already open. Finish or cancel it first.',
      );
    }
    _pickingImage = true;
    try {
      final f = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (f == null) return null;
      if (await f.length() > 8 * 1024 * 1024) {
        throw const MediaAccessException('Choose a photo smaller than 8 MB.');
      }
      return await f.readAsBytes();
    } on PlatformException catch (error) {
      final denied =
          error.code.toLowerCase().contains('denied') ||
          error.code.toLowerCase().contains('restricted');
      throw MediaAccessException(
        denied
            ? 'Allow ${camera ? 'Camera' : 'Photos'} access for ${Brand.name} in Settings, then try again.'
            : 'The ${camera ? 'camera' : 'photo library'} could not open. Try again or choose another photo source.',
        settings: denied && !kIsWeb,
      );
    } finally {
      _pickingImage = false;
    }
  }

  static Future<Uint8List?> chooseImage(
    BuildContext context, {
    bool front = false,
  }) async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheet, true),
          ),
          ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from photos'),
            onTap: () => Navigator.pop(sheet, false),
          ),
          ListTile(
            minTileHeight: 64,
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(sheet),
          ),
        ],
      ),
    );
    if (camera == null) return null;
    return pickImage(camera: camera, front: front);
  }

  static Future<void> openSettings() async {
    if (!kIsWeb) await AppSettings.openAppSettings();
  }
  static Future<void> downloadDocument(Future<String> url) async {
    final checked=url.then((value){
      final uri=Uri.parse(value);
      if(!((uri.scheme=='https'&&uri.host=='asia-south1-wheelio-apps.cloudfunctions.net')||(uri.scheme=='http'&&['localhost','127.0.0.1'].contains(uri.host))))throw StateError('The document download is unavailable.');
      return value;
    });
    if(kIsWeb){await impl.downloadDocument(checked);return;}
    if(!await launchUrl(Uri.parse(await checked),mode:LaunchMode.externalApplication))throw StateError('The document could not open. Try again.');
  }

  /// Directions to a typed address in Google Maps.
  static Future<bool> openMapsSearch(String address) => launchUrl(
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    }),
    mode: LaunchMode.externalApplication,
  );
  static Future<bool> openLocation(num latitude, num longitude) => launchUrl(
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    }),
    mode: LaunchMode.externalApplication,
  );
}
