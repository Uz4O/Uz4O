import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFFF4F8F8);
  static const homeBackground = Color(0xFFF8FAFA);
  static const surface = Colors.white;
  static const primary = Color(0xFF111827);
  static const secondary = Color(0xFF8A929D);
  static const border = Color(0xFFE4E8ED);
  static const destructive = Color(0xFFFF4B5E);

  static List<BoxShadow> cardShadow({double opacity = 0.075}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 24,
      offset: const Offset(0, 14),
    ),
  ];
}
