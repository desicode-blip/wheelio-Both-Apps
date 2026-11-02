package com.amanmaheshwari.wheelio.customer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import com.razorpay.Checkout

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "washkrew/checkout").setMethodCallHandler { call, result ->
            if (call.method != "preload") {
                result.notImplemented()
            } else {
                try {
                    Checkout.preload(applicationContext)
                    result.success(null)
                } catch (_: Exception) {
                    result.error("checkout_preload", "Payment resources could not preload.", null)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "washkrew/maps").setMethodCallHandler { call, result ->
            if (call.method != "configure") {
                result.notImplemented()
            } else {
                val key = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData?.getString("com.google.android.geo.API_KEY")
                if (key.isNullOrBlank()) result.error("maps_configuration", "Maps are not configured.", null)
                else result.success(null)
            }
        }
    }
}
