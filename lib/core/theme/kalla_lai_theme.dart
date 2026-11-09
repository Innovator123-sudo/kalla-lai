import 'package:flutter/material.dart';

abstract final class KallaLaiColors {
  static const slate = Color(0xFF0F172A);
  static const indigo = Color(0xFF4F46E5);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFD97706);
  static const crimson = Color(0xFFDC2626);
  static const successText = Color(0xFF166534);
  static const warningText = Color(0xFF8A4B08);
  static const errorText = Color(0xFFB91C1C);
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Colors.white;
  static const muted = Color(0xFF475569);
  static const outline = Color(0xFFE2E8F0);
}

abstract final class KallaLaiTypography {
  static const primary = 'Inter';
  static const numeric = 'Roboto Mono';
}

abstract final class KallaLaiSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class KallaLaiRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

class KallaLaiTokens extends ThemeExtension<KallaLaiTokens> {
  const KallaLaiTokens({
    required this.success,
    required this.warning,
    required this.error,
    required this.muted,
    required this.outline,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color muted;
  final Color outline;

  @override
  KallaLaiTokens copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? muted,
    Color? outline,
  }) => KallaLaiTokens(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    muted: muted ?? this.muted,
    outline: outline ?? this.outline,
  );

  @override
  KallaLaiTokens lerp(ThemeExtension<KallaLaiTokens>? other, double t) {
    if (other is! KallaLaiTokens) return this;
    return KallaLaiTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

abstract final class KallaLaiTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KallaLaiColors.indigo,
      primary: KallaLaiColors.indigo,
      secondary: KallaLaiColors.slate,
      surface: KallaLaiColors.surface,
      error: KallaLaiColors.crimson,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: const [
        KallaLaiTokens(
          success: KallaLaiColors.successText,
          warning: KallaLaiColors.warningText,
          error: KallaLaiColors.errorText,
          muted: KallaLaiColors.muted,
          outline: KallaLaiColors.outline,
        ),
      ],
      scaffoldBackgroundColor: KallaLaiColors.canvas,
      fontFamily: KallaLaiTypography.primary,
      appBarTheme: const AppBarTheme(
        backgroundColor: KallaLaiColors.canvas,
        foregroundColor: KallaLaiColors.slate,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KallaLaiColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          borderSide: const BorderSide(color: KallaLaiColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          borderSide: const BorderSide(color: KallaLaiColors.outline),
        ),
        contentPadding: const EdgeInsets.all(KallaLaiSpace.md),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: KallaLaiColors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: KallaLaiColors.slate,
          side: const BorderSide(color: KallaLaiColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KallaLaiColors.indigo,
      brightness: Brightness.dark,
      primary: const Color(0xFFA5B4FC),
      secondary: const Color(0xFFCBD5E1),
      surface: const Color(0xFF1E293B),
      error: const Color(0xFFF87171),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: const [
        KallaLaiTokens(
          success: Color(0xFF86EFAC),
          warning: Color(0xFFFCD34D),
          error: Color(0xFFFCA5A5),
          muted: Color(0xFFCBD5E1),
          outline: Color(0xFF334155),
        ),
      ],
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      fontFamily: KallaLaiTypography.primary,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Color(0xFFF1F5F9),
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        contentPadding: const EdgeInsets.all(KallaLaiSpace.md),
      ),
    );
  }
}
