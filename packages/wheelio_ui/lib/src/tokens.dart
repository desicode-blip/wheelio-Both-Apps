import 'package:flutter/widgets.dart';

/// Colour tokens from the Wheelio design system (Figma "🎨 Design system").
/// Names follow the token names used in the design read-me.
abstract final class WColors {
  // action
  static const primary = Color(0xFF3160FF); // action/primary
  static const primaryStrong = Color(0xFF1F4AD1); // action/primary-strong
  static const success = Color(0xFF4BD08C); // action/success
  static const onSuccess = Color(0xFF15352A);
  static const destructive = Color(0xFFB3261E); // action/destructive

  // content
  static const heading = Color(0xFF172231); // content/heading
  static const body = Color(0xFF2B3A4D); // content/body
  static const secondary = Color(0xFF5E7087); // content/secondary
  static const placeholder = Color(0xFF7E8B9C);
  static const muted = Color(0xFF9AA6B6);

  // surface
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF6F9FD); // surface/canvas
  static const primaryTint = Color(0xFFEAF0FF); // surface/primary-tint
  static const successTint = Color(0xFFE6F8EF); // surface/success-tint
  static const waitTint = Color(0xFFFFF3E0);
  static const wait = Color(0xFF8A4500);
  static const waitText = Color(0xFF5C2E00);
  static const errorTint = Color(0xFFFDECEA);
  static const errorText = Color(0xFF7A1A14);
  static const disabled = Color(0xFFE8ECF2);
  static const inverse = Color(0xFF1B2533);
  static const camera = Color(0xFF0E1520);
  static const map = Color(0xFFEEF2F7);
  static const mapBlock = Color(0xFFE2E8F0);

  // border
  static const border = Color(0xFFDCE2E9); // border/default
  static const divider = Color(0xFFE1E5EA);
  static const track = Color(0xFFDCE5F6);
  static const dashed = Color(0xFF9FB3D9);
  static const grab = Color(0xFFC9D5E6);

  static const scrim = Color(0x7A172130); // rgba(23,33,48,.48)
  static const shadow = Color(0x1F172130); // rgba(23,33,48,.12)
  static const shadowCard = Color(0x14172130); // rgba(23,33,48,.08)
}

/// Spacing: 4 px base. Screen gutter is 26 (customer) / 16 (washer).
abstract final class WSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double gutter = 26;
  static const double gutterWasher = 16;
  static const double section = 48;
}

/// Radius tokens: field 10 · chip 10 · card 20 · button 26 (pill) · sheet 28.
abstract final class WRadius {
  static const double field = 10;
  static const double chip = 10;
  static const double tile = 14;
  static const double card = 20;
  static const double button = 26;
  static const double sheet = 28;
}

/// Control sizes. Customer buttons 52 high, footer bar 101 high.
/// Washer buttons 64, accept 72, call button 64.
abstract final class WSize {
  static const double button = 52;
  static const double buttonWasher = 64;
  static const double buttonAccept = 72;
  static const double iconButton = 48;
  static const double iconButtonWasher = 64;
  static const double touchMin = 48;
  static const double footer = 101;
  static const double bottomNav = 80;
}

/// Semantic tone used by badges, banners and state circles.
/// Colour is never the only signal: always pair a tone with an icon and a word.
enum WTone { info, ok, wait, error, mute }

extension WToneColors on WTone {
  Color get background => switch (this) {
        WTone.info => WColors.primaryTint,
        WTone.ok => WColors.successTint,
        WTone.wait => WColors.waitTint,
        WTone.error => WColors.errorTint,
        WTone.mute => WColors.disabled,
      };

  Color get foreground => switch (this) {
        WTone.info => WColors.primaryStrong,
        WTone.ok => WColors.onSuccess,
        WTone.wait => WColors.wait,
        WTone.error => WColors.destructive,
        WTone.mute => WColors.body,
      };

  /// Text colour for long text on a tinted banner.
  Color get bannerText => switch (this) {
        WTone.info => WColors.inverse,
        WTone.ok => WColors.onSuccess,
        WTone.wait => WColors.waitText,
        WTone.error => WColors.errorText,
        WTone.mute => WColors.body,
      };
}
