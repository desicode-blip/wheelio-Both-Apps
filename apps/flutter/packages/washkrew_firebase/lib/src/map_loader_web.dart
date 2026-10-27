import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('washkrewMapsReady')
external set _mapsReady(JSFunction callback);

Future<void>? _loading;
Future<void> prepareMap(Map<String, dynamic> config) =>
    _loading ??= _load(config).catchError((Object e) {
      _loading = null;
      throw e;
    });
Future<void> _load(Map<String, dynamic> config) async {
  final key = config['webKey'];
  if (key is! String || key.isEmpty)
    throw StateError('Maps are not configured.');
  final script = web.HTMLScriptElement()
    ..id = 'washkrew-google-maps'
    ..async = true;
  script.src = Uri.https('maps.googleapis.com', '/maps/api/js', {
    'key': key,
    'v': 'quarterly',
    'loading': 'async',
    'callback': 'washkrewMapsReady',
  }).toString();
  final ready = Completer<void>();
  _mapsReady = (() {
    if (!ready.isCompleted) ready.complete();
  }).toJS;
  script.onerror = ((web.Event e) {
    if (!ready.isCompleted)
      ready.completeError(StateError('Map could not load.'));
  }).toJS;
  web.document.head!.appendChild(script);
  try {
    await ready.future.timeout(const Duration(seconds: 20));
  } catch (_) {
    script.remove();
    rethrow;
  }
}
