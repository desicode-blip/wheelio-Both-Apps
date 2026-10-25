// WashKrew logo, shared by the Customer and Captain apps.
// Source artwork (SVG masters, supplied 25 Oct 2026) lives in /brand at the repo root.
// The PNGs in lib/brand/ are rendered from those SVGs at 1x, 2x and 3x (64 px base height).

import 'package:flutter/widgets.dart';

import 'tokens.dart';

enum WLogoKind {
  /// Door mark + "WashKrew" + "Vehicle cleaning, on demand". The hero logo: splash, sign-in.
  lockup,

  /// Door mark + "WashKrew", no tagline. For headers and small spaces.
  wordmark,

  /// Door mark only. For tight spots next to other text.
  mark,
}

/// The WashKrew logo. Light theme by default; [onDark] switches to the white-door
/// version for dark backgrounds. Never recolour or redraw the logo in code.
class WLogo extends StatelessWidget {
  const WLogo({super.key, this.kind = WLogoKind.wordmark, this.height = 40, this.onDark = false});
  final WLogoKind kind;
  final double height;
  final bool onDark;

  String get _file => switch (kind) {
    WLogoKind.lockup => onDark ? 'lockup_dark' : 'lockup_light',
    WLogoKind.wordmark => onDark ? 'wordmark_dark' : 'wordmark_light',
    WLogoKind.mark => onDark ? 'mark_white' : 'mark',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: Brand.name,
    image: true,
    child: Image.asset(
      'lib/brand/$_file.png',
      package: 'wheelio_ui',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
