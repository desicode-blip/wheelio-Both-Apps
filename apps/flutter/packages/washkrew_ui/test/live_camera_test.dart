import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'fake_camera.dart';

void main() {
  test(
    'camera begins on screen entry with the requested lens and captures directly',
    () async {
      final rig = FakeCameraRig();
      expect(rig.natives, isEmpty);
      await rig.controller.start(front: true);
      expect(rig.natives.single.description, frontCamera);
      expect(rig.controller.ready, true);
      expect(await rig.controller.capture(), testPng);
      expect(rig.natives.single.captures, 1);
      await rig.controller.stop();
      expect(rig.natives.single.releases, 1);
      expect(rig.controller.ready, false);
      rig.controller.dispose();
    },
  );
  test('simultaneous start requests share one initialization', () async {
    final gate = Completer<void>(),
        rig = FakeCameraRig()..firstInitializeGate = gate;
    final first = rig.controller.start(), second = rig.controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(rig.natives.length, 1);
    gate.complete();
    await Future.wait([first, second]);
    expect(rig.natives.length, 1);
    rig.controller.dispose();
  });
  test(
    'permission-dialog pause then resume restarts safely without retaining the old camera',
    () async {
      final gate = Completer<void>(),
          rig = FakeCameraRig()..firstInitializeGate = gate;
      final first = rig.controller.start(front: true);
      await Future<void>.delayed(Duration.zero);
      await rig.controller.stop();
      final resumed = rig.controller.start(front: true);
      gate.complete();
      await Future.wait([first, resumed]);
      expect(rig.natives.length, 2);
      expect(rig.natives.first.releases, 1);
      expect(rig.controller.ready, true);
      rig.controller.dispose();
    },
  );
  test(
    'leaving while initialization is pending never reopens the camera',
    () async {
      final gate = Completer<void>(),
          rig = FakeCameraRig()..firstInitializeGate = gate;
      final first = rig.controller.start();
      await Future<void>.delayed(Duration.zero);
      await rig.controller.stop();
      gate.complete();
      await first;
      expect(rig.controller.ready, false);
      expect(rig.natives.single.releases, 1);
      rig.controller.dispose();
    },
  );
  test(
    'disposal during initialization suppresses late state notifications',
    () async {
      final gate = Completer<void>(),
          rig = FakeCameraRig()..firstInitializeGate = gate;
      var notices = 0;
      rig.controller.addListener(() => notices++);
      final first = rig.controller.start();
      await Future<void>.delayed(Duration.zero);
      rig.controller.dispose();
      final before = notices;
      gate.complete();
      await first;
      expect(notices, before);
      expect(rig.natives.single.releases, 1);
      await rig.controller.start();
      expect(rig.natives.length, 1);
    },
  );
  test(
    'duplicate shutters do not take two pictures and a stopped capture is discarded',
    () async {
      final gate = Completer<void>(), rig = FakeCameraRig()..captureGate = gate;
      await rig.controller.start();
      final first = rig.controller.capture();
      expect(await rig.controller.capture(), isNull);
      expect(rig.natives.single.captures, 1);
      await rig.controller.stop();
      gate.complete();
      expect(await first, isNull);
      rig.controller.dispose();
    },
  );
  test('denied access can retry without inventing an image', () async {
    final rig = FakeCameraRig()..denied = true;
    await rig.controller.start(front: true);
    expect(rig.controller.denied, true);
    expect(await rig.controller.capture(), isNull);
    rig.denied = false;
    await rig.controller.start(front: true);
    expect(rig.controller.ready, true);
    expect(rig.controller.denied, false);
    rig.controller.dispose();
  });
  test(
    'missing hardware reports retry state without falling back to a system picker',
    () async {
      final controller = WCameraController(listCameras: () async => []);
      await controller.start();
      expect(controller.failed, true);
      expect(controller.ready, false);
      expect(await controller.capture(), isNull);
      controller.dispose();
    },
  );
}
