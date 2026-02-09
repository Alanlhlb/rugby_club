import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Base (dark-first) ───
  static const Color scaffoldBg = Color(0xFF0E1118);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF1C2230);
  static const Color card = Color(0xFF1C2230);
  static const Color divider = Color(0xFF2A3040);

  // ─── Primary (green accent) ───
  static const Color primary = Color(0xFF22C55E);
  static const Color primaryGreen = Color(0xFF22C55E);
  static const Color primaryLight = Color(0xFF4ADE80);
  static const Color primaryDark = Color(0xFF16A34A);
  static const Color primaryMuted = Color(0xFF1A3A2A);

  // ─── Secondary (amber/orange) ───
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFBBF24);
  static const Color secondaryDark = Color(0xFFD97706);

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF8B95A5);
  static const Color textHint = Color(0xFF555F70);

  // ─── Status ───
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Event Types ───
  static const Color matchRed = Color(0xFFEF4444);

  // ─── Attendance ───
  static const Color notGoing = Color(0xFFEF4444);

  // ─── Match Cards ───
  static const Color yellowCard = Color(0xFFF59E0B);
  static const Color redCard = Color(0xFFDC2626);
  static const Color injured = Color(0xFFF87171);
  static const Color suspended = Color(0xFF6B7280);

  // ─── Pitch ───
  static const Color pitchGreen = Color(0xFF1B5E20);
  static const Color pitchLine = Color(0xFFFFFFFF);

  // ─── FIFA Card Gradients ───
  static const List<Color> fifaCardGold = [
    Color(0xFFD4A422),
    Color(0xFFE8C84A),
  ];
  static const List<Color> fifaCardSilver = [
    Color(0xFF8A9A9B),
    Color(0xFFB0BEC5),
  ];
  static const List<Color> fifaCardBronze = [
    Color(0xFF8D6E3F),
    Color(0xFFCD7F32),
  ];
}
