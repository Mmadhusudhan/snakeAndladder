import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Light and dark themes with the jungle look.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.jungleMid,
      brightness: brightness,
      primary: AppColors.gold,
      secondary: AppColors.jungleLight,
      surface: isDark ? AppColors.jungleDark : AppColors.cream,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.jungleDeep : AppColors.cream,
      fontFamilyFallback: const ['Avenir', 'Roboto', 'Segoe UI', 'sans-serif'],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: isDark ? AppColors.cream : AppColors.jungleDeep,
        displayColor: isDark ? AppColors.cream : AppColors.jungleDeep,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.jungleDeep,
          elevation: 6,
          shadowColor: AppColors.goldDark.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.cream : AppColors.jungleDeep,
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.8), width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark
            ? AppColors.jungleDark.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.jungleDark : AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.gold,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: AppColors.gold),
      ),
    );
  }

  /// Full-screen gradient used behind every screen.
  static BoxDecoration background(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [AppColors.jungleDark, AppColors.jungleDeep]
            : const [Color(0xFFE6F4D9), AppColors.cream],
      ),
    );
  }
}
