/// Phone features the app uses: camera, location, notifications, calls.
///
/// [MockDevice] lets the whole flow run in the simulator with no plugins.
/// When the real plugins are added (image_picker / camera, geolocator,
/// firebase_messaging, url_launcher) write `PluginDevice implements Device`
/// and pass it to AppState in main.dart. See docs/CONNECT-LATER.md.
abstract class Device {
  /// Asks for camera access if needed. False when denied (C08b).
  Future<bool> ensureCamera();

  /// Takes one photo with the in-app camera. Returns a local file path,
  /// or null if the customer backed out. Gallery picks are not allowed:
  /// photos are in-app camera only, time and location stamped.
  Future<String?> takePhoto();

  /// Current position, or null when location is off or denied (C09b).
  Future<({double lat, double lng})?> currentLocation();

  Future<bool> requestNotifications();

  /// Opens the phone dialer (masked number), WhatsApp or a web page.
  Future<void> openExternal(Uri uri);
}

class MockDevice implements Device {
  bool cameraAllowed = true;
  bool locationOn = true;

  @override
  Future<bool> ensureCamera() async => cameraAllowed;

  @override
  Future<String?> takePhoto() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return '';
  }

  @override
  Future<({double lat, double lng})?> currentLocation() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return locationOn ? (lat: 17.392, lng: 78.358) : null;
  }

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<void> openExternal(Uri uri) async {}
}
