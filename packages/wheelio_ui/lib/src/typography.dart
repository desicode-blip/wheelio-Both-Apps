import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type scale from the design read-me (size / line height, weight).
///
/// Display 40/48 Bold · Heading/Screen 26/32 Bold · Heading/Section 20/26 SemiBold
/// Body/Field value 17/22 · Body 15/22 · Label/Action 16.5/21 SemiBold
/// Caption 13/18 · Label/Field 12.5/16 SemiBold
abstract final class WText {
  static TextStyle _roboto(double size, double lineHeight, FontWeight weight, Color color) =>
      GoogleFonts.roboto(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: color,
      );

  static TextStyle get display => _roboto(40, 48, FontWeight.w700, WColors.heading);
  static TextStyle get screen => _roboto(26, 32, FontWeight.w700, WColors.heading);
  static TextStyle get section => _roboto(20, 26, FontWeight.w600, WColors.heading);
  static TextStyle get value => _roboto(17, 22, FontWeight.w400, WColors.heading);
  static TextStyle get valueStrong => _roboto(17, 22, FontWeight.w600, WColors.heading);
  static TextStyle get title => _roboto(16, 21, FontWeight.w600, WColors.heading);
  static TextStyle get rowTitle => _roboto(16, 21, FontWeight.w400, WColors.heading);
  static TextStyle get body => _roboto(15, 22, FontWeight.w400, WColors.secondary);
  static TextStyle get bodyStrong => _roboto(15, 22, FontWeight.w400, WColors.body);
  static TextStyle get action => _roboto(16.5, 21, FontWeight.w600, WColors.white);
  static TextStyle get caption => _roboto(13, 18, FontWeight.w400, WColors.secondary);
  static TextStyle get label => _roboto(12.5, 16, FontWeight.w600, WColors.secondary);
  static TextStyle get appBarTitle => _roboto(17, 22, FontWeight.w600, WColors.heading);
  static TextStyle get bigMoney => _roboto(44, 52, FontWeight.w700, WColors.heading)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Money always uses tabular figures.
  static TextStyle money(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
