// WashKrew design system tokens, ported from apps/ios/Shared/DesignSystem/Tokens.swift.
// Both apps (Customer and Captain) share this file.

import 'package:flutter/widgets.dart';

class Brand {
  /// Product name. Renamed from WashKrew on 25 Oct 2026. Change it here only.
  static const name = 'WashKrew';
  static const captainApp = 'WashKrew Captain';
  static const tagline = 'Vehicle cleaning, on demand';
  static const website = 'washkrew.com';
  static const websiteUrl = 'https://washkrew.com';
}

/// Colours aligned to the WashKrew logo (25 Oct 2026): blue #0049FF is the solid end of the
/// logo's "Krew" gradient, charcoal #22282D is "Wash" and the door. Text greys sit in the
/// same charcoal family. Contrast on white: primary 6.2:1, heading 14.9:1, body 11.0:1,
/// secondary 5.7:1; primary on primaryTint 5.4:1 (passes for text).
class WColor {
  // action
  static const primary = Color(0xFF0049FF);
  static const primaryStrong = Color(0xFF003BD1);
  static const success = Color(0xFF4BD08C);
  static const onSuccess = Color(0xFF15352A);
  static const destructive = Color(0xFFB3261E);
  // content
  static const heading = Color(0xFF22282D);
  static const body = Color(0xFF363D44);
  static const secondary = Color(0xFF5F6870);
  static const placeholder = Color(0xFF80878E);
  static const muted = Color(0xFF9CA2A8);
  // surface
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF6F9FD);
  static const primaryTint = Color(0xFFEAF0FF);
  static const successTint = Color(0xFFE6F8EF);
  static const waitTint = Color(0xFFFFF3E0);
  static const wait = Color(0xFF8A4500);
  static const waitText = Color(0xFF5C2E00);
  static const errorTint = Color(0xFFFDECEA);
  static const errorText = Color(0xFF7A1A14);
  static const disabled = Color(0xFFE8ECF2);
  static const inverse = Color(0xFF22282D);
  static const camera = Color(0xFF0E1520);
  static const cameraPanel = Color(0xFF1C2636);
  static const photo = Color(0xFFE6EAF0);
  static const map = Color(0xFFEEF2F7);
  static const mapBlock = Color(0xFFE2E8F0);
  static const mapGreen = Color(0xFFDDE9D8);
  static const star = Color(0xFFF0A030);
  // border
  static const border = Color(0xFFDCE2E9);
  static const divider = Color(0xFFE1E5EA);
  static const track = Color(0xFFDCE5F6);
  static const dashed = Color(0xFF9FB3D9);
  static const grab = Color(0xFFC9D5E6);

  static const scrim = Color(0x7A22282D);
  static const shadow = Color(0x1F22282D);
  static const shadowCard = Color(0x1422282D);
}

/// Semantic tone for badges, banners and state circles.
/// Colour is never the only signal: always pair a tone with an icon and a word.
enum Tone {
  info, ok, wait, error, mute;

  Color get background => switch (this) {
        Tone.info => WColor.primaryTint,
        Tone.ok => WColor.successTint,
        Tone.wait => WColor.waitTint,
        Tone.error => WColor.errorTint,
        Tone.mute => WColor.disabled,
      };

  Color get foreground => switch (this) {
        Tone.info => WColor.primaryStrong,
        Tone.ok => WColor.onSuccess,
        Tone.wait => WColor.wait,
        Tone.error => WColor.destructive,
        Tone.mute => WColor.body,
      };

  /// Text colour for longer text on a tinted banner.
  Color get bannerText => switch (this) {
        Tone.info => WColor.inverse,
        Tone.ok => WColor.onSuccess,
        Tone.wait => WColor.waitText,
        Tone.error => WColor.errorText,
        Tone.mute => WColor.body,
      };
}

class WSpace {
  static const double gutter = 26;
  static const double gutterCaptain = 16;
}

class WRadius {
  static const double field = 10;
  static const double chip = 10;
  static const double tile = 14;
  static const double card = 20;
  static const double sheet = 28;
}

/// Type scale from the design read-me (size / line height, weight, default colour).
enum WType {
  display(40, 48, FontWeight.w700, WColor.heading),
  screen(26, 32, FontWeight.w700, WColor.heading),
  section(20, 26, FontWeight.w600, WColor.heading),
  value(17, 22, FontWeight.w400, WColor.heading),
  valueStrong(17, 22, FontWeight.w600, WColor.heading),
  appBarTitle(17, 22, FontWeight.w600, WColor.heading),
  title(16, 21, FontWeight.w600, WColor.heading),
  rowTitle(16, 21, FontWeight.w400, WColor.heading),
  body(15, 22, FontWeight.w400, WColor.secondary),
  bodyStrong(15, 22, FontWeight.w400, WColor.body),
  action(16.5, 21, FontWeight.w600, WColor.white),
  caption(13, 18, FontWeight.w400, WColor.secondary),
  label(12.5, 16, FontWeight.w600, WColor.secondary),
  small(11.5, 14, FontWeight.w400, WColor.secondary),
  bigMoney(44, 52, FontWeight.w700, WColor.heading),
  hugeMoney(56, 64, FontWeight.w700, WColor.heading);

  const WType(this.size, this.line, this.weight, this.color);
  final double size;
  final double line;
  final FontWeight weight;
  final Color color;
}

const wFont = 'Roboto';
const wFontPackage = 'washkrew_ui';

/// Text style for a type token; [size] scales the line height with it.
TextStyle wStyle(WType t, {Color? color, FontWeight? weight, double? size, bool mono = false, double scale = 1}) {
  final s = (size ?? t.size) * scale;
  return TextStyle(
    fontFamily: wFont,
    package: wFontPackage,
    fontSize: s,
    height: t.line / t.size,
    fontWeight: weight ?? t.weight,
    color: color ?? t.color,
    fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
    letterSpacing: 0,
  );
}
