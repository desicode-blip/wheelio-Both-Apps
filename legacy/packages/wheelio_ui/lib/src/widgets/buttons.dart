import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Design: Button/Primary, Button/Success, Button/Outline, Button/Text,
/// Button/Danger, Button/Tonal. Disabled when [onPressed] is null.
///
/// Rules: one primary action per screen. Green only to pay, approve or accept.
/// Red only for errors and destructive actions.
enum WButtonVariant { primary, success, outline, text, danger, tonal }

class WButton extends StatelessWidget {
  const WButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.height = WSize.button,
    this.loading = false,
  });

  const WButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
  })  : variant = WButtonVariant.text,
        height = WSize.touchMin;

  final String label;
  final VoidCallback? onPressed;
  final WButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    late Color bg;
    late Color fg;
    BorderSide side = BorderSide.none;
    switch (variant) {
      case WButtonVariant.primary:
        bg = WColors.primary;
        fg = WColors.white;
      case WButtonVariant.success:
        bg = WColors.success;
        fg = WColors.onSuccess;
      case WButtonVariant.outline:
        bg = WColors.white;
        fg = WColors.primaryStrong;
        side = const BorderSide(color: WColors.primary, width: 1.5);
      case WButtonVariant.text:
        bg = Colors.transparent;
        fg = WColors.primaryStrong;
      case WButtonVariant.danger:
        bg = WColors.destructive;
        fg = WColors.white;
      case WButtonVariant.tonal:
        bg = WColors.primaryTint;
        fg = WColors.primaryStrong;
    }
    if (!enabled && !loading) {
      if (variant == WButtonVariant.text) {
        fg = WColors.muted;
      } else {
        bg = WColors.disabled;
        fg = WColors.placeholder;
        side = BorderSide.none;
      }
    }
    final shape = StadiumBorder(side: side);
    final textStyle = WText.action.copyWith(color: fg);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Material(
          color: bg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(label, style: textStyle, textAlign: TextAlign.center),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 20, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Design: Icon button (48 px circle). Always needs a [label] for screen readers.
enum WIconButtonStyle { raised, flat, tint }

class WIconButton extends StatelessWidget {
  const WIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.style = WIconButtonStyle.raised,
    this.size = WSize.iconButton,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final WIconButtonStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, shadow) = switch (style) {
      WIconButtonStyle.raised => (WColors.white, WColors.heading, true),
      WIconButtonStyle.flat => (Colors.transparent, WColors.heading, false),
      WIconButtonStyle.tint => (WColors.primaryTint, WColors.primaryStrong, false),
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: shadow
                ? const [BoxShadow(color: WColors.shadow, blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(child: Icon(icon, size: 22, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
