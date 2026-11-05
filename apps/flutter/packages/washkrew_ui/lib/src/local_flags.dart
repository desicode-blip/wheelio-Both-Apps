import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// v2 SH-NOTIFY: small yes/no facts remembered on this device only
/// (for example "we already asked about notifications"). Survives app
/// restarts; removed when the app is deleted. Falls back to memory on web.
class LocalFlags {
  static Map<String, bool>? _cache;

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/washkrew_flags.json');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, bool>> _load() async {
    if (_cache != null) return _cache!;
    final f = await _file();
    try {
      if (f != null && await f.exists()) {
        final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return _cache = {for (final e in data.entries) e.key: e.value == true};
      }
    } catch (_) {/* A damaged file is treated as empty. */}
    return _cache = {};
  }

  static Future<bool> get(String key) async => (await _load())[key] ?? false;

  static Future<void> set(String key, bool value) async {
    final map = await _load();
    map[key] = value;
    final f = await _file();
    try {
      await f?.create(recursive: true);
      await f?.writeAsString(jsonEncode(map));
    } catch (_) {/* Memory still holds it for this session. */}
  }

  // v2 CU-VEHICLE: small JSON lists kept on this device (e.g. saved vehicles
  // until the server stores them). Separate file from the yes/no flags.
  static Map<String, dynamic>? _json;

  static Future<File?> _jsonFile() async {
    final f = await _file();
    return f == null ? null : File(f.path.replaceFirst('washkrew_flags.json', 'washkrew_local.json'));
  }

  static Future<List<Map<String, dynamic>>> getList(String key) async {
    if (_json == null) {
      _json = {};
      try {
        final f = await _jsonFile();
        if (f != null && await f.exists()) _json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      } catch (_) {/* treated as empty */}
    }
    return [for (final e in (_json![key] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
  }

  static Future<void> setList(String key, List<Map<String, dynamic>> value) async {
    await getList(key);
    _json![key] = value;
    try {
      final f = await _jsonFile();
      await f?.create(recursive: true);
      await f?.writeAsString(jsonEncode(_json));
    } catch (_) {/* memory still holds it */}
  }

  /// v2 CU-VEHICLE: a small binary file on this device (e.g. a vehicle photo).
  static final Map<String, Uint8List> _bytes = {};
  static Future<void> saveBytes(String name, Uint8List data) async {
    _bytes[name] = data;
    final f = await _file();
    if (f == null) return;
    try {
      final out = File('${f.parent.path}/local_files/$name');
      await out.create(recursive: true);
      await out.writeAsBytes(data);
    } catch (_) {/* memory still holds it */}
  }

  static Future<Uint8List?> readBytes(String name) async {
    if (_bytes.containsKey(name)) return _bytes[name];
    final f = await _file();
    if (f == null) return null;
    try {
      final file = File('${f.parent.path}/local_files/$name');
      if (await file.exists()) return _bytes[name] = await file.readAsBytes();
    } catch (_) {}
    return null;
  }

  @visibleForTesting
  static void resetForTest() {
    _bytes.clear();
    _cache = {};
    _json = {};
  }
}
