// One layout everywhere: the apps are designed for a phone and are never stretched.
// On a laptop or any screen wider than a phone, the app keeps its phone size in the
// middle of the window and the space on both sides is greyed out. On a phone it fills
// the screen. See docs/FLUTTER.md ("One design on every screen").

import 'package:flutter/material.dart';

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child, this.below});
  final Widget child;

  /// Optional small widget shown under the phone on wide screens (e.g. nothing in production).
  final Widget? below;

  /// Screens up to this width get the full-screen phone layout.
  static const breakpoint = 600.0;
  static const phoneWidth = 390.0;
  static const phoneHeight = 844.0;
  static const side = Color(0xFFD9DEE6);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= breakpoint) return child;
    final h = (mq.size.height - 48).clamp(560.0, phoneHeight);
    final w = phoneWidth;
    return ColoredBox(
      color: side,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [BoxShadow(color: Color(0x33172130), blurRadius: 40, offset: Offset(0, 16))],
            ),
            clipBehavior: Clip.antiAlias,
            child: MediaQuery(
              data: mq.copyWith(size: Size(w, h), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero, viewInsets: EdgeInsets.zero),
              child: child,
            ),
          ),
          ?below,
        ]),
      ),
    );
  }
}
