import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

Future<void> prepareMap(Map<String, dynamic> config) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android Maps reads its package/certificate-restricted key from the manifest.
    await const MethodChannel('washkrew/maps').invokeMethod<void>('configure');
    return;
  }
  final key = config['iosKey'];
  if (key is! String || key.isEmpty)
    throw StateError('Maps are not configured.');
  await const MethodChannel(
    'washkrew/maps',
  ).invokeMethod<void>('configure', {'key': key});
}
