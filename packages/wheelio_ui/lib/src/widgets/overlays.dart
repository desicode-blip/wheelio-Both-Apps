import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Design: Bottom sheet (radius 28, grab handle).
Future<T?> showWSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: WColors.white,
    barrierColor: WColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WRadius.sheet))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WSpace.gutter, 12, WSpace.gutter, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: WColors.grab, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: builder(context))),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Design: Dialog (radius 28). Returns true when the primary action is chosen.
Future<bool> showWDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: WColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: WColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WRadius.sheet)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: WText.section),
            const SizedBox(height: 12),
            Text(body, style: WText.body),
            const SizedBox(height: 20),
            _DialogButton(
              label: confirmLabel,
              background: destructive ? WColors.destructive : WColors.primary,
              foreground: WColors.white,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            _DialogButton(
              label: cancelLabel,
              background: Colors.transparent,
              foreground: WColors.primaryStrong,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.background, required this.foreground, required this.onTap});

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: WSize.button,
        child: Material(
          color: background,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(child: Text(label, style: WText.action.copyWith(color: foreground))),
          ),
        ),
      );
}

/// Design: Snackbar (dark, above the footer bar).
void showWSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: WText.bodyStrong.copyWith(color: WColors.white)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 113),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, textColor: WColors.primaryTint, onPressed: onAction ?? () {}),
      ),
    );
}
