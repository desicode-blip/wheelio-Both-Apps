import 'package:flutter/material.dart';

import 'components.dart';
import 'icons.dart';
import 'tokens.dart';

/// Words for [showDeleteAccountDialog], so each app can pass its own language.
class DeleteAccountText {
  const DeleteAccountText({
    this.title = 'Delete your account?',
    required this.message,
    this.delete = 'Delete account',
    this.keep = 'Keep my account',
  });
  final String title, message, delete, keep;
}

/// C53 destructive dialog ("Delete your account?"), used by the Captain profile.
/// The Customer profile draws the same dialog inline (C53).
///
/// [delete] runs when the danger button is tapped and returns an error to show
/// in the dialog, or null when the account is gone. The dialog then closes with
/// true. "Keep my account" or tapping outside closes it with false.
Future<bool> showDeleteAccountDialog(
  BuildContext context, {
  required DeleteAccountText text,
  required Future<String?> Function() delete,
  ButtonSize size = ButtonSize.regular,
}) async {
  final done = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: text.keep,
    barrierColor: WColor.scrim,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _DeleteAccountDialog(text: text, delete: delete, size: size),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
  return done == true;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.text, required this.delete, required this.size});
  final DeleteAccountText text;
  final Future<String?> Function() delete;
  final ButtonSize size;
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool busy = false;
  String? error;

  Future<void> _deleteTapped() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    final problem = await widget.delete();
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() { busy = false; error = problem; });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(28)),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WIconBox(WIcon.trash, size: 52, tone: Tone.error, radius: 26),
              const SizedBox(height: 12),
              WText(t.title, WType.section, weight: semibold),
              const SizedBox(height: 12),
              WText(t.message, WType.body),
              if (error != null) ...[
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: WIconView(WIcon.warning, size: 15, color: WColor.destructive)),
                  const SizedBox(width: 8),
                  Expanded(child: WText(error!, WType.caption, color: WColor.destructive)),
                ]),
              ],
              const SizedBox(height: 18),
              WButton(t.delete, kind: ButtonKind.danger, size: widget.size, loading: busy, onTap: _deleteTapped),
              const SizedBox(height: 12),
              WButton(t.keep, kind: ButtonKind.text, size: widget.size, onTap: busy ? null : () => Navigator.of(context).pop(false)),
            ],
          ),
        ),
      ),
    );
  }
}
