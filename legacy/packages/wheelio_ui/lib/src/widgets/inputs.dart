import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import '../typography.dart';

/// Design: Text field with the label sitting on the border.
class WTextField extends StatelessWidget {
  const WTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.prefixText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? error;
  final String? prefixText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  static OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(WRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      style: WText.value,
      cursorColor: WColors.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: error == null ? helper : null,
        helperMaxLines: 3,
        helperStyle: WText.caption,
        error: error == null
            ? null
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: WColors.destructive),
                  const SizedBox(width: 6),
                  Expanded(child: Text(error!, style: WText.caption.copyWith(color: WColors.destructive))),
                ],
              ),
        prefixText: prefixText,
        prefixStyle: WText.value,
        suffixIcon: suffix,
        hintStyle: WText.value.copyWith(color: WColors.placeholder),
        labelStyle: WText.label,
        floatingLabelStyle: WText.label.copyWith(color: error == null ? WColors.primaryStrong : WColors.destructive),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: WColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: _border(WColors.border, 1),
        enabledBorder: _border(WColors.border, 1),
        focusedBorder: _border(WColors.primary, 2),
        errorBorder: _border(WColors.destructive, 2),
        focusedErrorBorder: _border(WColors.destructive, 2),
      ),
    );
  }
}

/// Design: Chip. Selected = blue outline on tint. Disabled = crossed out (full slot).
class WChoiceChip extends StatelessWidget {
  const WChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Border border;
    if (disabled) {
      bg = WColors.canvas;
      fg = WColors.muted;
      border = Border.all(color: WColors.divider);
    } else if (selected) {
      bg = WColors.primaryTint;
      fg = WColors.primaryStrong;
      border = Border.all(color: WColors.primary, width: 2);
    } else {
      bg = WColors.white;
      fg = WColors.body;
      border = Border.all(color: WColors.border);
    }
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: disabled ? '$label, full' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(WRadius.chip)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: WText.bodyStrong.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    decoration: disabled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Design: Radio dot used in lists and sheets.
class WRadio extends StatelessWidget {
  const WRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WColors.white,
          border: Border.all(color: selected ? WColors.primary : WColors.muted, width: selected ? 7 : 2),
        ),
      );
}

/// Design: OTP boxes. A single hidden text field drives the boxes so paste
/// and iOS one-time-code autofill both work.
class WOtpField extends StatefulWidget {
  const WOtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.error = false,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final bool error;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<WOtpField> createState() => _WOtpFieldState();
}

class _WOtpFieldState extends State<WOtpField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Enter the ${widget.length}-digit code',
      textField: true,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([widget.controller, _focus]),
            builder: (context, _) {
              final text = widget.controller.text;
              return Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(WRadius.field),
                          border: widget.error
                              ? Border.all(color: WColors.destructive, width: 2)
                              : (_focus.hasFocus && i == text.length.clamp(0, widget.length - 1))
                                  ? Border.all(color: WColors.primary, width: 2)
                                  : Border.all(color: WColors.border),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: WText.section.copyWith(fontSize: 22),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
              onChanged: (v) {
                if (v.length == widget.length) widget.onCompleted?.call(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Design: Tabs with an underline (Bookings: Upcoming / Past).
class WTabs extends StatelessWidget {
  const WTabs({super.key, required this.labels, required this.index, required this.onTap});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WColors.divider))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: InkWell(
                  onTap: () => onTap(i),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          labels[i],
                          style: WText.bodyStrong.copyWith(
                            fontWeight: FontWeight.w600,
                            color: i == index ? WColors.primaryStrong : WColors.secondary,
                          ),
                        ),
                        if (i == index)
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: 56,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: WColors.primary,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Design: Segmented control (pill).
class WSegmented extends StatelessWidget {
  const WSegmented({super.key, required this.labels, required this.index, required this.onTap});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: WColors.disabled, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? WColors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: i == index
                          ? const [BoxShadow(color: WColors.shadow, blurRadius: 3, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: WText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w600,
                        color: i == index ? WColors.heading : WColors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
