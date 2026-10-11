import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

/// Base screen. Header on top, scrolling content, footer bar pinned at the
/// bottom (it rises above the keyboard), optional bottom navigation.
class WScreen extends StatelessWidget {
  const WScreen({
    super.key,
    this.header,
    this.children = const [],
    this.body,
    this.footer,
    this.bottomNav,
    this.background = WColors.white,
    this.padding = const EdgeInsets.fromLTRB(WSpace.gutter, 20, WSpace.gutter, 16),
    this.gap = 24,
    this.overlay,
  });

  final Widget? header;
  final List<Widget> children;

  /// Replaces the default scrolling column when set.
  final Widget? body;
  final Widget? footer;
  final Widget? bottomNav;
  final Color background;
  final EdgeInsets padding;
  final double gap;

  /// Drawn over everything (sheets, dialogs, snackbars that are part of a design).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final content = body ??
        SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withGap(children, gap),
          ),
        );
    final column = Column(
      children: [
        if (header != null) header!,
        Expanded(child: content),
        if (footer != null) footer!,
        if (bottomNav != null) bottomNav!,
      ],
    );
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: footer == null && bottomNav == null,
        child: overlay == null ? column : Stack(children: [column, Positioned.fill(child: overlay!)]),
      ),
    );
  }
}

List<Widget> _withGap(List<Widget> children, double gap) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(SizedBox(height: gap));
    out.add(children[i]);
  }
  return out;
}

/// Column with a fixed gap between children.
class WGap extends StatelessWidget {
  const WGap({super.key, required this.children, this.gap = 12, this.crossAxisAlignment = CrossAxisAlignment.stretch});

  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: _withGap(children, gap),
      );
}

/// Design: App bar. 48 · title · 48.
class WAppBar extends StatelessWidget {
  const WAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.onBack,
    this.onHelp,
    this.backIcon = Icons.chevron_left_rounded,
    this.backLabel = 'Go back',
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onHelp;
  final IconData backIcon;
  final String backLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: onBack == null
                ? null
                : WIconButton(
                    icon: backIcon,
                    label: backLabel,
                    onPressed: onBack,
                    style: WIconButtonStyle.flat,
                  ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(title!, style: WText.appBarTitle, textAlign: TextAlign.center),
                if (subtitle != null)
                  Text(subtitle!, style: WText.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: trailing ??
                (onHelp == null
                    ? null
                    : WIconButton(
                        icon: Icons.help_outline_rounded,
                        label: 'Get help',
                        onPressed: onHelp,
                        style: WIconButtonStyle.flat,
                      )),
          ),
        ],
      ),
    );
  }
}

/// Header: app bar plus optional step progress.
class WHeader extends StatelessWidget {
  const WHeader({super.key, required this.appBar, this.progress});

  final WAppBar appBar;
  final WProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          appBar,
          if (progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
              child: progress,
            ),
        ],
      ),
    );
  }
}

/// Design: Progress. "Step 1 of 5 · Vehicle".
class WProgress extends StatelessWidget {
  const WProgress({super.key, required this.step, required this.total, required this.label, this.done = false});

  final int step;
  final int total;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = 'Step $step of $total · $label';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 4,
              backgroundColor: WColors.track,
              color: done ? WColors.success : WColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(text, style: WText.label.copyWith(color: WColors.primaryStrong)),
        ],
      ),
    );
  }
}

/// Design: Footer bar. Call/help sits bottom-left on task screens; the one
/// primary action fills the rest.
class WFooterBar extends StatelessWidget {
  const WFooterBar({super.key, this.leading, required this.children, this.vertical = false});

  /// Usually a call-support [WIconButton].
  final Widget? leading;
  final List<Widget> children;

  /// Stack buttons vertically (primary on top) instead of side by side.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WColors.white,
        border: Border(top: BorderSide(color: WColors.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(WSpace.gutter, 12, WSpace.gutter, math.max(16, bottomInset)),
        child: vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _withGap(children, 4),
              )
            : Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Design: Bottom navigation.
class WNavItem {
  const WNavItem({required this.icon, required this.label, this.badge});

  final IconData icon;
  final String label;
  final int? badge;
}

class WBottomNav extends StatelessWidget {
  const WBottomNav({super.key, required this.items, required this.index, required this.onTap});

  final List<WNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WColors.white,
        border: Border(top: BorderSide(color: WColors.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 10, 8, math.max(8, bottomInset)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++) _NavButton(item: items[i], selected: i == index, onTap: () => onTap(i)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final WNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.badge == null ? item.label : '${item.label}, ${item.badge} new';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected ? WColors.primaryTint : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(item.icon, size: 22, color: selected ? WColors.primaryStrong : WColors.secondary),
                  ),
                  if (item.badge != null)
                    Positioned(
                      top: -2,
                      right: 8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: WColors.destructive, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text('${item.badge}',
                            style: WText.label.copyWith(fontSize: 10, color: WColors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: WText.caption.copyWith(
                  fontSize: 12,
                  color: selected ? WColors.heading : WColors.secondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
