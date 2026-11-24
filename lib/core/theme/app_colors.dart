import 'package:flutter/material.dart';

/// Urban Pets design system colors — derived from the premium UI reference
/// screenshots (UrbanPets_Premium_UI_HD/*.png): deep navy header, bright
/// professional blue primary actions, clean light-neutral surfaces, green
/// accent for the Urban Pets brand paw mark, and semantic status colors for
/// variance / expiry indicators.
class AppColors {
  AppColors._();

  // Brand
  static const Color navy = Color(0xFF0E2A63); // header / app bar
  static const Color primaryBlue = Color(0xFF1958E8); // primary actions
  static const Color primaryBlueLight = Color(0xFF4C82F7);
  static const Color primaryBlueDark = Color(0xFF123FA8);
  static const Color accentGreen = Color(
    0xFF2E9E5B,
  ); // brand paw / success accents

  // Surfaces
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F3FA);
  static const Color border = Color(0xFFE1E6F0);
  static const Color borderSubtle = Color(0xFFEDF2F7);
  static const Color cardShadow = Color(0x0C101530); // ~5% soft shadow

  // Typography
  static const Color textPrimary = Color(0xFF101530);
  static const Color textSecondary = Color(0xFF5B6478);
  static const Color textMuted = Color(0xFF8A93A8);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Status / severity
  static const Color success = Color(0xFF2E9E5B);
  static const Color successBg = Color(0xFFE5F7EC);
  static const Color warning = Color(0xFFC88A12);
  static const Color warningBg = Color(0xFFFFF4DE);
  static const Color critical = Color(0xFFD6334C);
  static const Color criticalBg = Color(0xFFFDE8EB);
  static const Color info = Color(0xFF1958E8);
  static const Color infoBg = Color(0xFFE8EFFD);
  static const Color pending = Color(0xFFC88A12);
  static const Color pendingBg = Color(0xFFFFF4DE);

  // Variance
  static const Color variancePositive = Color(0xFF2E9E5B); // overage
  static const Color varianceNegative = Color(0xFFD6334C); // shortage
  static const Color varianceNeutral = Color(0xFF5B6478);

  // Unified brand colors across Stock Count, Assign Task, etc.
  static const Color tileStockCount = Color(0xFF1958E8);
  static const Color tileExpiryCheck = Color(0xFF1958E8);
  static const Color tileQuickView = Color(0xFF1958E8);
  static const Color tileMyTasks = Color(0xFF1958E8);

  static const Color scrim = Color(0x66101530);
}
