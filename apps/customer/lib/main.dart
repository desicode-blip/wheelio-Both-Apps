import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import 'config/app_config.dart';
import 'data/backend.dart';
import 'data/mock_backend.dart';
import 'router.dart';
import 'routes.dart';
import 'services/device.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Mock mode runs everything on sample data. When Supabase is connected,
  // build with --dart-define=BACKEND=supabase and return SupabaseBackend here.
  final Backend backend = AppConfig.useMock ? MockBackend() : _connectBackend();
  final Device device = MockDevice();

  runApp(WheelioCustomerApp(state: AppState(backend, device)));
}

Backend _connectBackend() {
  // TODO(connect): `await Supabase.initialize(url: AppConfig.supabaseUrl,
  // anonKey: AppConfig.supabaseAnonKey)` and `return SupabaseBackend();`.
  // See docs/CONNECT-LATER.md. Until then fall back to the mock.
  return MockBackend();
}

class WheelioCustomerApp extends StatefulWidget {
  const WheelioCustomerApp({super.key, required this.state});

  final AppState state;

  @override
  State<WheelioCustomerApp> createState() => _WheelioCustomerAppState();
}

class _WheelioCustomerAppState extends State<WheelioCustomerApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp.router(
        title: AppConfig.brandName,
        debugShowCheckedModeBanner: false,
        theme: buildWheelioTheme(),
        themeMode: ThemeMode.light,
        routerConfig: _router,
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (AppConfig.useMock) _GalleryButton(onTap: () => _router.push(R.gallery)),
          ],
        ),
      ),
    );
  }
}

/// Small "Screens" button in demo mode that opens the screen gallery.
class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A small tab on the left edge, clear of the app bar and footer buttons.
    final height = MediaQuery.sizeOf(context).height;
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(12)));
    return Positioned(
      top: height * 0.42,
      left: 0,
      child: Material(
        color: WColors.inverse.withValues(alpha: 0.72),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text('Screens', style: WText.label.copyWith(color: WColors.white, fontSize: 11)),
          ),
        ),
      ),
    );
  }
}
