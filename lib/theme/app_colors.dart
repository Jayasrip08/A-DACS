import 'package:flutter/material.dart';

class AppColors {
  // PRIMARY BRAND COLORS (Vibrant & Trustworthy)
  static const Color red = Color(0xFFC6372D);
  static const Color redLight = Color(0xFFFFF1F0);
  static const Color redDark = Color(0xFFA52A22);

  // NEUTRAL COLORS (Clean & Simple)
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color slate = Color(0xFF1E293B);
  static const Color slateLight = Color(0xFF475569);
  static const Color slateLighter = Color(0xFFF1F5F9);
  static const Color grey = Color(0xFF94A3B8);

  // FUNCTIONAL COLORS (Muted/Professional)
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  static const Color error = Color(0xFFEF4444);

  // GRADIENTS
  static const LinearGradient redGradient = LinearGradient(
    colors: [red, redDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // UTILITY STYLES
  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: const Color(0xFFC6372D).withOpacity(0.04), // Subtle brand glow
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF1E293B).withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF1E293B).withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
