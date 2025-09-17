import 'package:flutter/material.dart';

class AppColors {
  // Primary futuristic palette
  static const Color primary = Color(0xFF0FF4C6); // Neon Cyan
  static const Color secondary = Color(0xFF9D00FF); // Vivid Purple
  static const Color accent = Color(0xFFFF005C); // Neon Pink

  // Backgrounds
  static const Color backgroundDark = Color(0xFF0A0F1E); // Deep Space Black
  static const Color backgroundLight = Color(0xFF1B233A); // Muted Futuristic Navy

  // Gradients (can be used with LinearGradient)
  static const List<Color> gradient1 = [primary, secondary];
  static const List<Color> gradient2 = [accent, primary];

  // Additional accent tones
  static const Color neonBlue = Color(0xFF00F0FF);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonOrange = Color(0xFFFFA500);

  // Neutral futuristic grays
  static const Color greyLight = Color(0xFFB0B3C6);
  static const Color greyDark = Color(0xFF3A3D52);

  // Success / Error states (futuristic style)
  static const Color success = Color(0xFF00FF88); // Bright Emerald
  static const Color error = Color(0xFFFF1744); // Futuristic Red
}
