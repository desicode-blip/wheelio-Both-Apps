import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mapsConfigured = false
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "washkrew/maps", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "configure" else { result(FlutterMethodNotImplemented); return }
        guard let args = call.arguments as? [String: Any], let key = args["key"] as? String, !key.isEmpty else {
          result(FlutterError(code: "maps_configuration", message: "Maps are not configured.", details: nil)); return
        }
        if !self.mapsConfigured { GMSServices.provideAPIKey(key); self.mapsConfigured = true }
        result(nil)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
