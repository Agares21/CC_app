import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Estilos de texto de la aplicación.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter();

  static TextStyle get headingLg => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.brand,
      );

  static TextStyle get headingMd => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.brand,
      );

  static TextStyle get headingSm => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.brand,
      );

  static TextStyle get body => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.foreground,
      );

  static TextStyle get bodySm => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.foreground,
      );

  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.mutedForeground,
      );

  static TextStyle get captionXs => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.mutedForeground,
      );

  static TextStyle get label => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.brand,
      );

  static TextStyle get button => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      );

  static TextStyle get buttonSm => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      );
}
