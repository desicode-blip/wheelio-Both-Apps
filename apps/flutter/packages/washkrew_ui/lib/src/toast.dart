import 'package:flutter/material.dart';

import 'components.dart';
import 'icons.dart';
import 'tokens.dart';

// 13 Nov 2026 (Aman): a small toast that fades in, stays briefly and fades away.
// It appears next to what was tapped: at the top of the screen for a control near the
// top, or just above a bottom button (pass that button's context as [above]).

OverlayEntry? _current;

void showWToast(BuildContext context, String text, {BuildContext? above, WIcon icon = WIcon.checkCircle}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final media = MediaQuery.of(context);
  double? top, bottom;
  final box = above?.findRenderObject();
  if (box is RenderBox && box.attached) {
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final y = box.localToGlobal(Offset.zero, ancestor: overlayBox).dy;
    bottom = (overlayBox?.size.height ?? media.size.height) - y + 12;
  } else {
    top = media.padding.top + 12;
  }
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 24,
      right: 24,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: _Toast(
          text: text,
          icon: icon,
          fromTop: top != null,
          onDone: () {
            if (_current == entry) _current = null;
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.text, required this.icon, required this.fromTop, required this.onDone});
  final String text;
  final WIcon icon;
  final bool fromTop;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), reverseDuration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _c.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: Offset(0, widget.fromTop ? -0.3 : 0.3), end: Offset.zero).animate(curve),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: WColor.heading,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WIconView(widget.icon, size: 18, color: WColor.success),
                  const SizedBox(width: 8),
                  Flexible(child: WText(widget.text, WType.bodyStrong, color: WColor.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 13 Nov 2026 (Aman): never let a customer or Captain walk into a dead end. Anything the
// live server can't do yet is greyed out at its entry point and says "Coming soon".

/// The "coming soon" message, as a toast at the top.
void showComingSoon(BuildContext context, [String feature = 'This']) =>
    showWToast(context, '$feature is coming soon. We’re working on it.', icon: WIcon.clock);

/// A small grey "Coming soon" pill.
class ComingSoonTag extends StatelessWidget {
  const ComingSoonTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(8), border: Border.all(color: WColor.border)),
    child: const WText('Coming soon', WType.small, color: WColor.secondary, weight: FontWeight.w600),
  );
}

/// Wraps an entry point. When [available] is false it is greyed out, can't be used, and a
/// tap says "[feature] is coming soon" instead of opening a journey that would dead-end.
class ComingSoonGate extends StatelessWidget {
  const ComingSoonGate({super.key, required this.available, required this.feature, required this.child, this.showTag = true});
  final bool available;
  final String feature;
  final Widget child;
  final bool showTag;
  @override
  Widget build(BuildContext context) {
    if (available) return child;
    return Semantics(
      button: true,
      label: '$feature, coming soon',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showComingSoon(context, feature),
        child: Stack(
          children: [
            Opacity(opacity: 0.45, child: IgnorePointer(child: ExcludeSemantics(child: child))),
            if (showTag) const Positioned(top: 8, right: 8, child: ComingSoonTag()),
          ],
        ),
      ),
    );
  }
}
