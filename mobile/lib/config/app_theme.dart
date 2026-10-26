import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color tealPrimary;
  final Color tealLight;
  final Color emerald;
  final Color emeraldDark;
  final Color riskCritical;
  final Color riskCriticalBg;
  final Color riskHigh;
  final Color riskHighBg;
  final Color riskMedium;
  final Color riskMediumBg;
  final Color riskLow;
  final Color riskLowBg;
  final bool isDark;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.tealPrimary,
    required this.tealLight,
    required this.emerald,
    required this.emeraldDark,
    required this.riskCritical,
    required this.riskCriticalBg,
    required this.riskHigh,
    required this.riskHighBg,
    required this.riskMedium,
    required this.riskMediumBg,
    required this.riskLow,
    required this.riskLowBg,
    required this.isDark,
  });

  static const AppColors light = AppColors(
    background: Color(0xFFF8FAFC), // Slate 50
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5F9), // Slate 100
    border: Color(0xFFE2E8F0), // Slate 200
    borderSubtle: Color(0xFFCBD5E1), // Slate 300
    textPrimary: Color(0xFF0F172A), // Slate 900
    textSecondary: Color(0xFF475569), // Slate 600
    textMuted: Color(0xFF94A3B8), // Slate 400
    tealPrimary: Color(0xFF0D9488), // Teal 600
    tealLight: Color(0xFF14B8A6), // Teal 500
    emerald: Color(0xFF10B981), // Emerald 500
    emeraldDark: Color(0xFF059669), // Emerald 600
    riskCritical: Color(0xFFDC2626), // Red 600
    riskCriticalBg: Color(0xFFFEF2F2), // Red 50
    riskHigh: Color(0xFFEA580C), // Orange 600
    riskHighBg: Color(0xFFFFF7ED), // Orange 50
    riskMedium: Color(0xFFD97706), // Amber 600
    riskMediumBg: Color(0xFFFFFBEB), // Amber 50
    riskLow: Color(0xFF059669), // Emerald 600
    riskLowBg: Color(0xFFECFDF5), // Emerald 50
    isDark: false,
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF0B0F17), // Deep Slate 950
    surface: Color(0xFF131A29), // Refined Slate 900
    surfaceMuted: Color(0xFF1C2438), // Elevated Slate 800
    border: Color(0xFF222C42), // Subtle Dark Border
    borderSubtle: Color(0xFF2E3B55),
    textPrimary: Color(0xFFF8FAFC), // Crisp White-Slate
    textSecondary: Color(0xFF94A3B8), // Muted Slate 400
    textMuted: Color(0xFF64748B), // Subtle Slate 500
    tealPrimary: Color(0xFF14B8A6), // Vibrant Teal in Dark Mode
    tealLight: Color(0xFF2DD4BF),
    emerald: Color(0xFF10B981),
    emeraldDark: Color(0xFF34D399),
    riskCritical: Color(0xFFF87171), // Refined Red 400
    riskCriticalBg: Color(0x26EF4444), // 15% opacity red tint
    riskHigh: Color(0xFFFB923C), // Refined Orange 400
    riskHighBg: Color(0x26F97316),
    riskMedium: Color(0xFFFBBF24), // Refined Amber 400
    riskMediumBg: Color(0x26F59E0B),
    riskLow: Color(0xFF34D399), // Refined Emerald 400
    riskLowBg: Color(0x2610B981),
    isDark: true,
  );

  Color get primary => tealPrimary;
  Color get surfaceSubtle => surfaceMuted;
  Color get shadow =>
      isDark ? const Color(0x00000000) : const Color(0x0A0F172A);

  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? tealPrimary,
    Color? tealLight,
    Color? emerald,
    Color? emeraldDark,
    Color? riskCritical,
    Color? riskCriticalBg,
    Color? riskHigh,
    Color? riskHighBg,
    Color? riskMedium,
    Color? riskMediumBg,
    Color? riskLow,
    Color? riskLowBg,
    bool? isDark,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      tealPrimary: tealPrimary ?? this.tealPrimary,
      tealLight: tealLight ?? this.tealLight,
      emerald: emerald ?? this.emerald,
      emeraldDark: emeraldDark ?? this.emeraldDark,
      riskCritical: riskCritical ?? this.riskCritical,
      riskCriticalBg: riskCriticalBg ?? this.riskCriticalBg,
      riskHigh: riskHigh ?? this.riskHigh,
      riskHighBg: riskHighBg ?? this.riskHighBg,
      riskMedium: riskMedium ?? this.riskMedium,
      riskMediumBg: riskMediumBg ?? this.riskMediumBg,
      riskLow: riskLow ?? this.riskLow,
      riskLowBg: riskLowBg ?? this.riskLowBg,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      tealPrimary: Color.lerp(tealPrimary, other.tealPrimary, t)!,
      tealLight: Color.lerp(tealLight, other.tealLight, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      emeraldDark: Color.lerp(emeraldDark, other.emeraldDark, t)!,
      riskCritical: Color.lerp(riskCritical, other.riskCritical, t)!,
      riskCriticalBg: Color.lerp(riskCriticalBg, other.riskCriticalBg, t)!,
      riskHigh: Color.lerp(riskHigh, other.riskHigh, t)!,
      riskHighBg: Color.lerp(riskHighBg, other.riskHighBg, t)!,
      riskMedium: Color.lerp(riskMedium, other.riskMedium, t)!,
      riskMediumBg: Color.lerp(riskMediumBg, other.riskMediumBg, t)!,
      riskLow: Color.lerp(riskLow, other.riskLow, t)!,
      riskLowBg: Color.lerp(riskLowBg, other.riskLowBg, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

class AppTheme {
  // Legacy constants for backwards compatibility with tests / helpers
  static const Color navyDark = Color(0xFF0F172A);
  static const Color navyMedium = Color(0xFF1E293B);
  static const Color navyLight = Color(0xFF334155);

  static const Color tealPrimary = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFCBD5E1);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color riskCritical = Color(0xFFDC2626);
  static const Color riskCriticalBg = Color(0xFFFEF2F2);
  static const Color riskHigh = Color(0xFFEA580C);
  static const Color riskHighBg = Color(0xFFFFF7ED);
  static const Color riskMedium = Color(0xFFD97706);
  static const Color riskMediumBg = Color(0xFFFFFBEB);
  static const Color riskLow = Color(0xFF059669);
  static const Color riskLowBg = Color(0xFFECFDF5);

  static const Color statusOpen = Color(0xFFDC2626);
  static const Color statusInReview = Color(0xFFD97706);
  static const Color statusResolved = Color(0xFF059669);

  static AppColors colorsOf(BuildContext context) => AppColors.of(context);

  static ThemeData get lightTheme {
    const colors = AppColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.light(
        primary: colors.tealPrimary,
        onPrimary: Colors.white,
        secondary: colors.emeraldDark,
        onSecondary: Colors.white,
        error: colors.riskCritical,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceMuted,
        outline: colors.border,
        outlineVariant: colors.borderSubtle,
      ),
      extensions: const [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.tealPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.riskCritical, width: 1),
        ),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderSubtle, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 1,
        indicatorColor: colors.tealPrimary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.tealPrimary, size: 22);
          }
          return IconThemeData(color: colors.textMuted, size: 22);
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colors = AppColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.dark(
        primary: colors.tealPrimary,
        onPrimary: const Color(0xFF0F172A),
        secondary: colors.emeraldDark,
        onSecondary: const Color(0xFF0F172A),
        error: colors.riskCritical,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceMuted,
        outline: colors.border,
        outlineVariant: colors.borderSubtle,
      ),
      extensions: const [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.tealPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.riskCritical, width: 1),
        ),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.textPrimary,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderSubtle, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 1,
        indicatorColor: colors.tealPrimary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.tealPrimary, size: 22);
          }
          return IconThemeData(color: colors.textMuted, size: 22);
        }),
      ),
    );
  }
}
