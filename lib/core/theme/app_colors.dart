import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Palette - Deep Obsidian Dark Theme
  static const Color background = Color(0xFF07070D);
  static const Color secondaryBackground = Color(0xFF0E0F18);
  static const Color primaryPurple = Color(0xFF7657F5);
  static const Color accentCyan = Color(0xFF35D6E8);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA5A5B5);

  // Surface & Accent Shades
  static const Color cardSurface = Color(0xFF121320);
  static const Color cardBorder = Color(0xFF1F2034);
  static const Color chipBackground = Color(0xFF161726);
  static const Color inactiveIndicator = Color(0xFF27293E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF141526), Color(0xFF0E0F18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const RadialGradient glowGradient = RadialGradient(
    colors: [Color(0x337657F5), Colors.transparent],
    radius: 0.85,
  );
}
