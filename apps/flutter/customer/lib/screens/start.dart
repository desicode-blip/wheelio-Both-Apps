import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/store.dart';
import 'common.dart';

// MARK: C01 Splash

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Timer _t = Timer(const Duration(milliseconds: 1300), widget.onDone);
  @override
  void initState() {
    super.initState();
    _t;
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: WColor.primary,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandMark(size: 40, light: true),
          const SizedBox(height: 14),
          WText(Brand.tagline, WType.body, color: WColor.white.withValues(alpha: 0.92)),
        ],
      ),
    ),
  );
}

// MARK: C02 Welcome: three slides, one feeling each (same pattern as the Captain app)

/// Big picture, two short lines, a quiet "Next". The dots double as the timer:
/// each fills from the left, then the next slide comes. Skip goes straight in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

enum WelcomeArtKind { morning, trust, time }

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const slideMs = 3500;
  static const slides = [
    (WelcomeArtKind.morning, 'Wake up to a clean car', 'A captain washes it in your parking. You don’t need to be there.'),
    (WelcomeArtKind.trust, 'See it, then pay', 'Before and after photos. Money moves only when you approve.'),
    (WelcomeArtKind.time, 'Your weekend is yours', 'Spend it with family, not with a bucket.'),
  ];
  final _pages = PageController();
  int index = 0;
  double progress = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Auto-advance: fills the active dot over [slideMs], then slides to the next picture.
  void _start() {
    _tick?.cancel();
    progress = 0;
    final started = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 60), (t) {
      final p = (DateTime.now().difference(started).inMilliseconds / slideMs).clamp(0.0, 1.0);
      setState(() => progress = p);
      if (p >= 1) {
        t.cancel();
        if (index < slides.length - 1) _go(index + 1);
      }
    });
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
  }

  /// Back / Next / auto-advance: the whole slide (picture and words) moves sideways.
  void _go(int i) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(i.clamp(0, slides.length - 1), duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
  }

  /// Into Home, where "Book a wash" is the main button.
  void _enterApp() {
    context.store.set(() => context.store.hasSeenWelcome = true);
    context.router.popToRoot();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pages.dispose();
    super.dispose();
  }

  (WelcomeArtKind, String, String) _slide(int i) => context.store.isLive && i == 1
      ? (WelcomeArtKind.trust, 'See your wash clearly', 'Pay securely when booking. Review before and after photos to approve the captain’s earnings.')
      : slides[i];

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: WColor.white,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom + 12),
        child: Column(
          children: [
            // Back stays in place; it fades in after the first slide.
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: index > 0 ? 1 : 0,
                      child: Pressable(
                        enabled: index > 0,
                        onTap: () => _go(index - 1),
                        child: const SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              WIconView(WIcon.left, size: 15, weight: semibold),
                              SizedBox(width: 4),
                              WText('Back', WType.body, color: WColor.heading),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Carousel: picture and words move together with the finger (or mouse).
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  // Pause the timer while the person is dragging; restart once it settles.
                  if (n is ScrollStartNotification && n.dragDetails != null) _stop();
                  if (n is ScrollEndNotification && _tick == null) _start();
                  return false;
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
                    scrollbars: false,
                  ),
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: slides.length,
                    physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                    onPageChanged: (i) {
                      setState(() => index = i);
                      _start();
                    },
                    itemBuilder: (context, i) {
                      final s = _slide(i);
                      return Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(WSpace.gutter, 8, WSpace.gutter, 0),
                              child: CustomerWelcomeArt(kind: s.$1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(WSpace.gutter, 28, WSpace.gutter, 0),
                            child: Column(
                              children: [
                                WText(s.$2, WType.screen, size: 26, align: TextAlign.center),
                                const SizedBox(height: 10),
                                WText(s.$3, WType.body, color: WColor.secondary, size: 16.5, align: TextAlign.center),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            // Dots follow the carousel position while swiping.
            AnimatedBuilder(
              animation: _pages,
              builder: (context, _) {
                final page = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? index.toDouble()) : index.toDouble();
                return CarouselDots(count: slides.length, page: page, progress: _tick == null ? 0 : progress);
              },
            ),
            // Skip and Next stay put; only the carousel moves.
            Padding(
              padding: const EdgeInsets.fromLTRB(WSpace.gutter, 26, WSpace.gutter, 0),
              child: Row(
                children: [
                  Pressable(
                    onTap: _enterApp,
                    child: const SizedBox(
                      height: 48,
                      child: Center(child: WText('Skip', WType.body, color: WColor.secondary)),
                    ),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: () => index < slides.length - 1 ? _go(index + 1) : _enterApp(),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      decoration: const ShapeDecoration(color: WColor.primaryTint, shape: StadiumBorder()),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WText('Next', WType.title, color: WColor.primaryStrong, size: 17),
                          SizedBox(width: 8),
                          WIconView(WIcon.arrowRight, size: 15, color: WColor.primaryStrong, weight: semibold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide pictures (drawn, gently animated).
class CustomerWelcomeArt extends StatelessWidget {
  const CustomerWelcomeArt({super.key, required this.kind});
  final WelcomeArtKind kind;

  static const _sun = Color(0xFFFFC56E);

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      WelcomeArtKind.morning => const [Color(0xFFFFE9D2), Color(0xFFDCEBFF)],
      WelcomeArtKind.trust => const [Color(0xFFE8ECFF), Color(0xFFF5F7FF)],
      WelcomeArtKind.time => const [Color(0xFFE3F6EE), Color(0xFFFFF6E3)],
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bg, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: LayoutBuilder(
          builder: (c, box) {
            final w = box.maxWidth, h = box.maxHeight;
            Widget at(double x, double y, Widget child) => Positioned(
              left: w * x,
              top: h * y,
              child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
            );
            return Pulse(
              duration: const Duration(milliseconds: 2200),
              builder: (c, on) => Stack(
                clipBehavior: Clip.hardEdge,
                children: switch (kind) {
                  // Sunrise over the building; a gleaming car with sparkles in the parking.
                  WelcomeArtKind.morning => [
                    at(
                      0.74,
                      0.26,
                      Transform.scale(
                        scale: 0.95 + 0.11 * on,
                        child: Container(
                          width: w * 0.62,
                          height: w * 0.62,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _sun.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                    at(
                      0.74,
                      0.26,
                      Container(
                        width: w * 0.32,
                        height: w * 0.32,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: _sun),
                      ),
                    ),
                    at(0.26, 0.40, WIconView(WIcon.building, size: h * 0.30, color: const Color(0xFFB9C8DD))),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.27,
                      child: const ColoredBox(color: Color(0xFFC9D6E8)),
                    ),
                    at(0.5, 0.70, WIconView(WIcon.carFill, size: h * 0.24, color: WColor.primary)),
                    for (final (i, p) in const [(0.30, 0.58), (0.62, 0.55), (0.74, 0.70), (0.44, 0.52)].indexed)
                      at(
                        p.$1,
                        p.$2,
                        Opacity(
                          opacity: (i.isEven ? on : 1 - on) * 0.6 + 0.4,
                          child: Transform.scale(
                            scale: 0.6 + 0.6 * (i.isEven ? on : 1 - on),
                            child: WIconView(WIcon.sparkleFill, size: i.isEven ? 22 : 15, color: WColor.white),
                          ),
                        ),
                      ),
                  ],
                  // A phone with before / after photos and a green tick; a shield floats beside it.
                  WelcomeArtKind.trust => [
                    at(
                      0.46,
                      0.52,
                      Container(
                        width: w * 0.50,
                        height: h * 0.74,
                        decoration: BoxDecoration(
                          color: WColor.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [BoxShadow(color: WColor.primary.withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 8))],
                        ),
                      ),
                    ),
                    at(
                      0.46,
                      0.52,
                      SizedBox(
                        width: w * 0.42,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _photo('Before', true),
                            const SizedBox(height: 10),
                            _photo('After', false),
                            const SizedBox(height: 10),
                            Transform.scale(
                              scale: 0.98 + 0.06 * on,
                              child: Container(
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: const ShapeDecoration(color: WColor.success, shape: StadiumBorder()),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    WIconView(WIcon.check, size: 12, color: WColor.white, weight: bold),
                                    SizedBox(width: 6),
                                    WText('Approve', WType.label, color: WColor.white, size: 13),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    at(
                      0.80,
                      0.26,
                      Transform.translate(
                        offset: Offset(0, 4 - 10 * on),
                        child: WIconView(WIcon.shield, size: h * 0.12, color: WColor.primary, weight: bold),
                      ),
                    ),
                  ],
                  // A family out together on a sunny day; the clean car waits at home.
                  WelcomeArtKind.time => [
                    at(
                      0.80,
                      0.18,
                      Transform.scale(
                        scale: 0.96 + 0.1 * on,
                        child: Container(
                          width: w * 0.22,
                          height: w * 0.22,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD27A)),
                        ),
                      ),
                    ),
                    at(0.24 + 0.06 * on, 0.16, const WIconView(WIcon.cloud, size: 34, color: WColor.white)),
                    Positioned(
                      left: -w * 0.25,
                      right: -w * 0.25,
                      bottom: -h * 0.23,
                      height: h * 0.46,
                      child: Container(
                        decoration: const BoxDecoration(color: Color(0xFF8FD3A7), borderRadius: BorderRadius.all(Radius.elliptical(400, 120))),
                      ),
                    ),
                    at(0.16, 0.62, WIconView(WIcon.tree, size: h * 0.20, color: const Color(0xFF4FA873))),
                    at(
                      0.52,
                      0.62,
                      Transform.translate(
                        offset: Offset(0, 3 - 6 * on),
                        child: WIconView(WIcon.family, size: h * 0.30, color: WColor.primaryStrong),
                      ),
                    ),
                    at(
                      0.84,
                      0.74,
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          WIconView(WIcon.carFill, size: h * 0.09, color: WColor.primary.withValues(alpha: 0.75)),
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Opacity(
                              opacity: 0.3 + 0.7 * on,
                              child: const WIconView(WIcon.sparkleFill, size: 10, color: _sun),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _photo(String tag, bool dull) => Container(
    height: 72,
    decoration: BoxDecoration(color: dull ? const Color(0xFFD9D4CC) : const Color(0xFFDCEBFF), borderRadius: BorderRadius.circular(12)),
    child: Stack(
      children: [
        Center(child: WIconView(WIcon.carFill, size: 30, color: dull ? const Color(0xFF8C8577) : WColor.primary)),
        if (!dull) const Positioned(right: 8, top: 8, child: WIconView(WIcon.sparkleFill, size: 12, color: _sun)),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: ShapeDecoration(color: WColor.white.withValues(alpha: 0.85), shape: const StadiumBorder()),
            child: WText(tag, WType.small, weight: semibold, size: 10, color: dull ? const Color(0xFF5E5A52) : WColor.primaryStrong),
          ),
        ),
      ],
    ),
  );
}
