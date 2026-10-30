import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// In-screen camera for the guided photo screens: the preview shows inside the
/// designed box and the shutter takes the photo right there (no system camera).
///
/// [start] reports `denied` when the person refused camera access, and `failed`
/// when there is no usable camera (laptop without one, simulator). Screens then
/// fall back to the existing picker/sample path.
class WCameraController extends ChangeNotifier {
  CameraController? _camera;
  bool ready = false, denied = false, failed = false, flashOn = false;
  bool _starting = false, _disposed = false;

  CameraController? get camera => _camera;

  Future<void> start({bool front = false}) async {
    if (_starting || ready || _disposed) return;
    _starting = true;
    denied = false;
    failed = false;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        failed = true;
        return;
      }
      final want = front ? CameraLensDirection.front : CameraLensDirection.back;
      final description = cameras.firstWhere((c) => c.lensDirection == want, orElse: () => cameras.first);
      final camera = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
      await camera.initialize();
      if (_disposed) {
        await camera.dispose();
        return;
      }
      if (!kIsWeb) await camera.setFlashMode(flashOn ? FlashMode.always : FlashMode.off).catchError((Object _) {});
      _camera = camera;
      ready = true;
    } on CameraException catch (e) {
      if (e.code.contains('AccessDenied') || e.code.contains('AccessRestricted') || e.code.contains('NotAllowed')) {
        denied = true;
      } else {
        failed = true;
      }
    } catch (_) {
      failed = true;
    } finally {
      _starting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Takes the photo (JPEG bytes), or null when the camera is not ready or busy.
  Future<Uint8List?> capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || camera.value.isTakingPicture) return null;
    final file = await camera.takePicture();
    return file.readAsBytes();
  }

  Future<void> toggleFlash() async {
    flashOn = !flashOn;
    notifyListeners();
    final camera = _camera;
    if (camera != null && !kIsWeb) {
      await camera.setFlashMode(flashOn ? FlashMode.always : FlashMode.off).catchError((Object _) {});
    }
  }

  /// Releases the camera (app in the background, screen closed).
  Future<void> stop() async {
    final camera = _camera;
    _camera = null;
    ready = false;
    if (!_disposed) notifyListeners();
    await camera?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    final camera = _camera;
    _camera = null;
    camera?.dispose();
    super.dispose();
  }
}

/// The live preview, filling (cropping to) whatever box it is placed in.
class WCameraPreview extends StatelessWidget {
  const WCameraPreview(this.controller, {super.key});
  final WCameraController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final camera = controller.camera;
          if (!controller.ready || camera == null || !camera.value.isInitialized) return const SizedBox.expand();
          final size = camera.value.previewSize;
          // previewSize is landscape (sensor) on phones; the screen is portrait.
          final w = size == null ? 3.0 : (kIsWeb ? size.width : size.height);
          final h = size == null ? 4.0 : (kIsWeb ? size.height : size.width);
          return ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: w, height: h, child: CameraPreview(camera)),
            ),
          );
        },
      );
}
