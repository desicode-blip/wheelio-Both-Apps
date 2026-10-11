import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../config/app_config.dart';
import '../routes.dart';
import '../state/app_state.dart';

/// C01-Splash
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.autoContinue = true});

  final bool autoContinue;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoContinue) {
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        final app = AppScope.read(context);
        context.go(app.isLoggedIn ? R.home : R.welcome);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WLogo(brandName: AppConfig.brandName, size: 48, onBrand: true),
            const SizedBox(height: 16),
            Text(AppConfig.tagline, style: WText.body.copyWith(color: WColors.primaryTint)),
          ],
        ),
      ),
    );
  }
}

/// C02-Welcome
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget value(IconData icon, String title, String sub) => Row(
          children: [
            WIconTile(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title, style: WText.title), Text(sub, style: WText.caption)],
              ),
            ),
          ],
        );

    return WScreen(
      padding: const EdgeInsets.fromLTRB(WSpace.gutter, 24, WSpace.gutter, 16),
      gap: 28,
      children: [
        const Align(alignment: Alignment.centerLeft, child: WLogo(brandName: AppConfig.brandName, size: 34)),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Clean wheels,\nzero hassle', style: WText.display)),
              const SizedBox(height: 12),
              Text(
                'Book a wash for your car or bike. Pay only after you see the photos.',
                style: WText.body.copyWith(fontSize: 17, height: 24 / 17),
              ),
            ],
          ),
        ),
        WGap(gap: 18, children: [
          value(Icons.photo_camera_outlined, 'Photo proof, every wash', 'Before and after, same angles'),
          value(Icons.verified_user_outlined, 'Money held safely', 'Released only when you approve'),
          value(Icons.schedule_rounded, 'You pick the time', 'A nearby washer comes to your parking'),
        ]),
      ],
      footer: WFooterBar(
        vertical: true,
        children: [
          WButton(
            label: 'Book a wash',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () {
              AppScope.read(context).draft.clear();
              context.push(R.vehicleType);
            },
          ),
          WButton.text(
            label: 'I already have an account',
            onPressed: () {
              AppScope.read(context).afterLogin = R.home;
              context.push(R.login);
            },
          ),
        ],
      ),
    );
  }
}
