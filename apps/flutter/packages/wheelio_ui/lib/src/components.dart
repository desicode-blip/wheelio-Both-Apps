// Wheelio components, ported from apps/ios/Shared/DesignSystem (Buttons, Inputs, Layout, Display).
// One primary action per screen. Green only to pay, approve or accept. Red only for errors and
// destructive actions. Colour is never the only signal: always pair a tone with an icon and a word.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fmt.dart';
import 'icons.dart';
import 'tokens.dart';

// MARK: - Text

/// Text scale for the 200% text screen (C52).
class TextScale extends InheritedWidget {
  const TextScale({super.key, required this.scale, required super.child});
  final double scale;
  static double of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<TextScale>()?.scale ?? 1;
  @override
  bool updateShouldNotify(TextScale old) => old.scale != scale;
}

class WText extends StatelessWidget {
  const WText(this.text, this.k, {super.key, this.color, this.weight, this.size, this.maxLines, this.align, this.mono = false, this.decoration, this.letterSpacing});
  final String text;
  final WType k;
  final Color? color;
  final FontWeight? weight;
  final double? size;
  final int? maxLines;
  final TextAlign? align;
  final bool mono;
  final TextDecoration? decoration;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        textAlign: align,
        style: wStyle(k, color: color, weight: weight, size: size, mono: mono, scale: TextScale.of(context))
            .copyWith(decoration: decoration, decorationColor: color ?? k.color, letterSpacing: letterSpacing),
      );
}

/// Mixed text with bold spans, e.g. rich(["₹149 is held safely. ", bold], [rest]).
class WRich extends StatelessWidget {
  const WRich(this.spans, this.k, {super.key, this.color, this.size, this.align});
  final List<(String, FontWeight?)> spans;
  final WType k;
  final Color? color;
  final double? size;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    final base = wStyle(k, color: color, size: size, scale: TextScale.of(context));
    return Text.rich(
      TextSpan(children: [for (final s in spans) TextSpan(text: s.$1, style: s.$2 == null ? base : base.copyWith(fontWeight: s.$2))]),
      textAlign: align,
    );
  }
}

const bold = FontWeight.w700;
const semibold = FontWeight.w600;
const medium = FontWeight.w500;

// MARK: - Tappable surfaces

/// Subtle press feedback for every tappable surface. Right-click on the web counts as a long-press.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.enabled = true, this.feedback = true, this.label});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool feedback;
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return Semantics(
      button: true,
      label: widget.label,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: active ? (_) => setState(() => _down = true) : null,
          onTapUp: active ? (_) => setState(() => _down = false) : null,
          onTapCancel: active ? () => setState(() => _down = false) : null,
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onSecondaryTap: widget.enabled ? widget.onLongPress : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _down && widget.feedback ? 0.82 : 1,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _down && widget.feedback ? 0.985 : 1,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Elevation/Card on canvas: white, radius 20.
BoxDecoration cardDecoration({double radius = WRadius.card, Color color = WColor.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: WColor.shadowCard, blurRadius: 10, offset: Offset(0, 4))],
    );

/// Outlined card (border/default).
BoxDecoration outlinedDecoration({double radius = WRadius.card, Color fill = WColor.white, Color stroke = WColor.border, double width = 1}) =>
    BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius), border: Border.all(color: stroke, width: width));

class WCard extends StatelessWidget {
  const WCard({super.key, required this.child, this.padding = 16, this.radius = WRadius.card, this.onTap, this.outlined = false});
  final Widget child;
  final double padding;
  final double radius;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: outlined ? outlinedDecoration(radius: radius) : cardDecoration(radius: radius),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

// MARK: - Buttons

enum ButtonKind { primary, success, outline, text, danger, tonal }

enum ButtonSize {
  regular(52, 16.5),
  captain(64, 19),
  accept(72, 22);

  const ButtonSize(this.height, this.font);
  final double height;
  final double font;
}

class WButton extends StatelessWidget {
  const WButton(this.title, {super.key, this.icon, this.kind = ButtonKind.primary, this.size = ButtonSize.regular, this.enabled = true, this.loading = false, this.fullWidth = true, this.onTap});
  final String title;
  final WIcon? icon;
  final ButtonKind kind;
  final ButtonSize size;
  final bool enabled;
  final bool loading;
  final bool fullWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? (kind == ButtonKind.text ? Colors.transparent : WColor.disabled)
        : switch (kind) {
            ButtonKind.primary => WColor.primary,
            ButtonKind.success => WColor.success,
            ButtonKind.outline => WColor.white,
            ButtonKind.text => Colors.transparent,
            ButtonKind.danger => WColor.destructive,
            ButtonKind.tonal => WColor.primaryTint,
          };
    final fg = !enabled
        ? WColor.placeholder
        : switch (kind) {
            ButtonKind.primary || ButtonKind.danger => WColor.white,
            ButtonKind.success => WColor.onSuccess,
            _ => WColor.primaryStrong,
          };
    final content = loading
        ? WSpinner(color: fg, size: 20)
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[WIconView(icon!, size: size.font + 1, color: fg, weight: medium), const SizedBox(width: 8)],
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: wStyle(WType.action, color: fg, size: size.font))),
          ]);
    return Pressable(
      enabled: enabled,
      label: title,
      onTap: loading ? null : onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        constraints: BoxConstraints(minHeight: kind == ButtonKind.text ? 48 : size.height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(side: kind == ButtonKind.outline ? BorderSide(color: enabled ? WColor.primary : WColor.border, width: 1.5) : BorderSide.none),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

/// Icon button: elevated (Elevation/Subtle), flat, or tinted.
enum IconButtonStyle { elevated, flat, tint }

class WIconButton extends StatelessWidget {
  const WIconButton(this.icon, {super.key, this.style = IconButtonStyle.elevated, this.size = 48, this.label, this.onTap});
  final WIcon icon;
  final IconButtonStyle style;
  final double size;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: label ?? icon.name,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: style == IconButtonStyle.elevated ? WColor.white : style == IconButtonStyle.tint ? WColor.primaryTint : Colors.transparent,
            boxShadow: style == IconButtonStyle.elevated ? const [BoxShadow(color: WColor.shadow, blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          alignment: Alignment.center,
          child: WIconView(icon, size: size * 0.42, color: style == IconButtonStyle.tint ? WColor.primaryStrong : WColor.heading),
        ),
      );
}

/// Underlined inline link, e.g. "Change", "Retry", "See tomorrow".
class WLink extends StatelessWidget {
  const WLink(this.title, {super.key, this.color = WColor.primaryStrong, this.k = WType.body, this.onTap, this.minHeight = 44});
  final String title;
  final Color color;
  final WType k;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: title,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Align(widthFactor: 1, child: WText(title, k, color: color, weight: medium, maxLines: 2, decoration: TextDecoration.underline)),
        ),
      );
}

class WSpinner extends StatelessWidget {
  const WSpinner({super.key, this.color = WColor.primary, this.size = 22});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CircularProgressIndicator(strokeWidth: 2.5, color: color));
}

// MARK: - App bar

/// App bar: back (or close) on the left, title in the middle, help on the right.
class WAppBar extends StatelessWidget {
  const WAppBar({super.key, this.title = '', this.subtitle, this.leading = WIcon.left, this.trailing = WIcon.help, this.dark = false, this.onLeading, this.onTrailing, this.padding = const EdgeInsets.symmetric(horizontal: 14)});
  final String title;
  final String? subtitle;
  final WIcon? leading;
  final WIcon? trailing;
  final bool dark;
  final VoidCallback? onLeading;
  final VoidCallback? onTrailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? WColor.white : WColor.heading;
    Widget slot(WIcon? icon, VoidCallback? onTap, double size, String label) => icon == null
        ? const SizedBox(width: 48, height: 48)
        : Pressable(onTap: onTap, label: label, child: SizedBox(width: 48, height: 48, child: Center(child: WIconView(icon, size: size, color: fg, weight: medium))));
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(children: [
          slot(leading, onLeading, leading == WIcon.close ? 21 : 19, leading == WIcon.close ? 'Close' : 'Go back'),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (title.isNotEmpty) WText(title, WType.appBarTitle, color: fg, maxLines: 1, align: TextAlign.center),
              if (subtitle != null) WText(subtitle!, WType.caption, color: dark ? Colors.white70 : WColor.secondary, maxLines: 1, align: TextAlign.center),
            ]),
          ),
          slot(trailing, onTrailing, 22, trailing == WIcon.help ? 'Get help' : trailing?.name ?? ''),
        ]),
      ),
    );
  }
}

// MARK: - Progress

/// Progress: thin track plus "Step 1 of 5 · Vehicle".
class WProgress extends StatelessWidget {
  const WProgress({super.key, required this.fraction, this.label, this.done = false});
  final double fraction;
  final String? label;
  final bool done;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 4,
            child: Stack(children: [
              Container(color: WColor.track),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                widthFactor: fraction.clamp(0, 1),
                child: Container(decoration: BoxDecoration(color: done ? WColor.success : WColor.primary, borderRadius: BorderRadius.circular(4))),
              ),
            ]),
          ),
        ),
        if (label != null) ...[const SizedBox(height: 6), WText(label!, WType.label, color: WColor.primaryStrong)],
      ]);
}

/// Segmented step bar used by the captain app.
class WSegmentBar extends StatelessWidget {
  const WSegmentBar({super.key, required this.filled, required this.total, this.labels = const [], this.greenUpTo = 0});
  final int filled;
  final int total;
  final List<String> labels;
  final int greenUpTo;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: Container(height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: i < greenUpTo ? WColor.success : i < filled ? WColor.primary : WColor.track))),
          ],
        ]),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: WText(labels[i], WType.caption, color: i < filled ? WColor.heading : WColor.secondary, weight: i < filled ? medium : FontWeight.w400)),
            ],
          ]),
        ],
      ]);
}

// MARK: - Footer bar

/// Footer bar: call/help on the left, the screen's one primary action on the right.
class WFooterBar extends StatelessWidget {
  const WFooterBar({super.key, this.showCall = true, this.captain = false, this.onCall, required this.child});
  final bool showCall;
  final bool captain;
  final VoidCallback? onCall;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: WColor.white, border: Border(top: BorderSide(color: WColor.divider))),
        padding: EdgeInsets.fromLTRB(captain ? WSpace.gutterCaptain : WSpace.gutter, 12, captain ? WSpace.gutterCaptain : WSpace.gutter, 12),
        child: Row(children: [
          if (showCall) ...[
            WIconButton(WIcon.phone, style: captain ? IconButtonStyle.tint : IconButtonStyle.elevated, size: captain ? 64 : 48, label: 'Call support', onTap: onCall),
            const SizedBox(width: 12),
          ],
          Expanded(child: child),
        ]),
      );
}

/// Footer with a primary action and a text action stacked.
class WStackedFooter extends StatelessWidget {
  const WStackedFooter({super.key, this.captain = false, required this.children});
  final bool captain;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: WColor.white, border: Border(top: BorderSide(color: WColor.divider))),
        padding: EdgeInsets.fromLTRB(captain ? WSpace.gutterCaptain : WSpace.gutter, 12, captain ? WSpace.gutterCaptain : WSpace.gutter, 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 4), children[i]]]),
      );
}

// MARK: - Screen scaffold

/// A screen: optional app bar, scrolling content, footer pinned to the bottom. Handles the safe areas.
class WScreen extends StatelessWidget {
  const WScreen({super.key, this.canvas = false, this.gutter = WSpace.gutter, this.scrolls = true, this.header, this.footer, required this.children, this.background});
  final bool canvas;
  final double gutter;
  final bool scrolls;
  final Widget? header;
  final Widget? footer;
  final List<Widget> children;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final bg = background ?? (canvas ? WColor.canvas : WColor.white);
    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: scrolls ? MainAxisSize.min : MainAxisSize.max, children: children);
    return Material(
      color: bg,
      child: Column(children: [
        SizedBox(height: pad.top),
        if (header != null) header!,
        Expanded(
          child: scrolls
              ? SingleChildScrollView(padding: EdgeInsets.fromLTRB(gutter, 0, gutter, footer == null ? 24 + pad.bottom : 24), child: column)
              : Padding(padding: EdgeInsets.fromLTRB(gutter, 0, gutter, footer == null ? pad.bottom : 0), child: column),
        ),
        if (footer != null) ColoredBox(color: WColor.white, child: Padding(padding: EdgeInsets.only(bottom: pad.bottom), child: footer)),
      ]),
    );
  }
}

/// Title block: Heading/Screen plus optional subtitle.
class WTitleBlock extends StatelessWidget {
  const WTitleBlock(this.title, {super.key, this.subtitle, this.top = 20});
  final String title;
  final String? subtitle;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WText(title, WType.screen),
          if (subtitle != null && subtitle!.isNotEmpty) ...[const SizedBox(height: 6), WText(subtitle!, WType.body)],
        ]),
      );
}

class WSectionLabel extends StatelessWidget {
  const WSectionLabel(this.text, {super.key, this.top = 0});
  final String text;
  final double top;
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(top: top, bottom: 8), child: WText(text, WType.label));
}

/// Vertical gap.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

// MARK: - Bottom navigation

class NavItem {
  const NavItem(this.id, this.title, this.icon, {this.badge = 0});
  final int id;
  final String title;
  final WIcon icon;
  final int badge;
}

class WBottomNav extends StatelessWidget {
  const WBottomNav({super.key, required this.items, required this.selection, required this.onSelect});
  final List<NavItem> items;
  final int selection;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: WColor.white, border: Border(top: BorderSide(color: WColor.divider))),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          for (final it in items)
            Expanded(
              child: Pressable(
                feedback: false,
                label: it.title,
                onTap: () => onSelect(it.id),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Column(children: [
                    Stack(clipBehavior: Clip.none, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(color: selection == it.id ? WColor.primaryTint : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                        alignment: Alignment.center,
                        child: WIconView(it.icon, size: 19, color: selection == it.id ? WColor.primaryStrong : WColor.secondary, weight: selection == it.id ? semibold : FontWeight.w400),
                      ),
                      if (it.badge > 0)
                        Positioned(
                          top: -3,
                          right: 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(color: WColor.destructive, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('${it.badge}', style: wStyle(WType.small, color: WColor.white, weight: bold, size: 10)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    WText(it.title, WType.label, color: selection == it.id ? WColor.heading : WColor.secondary, weight: selection == it.id ? semibold : FontWeight.w400),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

// MARK: - Sheets, alerts, menus

/// Present a Wheelio bottom sheet sized to a height (detent), with a grab handle.
Future<T?> showWSheet<T>(BuildContext context, {required double height, required WidgetBuilder builder, double gutter = WSpace.gutter}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: false,
    backgroundColor: WColor.white,
    barrierColor: WColor.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WRadius.sheet))),
    clipBehavior: Clip.antiAlias,
    builder: (c) => SizedBox(
      height: height + MediaQuery.paddingOf(c).bottom,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8 + MediaQuery.paddingOf(c).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14), decoration: BoxDecoration(color: WColor.grab, borderRadius: BorderRadius.circular(2)))),
          Expanded(child: builder(c)),
        ]),
      ),
    ),
  );
}

class AlertAction {
  const AlertAction(this.title, {this.cancel = false, this.destructive = false, this.onTap});
  final String title;
  final bool cancel;
  final bool destructive;
  final VoidCallback? onTap;
}

/// iOS-style alert (SwiftUI .alert).
Future<void> showWAlert(BuildContext context, {required String title, String? message, List<AlertAction> actions = const [AlertAction('OK', cancel: true)], Widget? field}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (c) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null && field == null ? null : Column(mainAxisSize: MainAxisSize.min, children: [if (message != null) Text(message), if (field != null) ...[const SizedBox(height: 12), field]]),
      actions: [
        for (final a in actions)
          CupertinoDialogAction(
            isDefaultAction: a.cancel,
            isDestructiveAction: a.destructive,
            onPressed: () {
              Navigator.of(c).pop();
              a.onTap?.call();
            },
            child: Text(a.title),
          ),
      ],
    ),
  );
}

/// iOS-style action sheet (confirmationDialog and context menus).
Future<void> showWActions(BuildContext context, {String? title, String? message, required List<AlertAction> actions, String cancel = 'Cancel'}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (c) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final a in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: a.destructive,
            onPressed: () {
              Navigator.of(c).pop();
              a.onTap?.call();
            },
            child: Text(a.title),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(isDefaultAction: true, onPressed: () => Navigator.of(c).pop(), child: Text(cancel)),
    ),
  );
}

// MARK: - Display

/// Rounded square holding an icon (tinted), used in tiles and rows.
class WIconBox extends StatelessWidget {
  const WIconBox(this.icon, {super.key, this.size = 44, this.tone = Tone.info, this.radius = 12, this.iconSize});
  final WIcon icon;
  final double size;
  final Tone tone;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(radius)),
        alignment: Alignment.center,
        child: WIconView(icon, size: iconSize ?? size * 0.45, color: tone.foreground),
      );
}

/// Large state circle with an icon, used by full-screen states.
class WStateCircle extends StatelessWidget {
  const WStateCircle(this.icon, {super.key, this.tone = Tone.info, this.size = 96, this.spinning = false});
  final WIcon icon;
  final Tone tone;
  final double size;
  final bool spinning;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: spinning ? WSpinner(size: size * 0.34) : WIconView(icon, size: size * 0.36, color: tone == Tone.ok ? WColor.onSuccess : tone.foreground, weight: medium),
      );
}

/// Badge: icon + word on a tint.
class WBadge extends StatelessWidget {
  const WBadge(this.text, {super.key, this.tone = Tone.info, this.icon, this.solid = false});
  final String text;
  final Tone tone;
  final WIcon? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? WColor.white : tone.foreground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(color: solid ? tone.foreground : tone.background, shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[WIconView(icon!, size: 11, color: fg, weight: semibold), const SizedBox(width: 5)],
        Flexible(child: WText(text, WType.label, color: fg, weight: semibold, maxLines: 1)),
      ]),
    );
  }
}

/// Inline banner: tinted panel with icon, text and an optional link action.
class WBanner extends StatelessWidget {
  const WBanner({super.key, this.tone = Tone.info, this.icon = WIcon.info, this.title, required this.text, this.actionTitle, this.onAction});
  final Tone tone;
  final WIcon icon;
  final String? title;
  final String text;
  final String? actionTitle;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: WIconView(icon, size: 17, color: tone == Tone.info ? WColor.heading : tone.bannerText)),
          const SizedBox(width: 12),
          Expanded(child: WRich([if (title != null) ('$title ', semibold), (text, null)], WType.caption, color: tone.bannerText, size: 14)),
          if (actionTitle != null) ...[const SizedBox(width: 8), WLink(actionTitle!, k: WType.caption, onTap: onAction, minHeight: 20)],
        ]),
      );
}

/// Centered state: circle, title, body, primary and text actions.
class WFullState extends StatelessWidget {
  const WFullState({super.key, required this.icon, this.tone = Tone.info, required this.title, this.message = '', this.spinning = false, this.primary, this.primaryIcon, this.primaryKind = ButtonKind.primary, this.secondary, this.captain = false, this.onPrimary, this.onSecondary});
  final WIcon icon;
  final Tone tone;
  final String title;
  final String message;
  final bool spinning;
  final String? primary;
  final WIcon? primaryIcon;
  final ButtonKind primaryKind;
  final String? secondary;
  final bool captain;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: captain ? WSpace.gutterCaptain : 0),
        child: Column(children: [
          const Spacer(),
          WStateCircle(icon, tone: tone, size: captain ? 112 : 96, spinning: spinning),
          const SizedBox(height: 22),
          WText(title, WType.section, weight: semibold, size: captain ? 23 : 21, align: TextAlign.center),
          const SizedBox(height: 10),
          if (message.isNotEmpty) ...[WText(message, WType.body, size: captain ? 16.5 : 15, align: TextAlign.center), const SizedBox(height: 24)],
          if (primary != null) WButton(primary!, icon: primaryIcon, kind: primaryKind, size: captain ? ButtonSize.captain : ButtonSize.regular, onTap: onPrimary),
          if (secondary != null) ...[const SizedBox(height: 6), WButton(secondary!, kind: ButtonKind.text, onTap: onSecondary)],
          const Spacer(flex: 2),
        ]),
      );
}

/// Selection tile: icon box, title, subtitle, trailing value.
class WSelectionTile extends StatelessWidget {
  const WSelectionTile({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.selected = false, this.radio = false, this.iconTone = Tone.info, this.onTap});
  final WIcon icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final bool radio;
  final Tone iconTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: outlinedDecoration(radius: 16, fill: selected ? WColor.primaryTint : WColor.white, stroke: selected ? WColor.primary : WColor.border, width: selected ? 2 : 1),
          child: Row(children: [
            WIconBox(icon, size: 48, tone: iconTone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WText(title, WType.title),
                if (subtitle != null) ...[const SizedBox(height: 1), WText(subtitle!, WType.caption)],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), WText(trailing!, WType.valueStrong, mono: true)],
            if (radio) ...[const SizedBox(width: 8), WRadio(on: selected)],
          ]),
        ),
      );
}

class WRadio extends StatelessWidget {
  const WRadio({super.key, required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? WColor.primary : WColor.muted, width: 2)),
        alignment: Alignment.center,
        child: on ? Container(width: 12, height: 12, decoration: const BoxDecoration(color: WColor.primary, shape: BoxShape.circle)) : null,
      );
}

class WChip extends StatelessWidget {
  const WChip(this.title, {super.key, this.selected = false, this.icon, this.enabled = true, this.strike = false, this.height = 46, this.fill = false, this.onTap});
  final String title;
  final bool selected;
  final WIcon? icon;
  final bool enabled;
  final bool strike;
  final double height;
  final bool fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        enabled: enabled,
        onTap: onTap,
        child: Container(
          width: fill ? double.infinity : null,
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: outlinedDecoration(radius: WRadius.chip, fill: selected ? WColor.primaryTint : enabled ? WColor.white : WColor.canvas, stroke: selected ? WColor.primary : WColor.border, width: selected ? 2 : 1),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (selected) ...[const WIconView(WIcon.check, size: 13, color: WColor.primaryStrong, weight: semibold), const SizedBox(width: 6)] else if (icon != null) ...[WIconView(icon!, size: 14), const SizedBox(width: 6)],
            Flexible(
              child: WText(title, WType.bodyStrong,
                  size: 15.5,
                  maxLines: 1,
                  color: enabled ? (selected ? WColor.primaryStrong : WColor.heading) : WColor.muted,
                  weight: selected ? semibold : FontWeight.w400,
                  decoration: strike ? TextDecoration.lineThrough : null),
            ),
          ]),
        ),
      );
}

/// Wrapping layout for chips.
class WFlow extends StatelessWidget {
  const WFlow({super.key, this.spacing = 10, required this.children});
  final double spacing;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(spacing: spacing, runSpacing: spacing, children: children);
}

class WSegmented extends StatelessWidget {
  const WSegmented({super.key, required this.options, required this.selection, required this.onChanged, this.height = 46});
  final List<String> options;
  final int selection;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: ShapeDecoration(color: WColor.disabled, shape: const StadiumBorder()),
        child: Row(children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Pressable(
                feedback: false,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: height - 8,
                  decoration: ShapeDecoration(
                    color: selection == i ? WColor.white : Colors.transparent,
                    shape: const StadiumBorder(),
                    shadows: selection == i ? const [BoxShadow(color: WColor.shadow, blurRadius: 4, offset: Offset(0, 1))] : null,
                  ),
                  alignment: Alignment.center,
                  child: WText(options[i], WType.bodyStrong, color: selection == i ? WColor.heading : WColor.secondary, weight: selection == i ? semibold : medium, maxLines: 1),
                ),
              ),
            ),
        ]),
      );
}

/// Underline tabs (Bookings: Upcoming / Past).
class WTabs extends StatelessWidget {
  const WTabs({super.key, required this.options, required this.selection, required this.onChanged});
  final List<String> options;
  final int selection;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WColor.divider))),
        child: Row(children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Pressable(
                feedback: false,
                onTap: () => onChanged(i),
                child: Column(children: [
                  WText(options[i], WType.title, color: selection == i ? WColor.primaryStrong : WColor.secondary, weight: selection == i ? semibold : medium),
                  const SizedBox(height: 10),
                  Container(width: 68, height: 3, decoration: BoxDecoration(color: selection == i ? WColor.primary : Colors.transparent, borderRadius: BorderRadius.circular(2))),
                ]),
              ),
            ),
        ]),
      );
}

/// Number plate tag (outlined, spaced letters).
class WPlate extends StatelessWidget {
  const WPlate(this.text, {super.key, this.large = false});
  final String text;
  final bool large;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 8 : 5),
        decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: WColor.heading, width: 1.5)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: wStyle(WType.title, weight: bold, size: large ? 22 : 14.5).copyWith(letterSpacing: large ? 2 : 1.3, height: 1.2)),
      );
}

class WAvatar extends StatelessWidget {
  const WAvatar(this.initials, {super.key, this.size = 48, this.photo});
  final String initials;
  final double size;
  final Uint8List? photo;
  @override
  Widget build(BuildContext context) => photo != null
      ? ClipOval(child: Image.memory(photo!, width: size, height: size, fit: BoxFit.cover))
      : Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(initials, style: wStyle(WType.title, weight: bold, size: size * 0.36, color: WColor.primaryStrong)),
        );
}

/// List row: icon box, title, subtitle, chevron.
class WListRow extends StatelessWidget {
  const WListRow({super.key, required this.icon, required this.title, this.subtitle, this.tone = Tone.info, this.trailing, this.chevron = true, this.iconSize = 40, this.onTap});
  final WIcon icon;
  final String title;
  final String? subtitle;
  final Tone tone;
  final String? trailing;
  final bool chevron;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        feedback: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            WIconBox(icon, size: iconSize, tone: tone, radius: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WText(title, WType.rowTitle),
                if (subtitle != null) ...[const SizedBox(height: 1), WText(subtitle!, WType.caption)],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), WText(trailing!, WType.caption)],
            if (chevron) ...[const SizedBox(width: 6), const WIconView(WIcon.chevron, size: 13, color: WColor.secondary, weight: medium)],
          ]),
        ),
      );
}

class WDivider extends StatelessWidget {
  const WDivider({super.key, this.inset = 0});
  final double inset;
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(left: inset), child: Container(height: 1, color: WColor.divider));
}

/// Key / value rows in an outlined card (Check and pay, booking detail).
class WKeyValueCard extends StatelessWidget {
  const WKeyValueCard({super.key, required this.rows, this.boldLast = false});
  final List<(String, String)> rows;
  final bool boldLast;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: outlinedDecoration(radius: 16),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WText(rows[i].$1, WType.body, color: WColor.secondary),
                const SizedBox(width: 12),
                Expanded(child: WText(rows[i].$2, boldLast && i == rows.length - 1 ? WType.valueStrong : WType.bodyStrong, color: WColor.heading, align: TextAlign.right, mono: true)),
              ]),
            ),
            if (i < rows.length - 1) const WDivider(),
          ],
        ]),
      );
}

/// Vertical status steps (Booked → Captain on the way → Washing → Check photos).
class WStatusSteps extends StatelessWidget {
  const WStatusSteps({super.key, required this.steps, required this.current, this.spacing = 26});
  final List<(String, String?)> steps;
  final int current;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                _dot(i),
                if (i < steps.length - 1) Expanded(child: Container(width: 2, constraints: BoxConstraints(minHeight: spacing - 4), color: i < current ? WColor.success : WColor.border)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 1, bottom: i < steps.length - 1 ? 4 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    WText(steps[i].$1, WType.rowTitle, color: i == current ? WColor.primaryStrong : i < current ? WColor.heading : WColor.secondary, weight: i <= current ? semibold : FontWeight.w400),
                    if (steps[i].$2 != null) ...[const SizedBox(height: 2), WText(steps[i].$2!, WType.caption)],
                  ]),
                ),
              ),
            ]),
          ),
      ]);

  Widget _dot(int i) {
    if (i < current) {
      return Container(width: 24, height: 24, decoration: const BoxDecoration(color: WColor.success, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.check, size: 11, color: WColor.onSuccess, weight: bold));
    }
    if (i == current) {
      return Container(width: 24, height: 24, decoration: const BoxDecoration(color: WColor.primary, shape: BoxShape.circle), alignment: Alignment.center, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)));
    }
    return Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.border, width: 2)));
  }
}

/// Dashed rounded border (empty photo slots, "Add a vehicle").
class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, this.radius = 12, this.color = WColor.dashed});
  final Widget child;
  final double radius;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _DashPainter(radius, color), child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.radius, this.color);
  final double radius;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

enum PhotoState { empty, uploading, done, failed }

/// Photo slot: dashed empty slot with camera, or a placeholder photo with state.
class WPhotoSlot extends StatelessWidget {
  const WPhotoSlot({super.key, required this.label, this.state = PhotoState.empty, this.tag, this.tagTone = Tone.mute, this.height = 126, this.showLabelBelow = false, this.icon = WIcon.car, this.onTap});
  final String label;
  final PhotoState state;
  final String? tag;
  final Tone tagTone;
  final double height;
  final bool showLabelBelow;
  final WIcon icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget inner;
    switch (state) {
      case PhotoState.empty:
        inner = DashedBorder(
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const WIconView(WIcon.camera, size: 20, color: WColor.primaryStrong), if (!showLabelBelow) ...[const SizedBox(height: 6), WText(label, WType.label, color: WColor.primaryStrong)]])),
        );
      case PhotoState.failed:
        inner = Container(
          decoration: BoxDecoration(color: WColor.errorTint, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [WIconView(WIcon.refresh, size: 18, color: WColor.destructive, weight: medium), SizedBox(height: 6), WText('Retry upload', WType.label, color: WColor.destructive)])),
        );
      default:
        inner = Container(
          decoration: BoxDecoration(color: WColor.photo, borderRadius: BorderRadius.circular(12)),
          child: Stack(children: [
            Center(child: WIconView(icon, size: 20, color: WColor.secondary)),
            if (state == PhotoState.uploading) const Positioned(left: 8, right: 8, bottom: 8, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 4, color: WColor.primary, backgroundColor: WColor.track))),
            if (state == PhotoState.done)
              Positioned(top: 8, right: 8, child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: WColor.success, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.check, size: 11, color: WColor.onSuccess, weight: bold))),
            if (tag != null) Positioned(left: 8, bottom: 8, child: PhotoTag(tag!, tagTone)),
          ]),
        );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Pressable(onTap: onTap, child: SizedBox(height: height, width: double.infinity, child: inner)),
      if (showLabelBelow || state != PhotoState.empty) ...[const SizedBox(height: 6), WText(label, WType.label, color: WColor.heading, weight: medium)],
    ]);
  }
}

class PhotoTag extends StatelessWidget {
  const PhotoTag(this.tag, this.tone, {super.key});
  final String tag;
  final Tone tone;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: ShapeDecoration(color: tone == Tone.ok ? WColor.success : WColor.inverse, shape: const StadiumBorder()),
        child: WText(tag, WType.small, color: tone == Tone.ok ? WColor.onSuccess : WColor.white, weight: semibold),
      );
}

/// Grey placeholder used where a real photo will be (mock mode).
class WPhotoPlaceholder extends StatelessWidget {
  const WPhotoPlaceholder({super.key, this.icon = WIcon.car, this.tag, this.tagTone = Tone.mute, this.radius = 10, required this.height, this.caption});
  final WIcon icon;
  final String? tag;
  final Tone tagTone;
  final double radius;
  final double height;
  final String? caption;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: WColor.photo, borderRadius: BorderRadius.circular(radius)),
        child: Stack(children: [
          Center(child: WIconView(icon, size: 18, color: WColor.secondary)),
          if (tag != null) Positioned(left: 6, bottom: 6, child: PhotoTag(tag!, tagTone)),
          if (caption != null) Positioned(left: 0, right: 0, bottom: 14, child: WText(caption!, WType.small, align: TextAlign.center)),
        ]),
      );
}

// MARK: - Inputs

/// Outlined field with the label sitting on the border, helper and error text.
class WTextField extends StatefulWidget {
  const WTextField({super.key, required this.label, required this.value, required this.onChanged, this.placeholder = '', this.helper, this.error, this.leadingIcon, this.keyboard = TextInputType.text, this.caps = TextCapitalization.none, this.large = false, this.autofocus = false, this.focusTrigger = 0, this.onSubmit, this.action = TextInputAction.done, this.formatters});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final String? helper;
  final String? error;
  final WIcon? leadingIcon;
  final TextInputType keyboard;
  final TextCapitalization caps;
  final bool large;
  final bool autofocus;

  /// Change to move the cursor here (e.g. after the field above is done).
  final int focusTrigger;
  final VoidCallback? onSubmit;
  final TextInputAction action;
  final List<TextInputFormatter>? formatters;

  @override
  State<WTextField> createState() => _WTextFieldState();
}

class _WTextFieldState extends State<WTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    if (widget.autofocus) Timer(const Duration(milliseconds: 350), () { if (mounted) _focus.requestFocus(); });
  }

  @override
  void didUpdateWidget(WTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.value = TextEditingValue(text: widget.value, selection: TextSelection.collapsed(offset: widget.value.length));
    if (widget.focusTrigger != old.focusTrigger) _focus.requestFocus();
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final err = widget.error;
    final border = err != null ? WColor.destructive : focused ? WColor.primary : WColor.border;
    final style = wStyle(WType.value, size: widget.large ? 24 : 17).copyWith(letterSpacing: widget.large ? 1.5 : 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          height: widget.large ? 62 : 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(WRadius.field), border: Border.all(color: border, width: focused || err != null ? 2 : 1)),
          child: Row(children: [
            if (widget.leadingIcon != null) ...[WIconView(widget.leadingIcon!, size: 16, color: WColor.secondary), const SizedBox(width: 10)],
            Expanded(
              child: TextField(
                controller: _c,
                focusNode: _focus,
                style: style,
                keyboardType: widget.keyboard,
                textCapitalization: widget.caps,
                textInputAction: widget.action,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: widget.formatters,
                cursorColor: WColor.primary,
                onChanged: (v) {
                  final out = widget.caps == TextCapitalization.characters ? v.toUpperCase() : v;
                  if (out != v) _c.value = _c.value.copyWith(text: out);
                  widget.onChanged(out);
                },
                onSubmitted: (_) => widget.onSubmit?.call(),
                decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: widget.placeholder.isEmpty ? widget.label : widget.placeholder, hintStyle: style.copyWith(color: WColor.placeholder)),
              ),
            ),
          ]),
        ),
        if (widget.label.isNotEmpty && (focused || widget.value.isNotEmpty || err != null))
          Positioned(
            left: 12,
            top: -8,
            child: Container(color: WColor.white, padding: const EdgeInsets.symmetric(horizontal: 4), child: WText(widget.label, WType.label, color: err != null ? WColor.destructive : focused ? WColor.primaryStrong : WColor.secondary)),
          ),
      ]),
      if (err != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const WIconView(WIcon.warning, size: 12, color: WColor.destructive), const SizedBox(width: 6), Expanded(child: WText(err, WType.caption, color: WColor.destructive))]))
      else if (widget.helper != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: WText(widget.helper!, WType.caption)),
    ]);
  }
}

/// Multi-line note box.
class WTextArea extends StatefulWidget {
  const WTextArea({super.key, required this.value, required this.onChanged, this.placeholder = '', this.height = 112});
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final double height;
  @override
  State<WTextArea> createState() => _WTextAreaState();
}

class _WTextAreaState extends State<WTextArea> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = wStyle(WType.value, size: 16);
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _focus.hasFocus ? WColor.primary : WColor.border, width: _focus.hasFocus ? 2 : 1)),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        maxLines: null,
        expands: true,
        style: style,
        cursorColor: WColor.primary,
        onChanged: widget.onChanged,
        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: widget.placeholder, hintStyle: style.copyWith(color: WColor.placeholder), hintMaxLines: 3),
      ),
    );
  }
}

/// OTP boxes backed by one hidden text field.
class WOtpField extends StatefulWidget {
  const WOtpField({super.key, required this.code, required this.onChanged, this.length = 6, this.error = false, this.boxSize = 48, this.autofocus = true});
  final String code;
  final ValueChanged<String> onChanged;
  final int length;
  final bool error;
  final double boxSize;
  final bool autofocus;
  @override
  State<WOtpField> createState() => _WOtpFieldState();
}

class _WOtpFieldState extends State<WOtpField> {
  late final TextEditingController _c = TextEditingController(text: widget.code);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    if (widget.autofocus) Timer(const Duration(milliseconds: 350), () { if (mounted) _focus.requestFocus(); });
  }

  @override
  void didUpdateWidget(WOtpField old) {
    super.didUpdateWidget(old);
    if (widget.code != _c.text) _c.value = TextEditingValue(text: widget.code, selection: TextSelection.collapsed(offset: widget.code.length));
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(children: [
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0.01,
            child: TextField(
              controller: _c,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
              onChanged: widget.onChanged,
              showCursor: false,
            ),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Builder(builder: (_) {
              final ch = i < code.length ? code[i] : '';
              final cursor = _focus.hasFocus && i == (code.length < widget.length ? code.length : widget.length - 1) && !widget.error;
              return Container(
                width: widget.boxSize,
                height: widget.boxSize * 1.15,
                decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.error ? WColor.destructive : cursor ? WColor.primary : WColor.border, width: widget.error || cursor ? 2 : 1)),
                alignment: Alignment.center,
                child: Text(ch, style: wStyle(WType.section, weight: medium, size: widget.boxSize * 0.46)),
              );
            }),
          ],
        ]),
      ]),
    );
  }
}

/// Phone field: "+91" box and the number field.
class WPhoneField extends StatelessWidget {
  const WPhoneField({super.key, required this.number, required this.onChanged, this.error, this.large = false, this.autofocus = true, this.focusTrigger = 0});
  final String number;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool large;
  final bool autofocus;
  final int focusTrigger;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: large ? 72 : 82,
          height: large ? 62 : 52,
          decoration: outlinedDecoration(radius: WRadius.field),
          alignment: Alignment.center,
          child: Text('+91', style: wStyle(WType.value, size: large ? 19 : 17)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: WTextField(
            label: large ? '' : 'Mobile number',
            value: number,
            placeholder: '9876543210',
            error: error,
            keyboard: TextInputType.phone,
            large: large,
            autofocus: autofocus,
            focusTrigger: focusTrigger,
            // Digits only, no spaces; anything after the first 10 digits is ignored.
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            onChanged: onChanged,
          ),
        ),
      ]);
}

/// iOS switch.
class WToggle extends StatelessWidget {
  const WToggle({super.key, required this.on, required this.onChanged, this.enabled = true, this.tint = WColor.primary});
  final bool on;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Color tint;
  @override
  Widget build(BuildContext context) => CupertinoSwitch(value: on, activeTrackColor: tint, onChanged: enabled ? onChanged : null);
}

/// A labelled row with a switch on the right (SwiftUI Toggle with a label).
class WToggleRow extends StatelessWidget {
  const WToggleRow({super.key, required this.on, required this.onChanged, this.enabled = true, this.tint = WColor.primary, required this.child, this.padding = EdgeInsets.zero});
  final bool on;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Color tint;
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Row(children: [Expanded(child: child), const SizedBox(width: 12), WToggle(on: on, onChanged: onChanged, enabled: enabled, tint: tint)]),
        ),
      );
}

/// Three dots; the current one stretches and fills from the left like a timer.
class TimerDots extends StatelessWidget {
  const TimerDots({super.key, required this.count, required this.index, required this.progress});
  final int count;
  final int index;
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Slide ${index + 1} of $count',
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == index ? 30 : 8,
              height: 8,
              decoration: BoxDecoration(color: i < index ? WColor.primary : WColor.border, borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.centerLeft,
              child: i == index
                  ? Container(width: (30 * progress).clamp(8, 30).toDouble(), height: 8, decoration: BoxDecoration(color: WColor.primary, borderRadius: BorderRadius.circular(4)))
                  : null,
            ),
          ],
        ]),
      );
}

/// Page dots (TabView page style). On the web the dots can be tapped.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index, this.light = true, this.onTap});
  final int count;
  final int index;
  final bool light;
  final ValueChanged<int>? onTap;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < count; i++)
          Pressable(
            feedback: false,
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: light ? (i == index ? WColor.white : Colors.white38) : (i == index ? WColor.heading : WColor.border))),
            ),
          ),
      ]);
}

/// Horizontal pager (TabView .page). Phones swipe between pages. On the web there are no
/// swipes: ‹ › arrow buttons sit on the sides instead (see docs/FLUTTER.md, "Swipes on the web").
class WPager extends StatefulWidget {
  const WPager({super.key, required this.count, required this.index, required this.onIndex, required this.builder, this.arrowsOnDark = true});
  final int count;
  final int index;
  final ValueChanged<int> onIndex;
  final IndexedWidgetBuilder builder;
  final bool arrowsOnDark;
  @override
  State<WPager> createState() => _WPagerState();
}

class _WPagerState extends State<WPager> {
  late final PageController _c = PageController(initialPage: widget.index);

  @override
  void didUpdateWidget(WPager old) {
    super.didUpdateWidget(old);
    if (_c.hasClients && (_c.page?.round() ?? widget.index) != widget.index) {
      _c.animateToPage(widget.index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pager = PageView.builder(
      controller: _c,
      physics: kIsWeb ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      itemCount: widget.count,
      onPageChanged: widget.onIndex,
      itemBuilder: widget.builder,
    );
    if (!kIsWeb) return pager;
    Widget arrow(bool left) {
      final enabled = left ? widget.index > 0 : widget.index < widget.count - 1;
      return Pressable(
        enabled: enabled,
        label: left ? 'Previous' : 'Next',
        onTap: () => widget.onIndex(widget.index + (left ? -1 : 1)),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.3,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.arrowsOnDark ? Colors.white24 : WColor.white, boxShadow: widget.arrowsOnDark ? null : const [BoxShadow(color: WColor.shadow, blurRadius: 4)]),
            alignment: Alignment.center,
            child: WIconView(left ? WIcon.left : WIcon.chevron, size: left ? 15 : 20, color: widget.arrowsOnDark ? WColor.white : WColor.heading, weight: semibold),
          ),
        ),
      );
    }

    return Stack(children: [
      pager,
      Positioned(left: 4, top: 0, bottom: 0, child: Center(child: arrow(true))),
      Positioned(right: 4, top: 0, bottom: 0, child: Center(child: arrow(false))),
    ]);
  }
}

/// Continuous animation 0→1 (repeating), for gentle pulses and bobs.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.builder, this.duration = const Duration(seconds: 1), this.reverse = true, this.active = true});
  final Widget Function(BuildContext, double t) builder;
  final Duration duration;
  final bool reverse;
  final bool active;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.active) _a.repeat(reverse: widget.reverse);
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_a.isAnimating) _a.repeat(reverse: widget.reverse);
    if (!widget.active && _a.isAnimating) _a.stop();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _a, builder: (c, _) => widget.builder(c, Curves.easeInOut.transform(_a.value)));
}

/// Fades and slides a child in when it first appears.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.offset = 16, this.duration = const Duration(milliseconds: 300)});
  final Widget child;
  final double offset;
  final Duration duration;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (c, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child)),
        child: child,
      );
}

/// Formatting re-export so screens import one file.
typedef F = Fmt;
