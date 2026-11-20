import 'package:flutter/material.dart';

/// Design tokens inspired by modern luxury editorial travel & audio apps
/// (Forest Pine, Warm Cream/Off-White canvas, Pure White cards, Golden Star, Slate Charcoal)
class AppColors {
  AppColors._();

  // Primary Brand: Deep Forest Pine (#1E513B) for buttons, active tabs, and main accents
  static const Color primary = Color(0xFF1E513B);
  static const Color primaryDark = Color(0xFF133B2B);
  static const Color primaryLight = Color(0xFF2D6A4F);
  static const Color onPrimary = Colors.white;

  // Mint / Light Container for badges and chips
  static const Color primaryContainer = Color(0xFFEAF4EE);
  static const Color onPrimaryContainer = Color(0xFF1E513B);

  // Vibrant Brand Logo Mint (#0CD090) used specifically for the Brand Logo mark, Splash Screen, and App Icon
  static const Color logoGreen = Color(0xFF0CD090);
  static const Color splashBackground = Color(0xFF0CD090);

  // Accent Amber Gold for ratings and awards
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color onAmber = Colors.white;

  // Canvases & Backgrounds
  static const Color background = Color(0xFFF8F9FA);
  static const Color backgroundSubtle = Color(0xFFF1F3F5);

  // Surfaces & Cards
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF3F4F6);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSubtle = Color(0xFFEFF1F3);
  static const Color divider = Color(0xFFE5E7EB);

  // Typography
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Colors.white;

  // Status
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // Shadows - Razor crisp, minimal, non-blurry modern Google M3 depth
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.025),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> primaryGlow({double blur = 16}) => [
        BoxShadow(
          color: primary.withValues(alpha: 0.28),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ];
}
