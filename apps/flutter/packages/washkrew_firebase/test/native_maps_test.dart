import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/map_loader_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('washkrew/maps');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'Android uses its manifest key rather than sending the iOS key',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return null;
      });
      await prepareMap({'iosKey': 'ios-only-key'});
      expect(received?.method, 'configure');
      expect(received?.arguments, isNull);
    },
  );
  test('iOS keeps the existing configure channel and its own key', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });
    await prepareMap({'iosKey': 'ios-only-key'});
    expect(received?.arguments, {'key': 'ios-only-key'});
    await expectLater(prepareMap({}), throwsStateError);
  });
  test('native map configuration failures stay visible for retry', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'maps_configuration');
    });
    await expectLater(prepareMap({}), throwsA(isA<PlatformException>()));
  });
}
