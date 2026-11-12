import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permission_sequence.dart';

Future<void>? _requests;
Future<void> requestStartupPermissions() {
  if (!Platform.isAndroid && !Platform.isIOS) return Future.value();
  return _requests ??= _request().whenComplete(() => _requests = null);
}
Future<void> _request() async {
  try {
    final directory = await getApplicationSupportDirectory();
    const permissions = {'camera':Permission.camera, 'microphone':Permission.microphone,
      'location':Permission.locationWhenInUse, 'notifications':Permission.notification};
    File marker(String name) => File('${directory.path}/permission-v1-$name');
    await runPermissionSequence(
      alreadyAsked:(name)=>marker(name).exists(),
      remember:(name) async { await marker(name).writeAsString('asked', flush:true); },
      request:(name) async { await permissions[name]!.request(); },
    );
  } catch (_) { /* Per-feature permission checks remain available. */ }
}
