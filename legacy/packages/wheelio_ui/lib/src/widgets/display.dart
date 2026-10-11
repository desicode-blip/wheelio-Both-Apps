import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Design: Logo/Lockup and Logo/Mark. The name comes from the brand token
/// so a rename touches one config value.
class WLogo extends StatelessWidget {
  const WLogo({super.key, required this.brandName, this.size = 34, this.onBrand = false});

  final String brandName;
  final double size;

  /// White text, used on the blue splash.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: brandName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: WColors.primary, borderRadius: BorderRadius.circular(size / 4)),
            child: CustomPaint(painter: _MarkPainter()),
          ),
          SizedBox(width: size * 0.3),
          Text(
            brandName,
            style: WText.display.copyWith(
              fontSize: size * 0.8,
              height: 1.1,
              letterSpacing: -0.3,
              color: onBrand ? WColors.white : WColors.heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The mark is drawn on a 24-unit grid at 78% of the tile (26 px in a 34 px tile).
    final c = size.center(Offset.zero);
    final scale = size.width / 24 * 0.78;
    final ring = Paint()
      ..color = WColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * scale;
    canvas.drawCircle(c, 7.5 * scale, ring);
    canvas.drawCircle(c, 2.6 * scale, Paint()..color = WColors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Design: Card (raised), Card/Outline and Card/Fill.
enum WCardStyle { raised, outline, fill }

class WCard extends StatelessWidget {
  const WCard({
    super.key,
    required this.child,
    this.style = WCardStyle.outline,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final WCardStyle style;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(WRadius.card);
    final decoration = switch (style) {
      WCardStyle.raised => BoxDecoration(
          color: color ?? WColors.white,
          borderRadius: radius,
          boxShadow: const [BoxShadow(color: WColors.shadowCard, blurRadius: 20, offset: Offset(0, 6))],
        ),
      WCardStyle.outline =>
        BoxDecoration(color: color ?? WColors.white, borderRadius: radius, border: Border.all(color: WColors.border)),
      WCardStyle.fill => BoxDecoration(color: color ?? WColors.canvas, borderRadius: radius),
    };
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Design: icon in a tinted rounded square ("tic").
class WIconTile extends StatelessWidget {
  const WIconTile({super.key, required this.icon, this.size = 48, this.tone = WTone.info});

  final IconData icon;
  final double size;
  final WTone tone;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(WRadius.tile)),
        child: Icon(icon, size: size * 0.52, color: tone.foreground),
      );
}

/// Design: Selection tile (vehicle type, problem type, payment method).
class WSelectionTile extends StatelessWidget {
  const WSelectionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
    this.trailingText,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(WRadius.card);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? WColors.primaryTint : WColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? const BorderSide(color: WColors.primary, width: 2)
              : const BorderSide(color: WColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (icon != null) ...[WIconTile(icon: icon!), const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: WText.valueStrong),
                      if (subtitle != null) Text(subtitle!, style: WText.caption),
                    ],
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: 8),
                  Text(trailingText!, style: WText.money(WText.valueStrong)),
                ],
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Design: Badge. Always icon + word, never colour alone.
class WBadge extends StatelessWidget {
  const WBadge({super.key, required this.label, this.tone = WTone.info, this.icon});

  final String label;
  final WTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? _defaultIcon(tone), size: 15, color: tone.foreground),
            const SizedBox(width: 6),
            Text(label, style: WText.label.copyWith(color: tone.foreground)),
          ],
        ),
      );
}

IconData _defaultIcon(WTone tone) => switch (tone) {
      WTone.info => Icons.info_outline_rounded,
      WTone.ok => Icons.check_circle_outline_rounded,
      WTone.wait => Icons.schedule_rounded,
      WTone.error => Icons.error_outline_rounded,
      WTone.mute => Icons.remove_circle_outline_rounded,
    };

/// Design: Banner (info, ok, wait, error).
class WBanner extends StatelessWidget {
  const WBanner({super.key, required this.text, this.tone = WTone.info, this.icon, this.title, this.action});

  final String text;
  final String? title;
  final WTone tone;
  final IconData? icon;

  /// Usually a small text button such as "Retry".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon(tone), size: 20, color: tone.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: WText.title.copyWith(fontSize: 15, color: tone.bannerText)),
                Text(text, style: WText.body.copyWith(fontSize: 14, height: 20 / 14, color: tone.bannerText)),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Small inline text action, used inside banners and rows.
class WLinkButton extends StatelessWidget {
  const WLinkButton({super.key, required this.label, required this.onTap, this.color = WColors.primaryStrong});

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: WText.bodyStrong.copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
}

/// Design: full-screen state (success, failure, empty, offline …).
class WStateView extends StatelessWidget {
  const WStateView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.tone = WTone.info,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String? body;
  final WTone tone;

  /// Extra content under the text (cards, banners).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: tone.foreground),
            ),
            const SizedBox(height: 20),
            Text(title, style: WText.screen, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 12),
              Text(body!, style: WText.body, textAlign: TextAlign.center),
            ],
            for (final c in children) ...[const SizedBox(height: 16), c],
          ],
        ),
      ),
    );
  }
}

/// Design: Title block (screen heading + subtitle).
class WTitleBlock extends StatelessWidget {
  const WTitleBlock({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: WText.screen)),
          if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: WText.body)],
        ],
      );
}

/// Design: Photo slot. Empty (dashed), filled (placeholder image or real
/// image), failed. Optional Before/After tag.
enum WPhotoState { empty, filled, failed, uploading }

enum WPhotoTag { before, after, yours }

class WPhotoSlot extends StatelessWidget {
  const WPhotoSlot({
    super.key,
    required this.label,
    this.state = WPhotoState.empty,
    this.tag,
    this.image,
    this.onTap,
    this.aspectRatio = 4 / 3,
    this.icon = Icons.photo_camera_outlined,
  });

  final String label;
  final WPhotoState state;
  final WPhotoTag? tag;
  final ImageProvider? image;
  final VoidCallback? onTap;
  final double aspectRatio;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(WRadius.field);
    Widget inner;
    BoxDecoration deco;
    switch (state) {
      case WPhotoState.empty:
        deco = BoxDecoration(color: WColors.white, borderRadius: radius, border: Border.all(color: WColors.dashed, width: 1.5));
        inner = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: WColors.primaryStrong),
            const SizedBox(height: 6),
            Text(label, style: WText.label.copyWith(color: WColors.primaryStrong), textAlign: TextAlign.center),
          ],
        );
      case WPhotoState.failed:
        deco = BoxDecoration(color: WColors.errorTint, borderRadius: radius, border: Border.all(color: WColors.destructive, width: 1.5));
        inner = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, color: WColors.destructive),
            const SizedBox(height: 6),
            Text('$label\nRetry upload', style: WText.label.copyWith(color: WColors.destructive), textAlign: TextAlign.center),
          ],
        );
      case WPhotoState.uploading:
      case WPhotoState.filled:
        deco = BoxDecoration(
          color: WColors.disabled,
          borderRadius: radius,
          image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
        );
        inner = Stack(
          children: [
            if (image == null)
              Center(child: Icon(Icons.directions_car_filled_outlined, size: 36, color: WColors.secondary.withValues(alpha: 0.6))),
            if (state == WPhotoState.uploading)
              const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
            Positioned(
              left: 8,
              bottom: 8,
              child: _Tag(text: switch (tag) {
                WPhotoTag.before => 'Before',
                WPhotoTag.after => 'After',
                WPhotoTag.yours => 'Yours',
                null => label,
              }, tag: tag),
            ),
          ],
        );
    }
    return Semantics(
      button: onTap != null,
      label: '$label photo, ${state.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(decoration: deco, clipBehavior: Clip.antiAlias, child: inner),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.tag});

  final String text;
  final WPhotoTag? tag;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tag) {
      WPhotoTag.after => (WColors.success, WColors.onSuccess),
      WPhotoTag.yours => (WColors.primary, WColors.white),
      _ => (WColors.inverse, WColors.white),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Text(text, style: WText.label.copyWith(fontSize: 11.5, color: fg)),
    );
  }
}

/// Design: List row.
class WListRow extends StatelessWidget {
  const WListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.showChevron,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  /// Defaults to true when [onTap] is set and there is no [trailing].
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final chevron = showChevron ?? (onTap != null && trailing == null);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: WText.rowTitle.copyWith(color: titleColor)),
                    if (subtitle != null) Text(subtitle!, style: WText.caption),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (chevron) const Icon(Icons.chevron_right_rounded, color: WColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows separated by dividers.
class WRowGroup extends StatelessWidget {
  const WRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: WColors.divider),
            children[i],
          ],
        ],
      );
}

/// Design: Key-value row (review and receipt).
class WKeyValue extends StatelessWidget {
  const WKeyValue({super.key, required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: WText.body),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: strong ? WText.money(WText.valueStrong) : WText.bodyStrong.copyWith(color: WColors.heading),
              ),
            ),
          ],
        ),
      );
}

/// Design: order status steps — Booked · Washer on the way · Washing · Check photos.
class WStatusSteps extends StatelessWidget {
  const WStatusSteps({super.key, required this.steps, required this.current});

  final List<String> steps;

  /// Index of the step in progress. Steps before it are done.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            label: '${steps[i]}, ${i < current ? 'done' : i == current ? 'now' : 'next'}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < current ? WColors.success : (i == current ? WColors.primary : WColors.white),
                      border: i > current ? Border.all(color: WColors.border, width: 2) : null,
                    ),
                    child: i < current
                        ? const Icon(Icons.check_rounded, size: 16, color: WColors.onSuccess)
                        : i == current
                            ? const Icon(Icons.circle, size: 8, color: WColors.white)
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    steps[i],
                    style: WText.bodyStrong.copyWith(
                      color: i <= current ? WColors.heading : WColors.secondary,
                      fontWeight: i == current ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Design: Avatar with initials.
class WAvatar extends StatelessWidget {
  const WAvatar({super.key, required this.initials, this.size = 48});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: WColors.primaryTint, shape: BoxShape.circle),
        child: Text(initials, style: WText.title.copyWith(color: WColors.primaryStrong, fontSize: size * 0.36, fontWeight: FontWeight.w700)),
      );
}

/// Design: Number plate.
class WPlate extends StatelessWidget {
  const WPlate({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: WColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: WColors.heading, width: 1.5),
        ),
        child: Text(number, style: WText.title.copyWith(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );
}

/// Design: map placeholder used until a maps key is connected.
class WMapPlaceholder extends StatelessWidget {
  const WMapPlaceholder({super.key, this.height = 260, this.showPin = true});

  final double height;
  final bool showPin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Map',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WRadius.card),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: WColors.map)),
              const Positioned(left: 0, right: 0, top: 110, height: 18, child: ColoredBox(color: WColors.white)),
              const Positioned(top: 0, bottom: 0, left: 150, width: 16, child: ColoredBox(color: WColors.white)),
              for (final r in const [
                Rect.fromLTWH(16, 16, 110, 80),
                Rect.fromLTWH(186, 20, 90, 70),
                Rect.fromLTWH(20, 146, 100, 90),
                Rect.fromLTWH(190, 150, 120, 80),
              ])
                Positioned.fromRect(
                  rect: r,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: WColors.mapBlock, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              if (showPin)
                const Center(child: Icon(Icons.location_on_rounded, size: 44, color: WColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton block.
class WSkeleton extends StatelessWidget {
  const WSkeleton({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: WColors.disabled, borderRadius: BorderRadius.circular(radius)),
      );
}
