// Isolated hardware adapter for controller/widget tests. Never used by app builds.
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image;
import 'package:washkrew_ui/washkrew_ui.dart';

const frontCamera = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);
const backCamera = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
final testPng = Uint8List.fromList(
  image.encodePng(image.Image(width: 4, height: 4)),
);

class FakeNativeCamera extends CameraController {
  FakeNativeCamera(
    CameraDescription description, {
    this.initializeGate,
    this.captureGate,
    this.failure,
  }) : super(description, ResolutionPreset.high, enableAudio: false);
  final Completer<void>? initializeGate, captureGate;
  final CameraException? failure;
  int captures = 0, releases = 0;
  @override
  Future<void> initialize() async {
    await initializeGate?.future;
    if (failure != null) throw failure!;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {}
  @override
  Future<XFile> takePicture() async {
    captures++;
    await captureGate?.future;
    return XFile.fromData(Uint8List.fromList(testPng));
  }

  @override
  Widget buildPreview() => const ColoredBox(
    color: Color(0xFF22282D),
    key: ValueKey('test-native-preview'),
  );
  @override
  Future<void> dispose() async {
    releases++;
    await super.dispose();
  }
}

class FakeCameraRig {
  final natives = <FakeNativeCamera>[];
  Completer<void>? firstInitializeGate, captureGate;
  bool denied = false;
  late final WCameraController controller = WCameraController(
    listCameras: () async => [backCamera, frontCamera],
    createCamera: (description) {
      final native = FakeNativeCamera(
        description,
        initializeGate: natives.isEmpty ? firstInitializeGate : null,
        captureGate: captureGate,
        failure: denied
            ? CameraException('CameraAccessDenied', 'Test permission denial')
            : null,
      );
      natives.add(native);
      return native;
    },
  );
}
