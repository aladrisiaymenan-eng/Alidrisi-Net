import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1E40AF); // Deep Indigo
  static const primaryDark = Color(0xFF1E3A8A);
  static const indigo = primary;
  static const indigoLight = primaryDark;
  static const teal = Color(0xFF0D9488);
  static const cyan = Color(0xFF0891B2);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF334155);
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final text = isDark ? Colors.white : AppColors.ink;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.teal,
      surface: surface,
      error: AppColors.danger,
    );
    final radius = BorderRadius.circular(14);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      fontFamily: 'sans',
      textTheme: ThemeData(brightness: brightness)
          .textTheme
          .apply(bodyColor: text, displayColor: text, fontFamily: 'sans'),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle:
            TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.primary.withValues(alpha: isDark ? .15 : .08),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: .06) : Colors.white,
        border: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border)),
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.darkBorder : AppColors.border,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side:
            BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: text),
      ),
      dividerTheme: DividerThemeData(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          thickness: .8),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
        contentTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
