import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import 'backend.dart';
import 'live_backend.dart';

/// The designed sample-data apps are available only with an explicit demo URL.
Future<void> launchWashKrew({
  required bool captain,
  required Widget demo,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  WashKrewRuntime.backend = null;
  // Web: ?demo=true. Phone builds: --dart-define=WHEELIO_DEMO=true (sample data, no Firebase).
  if (Uri.base.queryParameters['demo'] == 'true' ||
      const bool.fromEnvironment('WHEELIO_DEMO')) {
    runApp(demo);
    return;
  }
  Object? initializationError;
  try {
    await WashKrewFirebase.initialize(captain: captain);
    WashKrewRuntime.backend = LiveBackend();
  } catch (error) {
    initializationError = error;
  }
  runApp(
    initializationError == null
        ? demo
        : _InitializationFailureApp(captain: captain),
  );
}

/// Label every explicit sample-data build, including installed phone builds.
class DemoLabel extends StatelessWidget {
  const DemoLabel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => !WashKrewRuntime.demo
      ? child
      : Column(
          children: [
            const Material(
              color: Color(0xFFFFE6A8),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: Center(
                    child: Text(
                      'DEMO · Sample data · No bookings or payments',
                      style: TextStyle(
                        color: WColor.heading,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
}

class _InitializationFailureApp extends StatelessWidget {
  const _InitializationFailureApp({required this.captain});
  final bool captain;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: captain ? Brand.captainApp : Brand.name,
    theme: ThemeData(
      fontFamily: wFont,
      useMaterial3: true,
      scaffoldBackgroundColor: WColor.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WColor.primary,
        primary: WColor.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    builder: (context, child) => PhoneFrame(child: child!),
    home: const _Unavailable(),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WLogo(kind: WLogoKind.lockup, height: 72),
            SizedBox(height: 32),
            Text(
              'We’re getting ready',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'The live app is not configured yet. Please come back soon.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
