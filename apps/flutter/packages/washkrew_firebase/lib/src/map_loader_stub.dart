import 'package:flutter/services.dart';

Future<void> prepareMap(Map<String, dynamic> config) async {
  final key = config['iosKey'];
  if (key is! String || key.isEmpty)
    throw StateError('Maps are not configured.');
  await const MethodChannel(
    'washkrew/maps',
  ).invokeMethod<void>('configure', {'key': key});
}
