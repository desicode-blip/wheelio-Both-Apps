import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// In-screen camera for the guided photo screens: the preview shows inside the
/// designed box and the shutter takes the photo right there (no system camera).
///
/// [start] reports `denied` when the person refused camera access, and `failed`
/// when there is no usable camera (laptop without one, simulator). Screens then
/// present permission/retry feedback in the existing screen.
class WCameraController extends ChangeNotifier {
  WCameraController({
    Future<List<CameraDescription>> Function()? listCameras,
    CameraController Function(CameraDescription)? createCamera,
  }) : _listCameras = listCameras ?? availableCameras,
       _createCamera = createCamera ?? _nativeCamera;
  final Future<List<CameraDescription>> Function() _listCameras;
  final CameraController Function(CameraDescription) _createCamera;
  static CameraController _nativeCamera(CameraDescription description) =>
      CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
  CameraController? _camera;
  bool ready = false, denied = false, failed = false, flashOn = false;
  bool _disposed = false,
      _wanted = false,
      _requestedFront = false,
      _activeFront = false,
      _capturing = false;
  int _generation = 0;
  Future<void>? _starting;

  CameraController? get camera => _camera;

  Future<void> start({bool front = false}) {
    if (_disposed) return Future.value();
    _wanted = true;
    _requestedFront = front;
    if (ready && _activeFront == front) return Future.value();
    final pending = _starting;
    if (pending != null) {
      return pending.then<void>((_) {
        if (!_disposed &&
            _wanted &&
            (!ready || _activeFront != _requestedFront)) {
          return start(front: _requestedFront);
        }
      });
    }
    final task = _initialize(front, ++_generation);
    _starting = task;
    return task.whenComplete(() {
      if (identical(_starting, task)) _starting = null;
    });
  }

  Future<void> _initialize(bool front, int generation) async {
    CameraController? opening;
    denied = false;
    failed = false;
    try {
      final previous = _camera;
      _camera = null;
      ready = false;
      if (!_disposed) notifyListeners();
      await _release(previous);
      final cameras = await _listCameras();
      if (_disposed || !_wanted || generation != _generation) return;
      if (cameras.isEmpty) {
        failed = true;
        return;
      }
      final want = front ? CameraLensDirection.front : CameraLensDirection.back;
      final description = cameras.firstWhere(
        (c) => c.lensDirection == want,
        orElse: () => cameras.first,
      );
      opening = _createCamera(description);
      await opening.initialize();
      if (_disposed || !_wanted || generation != _generation) return;
      if (!kIsWeb) {
        await opening
            .setFlashMode(flashOn ? FlashMode.always : FlashMode.off)
            .catchError((Object _) {});
      }
      if (_disposed || !_wanted || generation != _generation) return;
      _camera = opening;
      _activeFront = front;
      ready = true;
    } on CameraException catch (e) {
      if (_disposed || generation != _generation) return;
      if (e.code.contains('AccessDenied') ||
          e.code.contains('AccessRestricted') ||
          e.code.contains('NotAllowed')) {
        denied = true;
      } else {
        failed = true;
      }
    } catch (_) {
      if (!_disposed && generation == _generation) failed = true;
    } finally {
      if (!identical(opening, _camera)) await _release(opening);
      if (!_disposed && generation == _generation) notifyListeners();
    }
  }

  /// Takes the photo (JPEG bytes), or null when the camera is not ready or busy.
  Future<Uint8List?> capture() async {
    final camera = _camera;
    if (_disposed ||
        _capturing ||
        !ready ||
        camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture) {
      return null;
    }
    final generation = _generation;
    _capturing = true;
    try {
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      return !_disposed &&
              generation == _generation &&
              identical(camera, _camera)
          ? bytes
          : null;
    } catch (_) {
      if (_disposed || generation != _generation) return null;
      rethrow;
    } finally {
      _capturing = false;
    }
  }

  Future<void> toggleFlash() async {
    if (_disposed) return;
    flashOn = !flashOn;
    notifyListeners();
    final camera = _camera;
    if (camera != null && !kIsWeb) {
      await camera
          .setFlashMode(flashOn ? FlashMode.always : FlashMode.off)
          .catchError((Object _) {});
    }
  }

  /// Releases the camera (app in the background, screen closed).
  Future<void> stop() async {
    _wanted = false;
    _generation++;
    final camera = _camera;
    _camera = null;
    ready = false;
    if (!_disposed) notifyListeners();
    await _release(camera);
  }

  Future<void> _release(CameraController? camera) async {
    try {
      await camera?.dispose();
    } catch (_) {
      /* A failed initialization may already have released the platform camera. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _generation++;
    final camera = _camera;
    _camera = null;
    ready = false;
    _release(camera);
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
      if (!controller.ready || camera == null || !camera.value.isInitialized) {
        return const SizedBox.expand();
      }
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
