import 'package:flutter/cupertino.dart';
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
  final Color indigo;
  final Color indigoBg;
  final Color violet;
  final Color violetBg;
  final Color cyan;
  final Color cyanBg;
  final Color amber;
  final Color amberBg;
  final Color rose;
  final Color roseBg;
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
    required this.indigo,
    required this.indigoBg,
    required this.violet,
    required this.violetBg,
    required this.cyan,
    required this.cyanBg,
    required this.amber,
    required this.amberBg,
    required this.rose,
    required this.roseBg,
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
    indigo: Color(0xFF4F46E5), // Indigo 600
    indigoBg: Color(0xFFEEF2FF), // Indigo 50
    violet: Color(0xFF7C3AED), // Violet 600
    violetBg: Color(0xFFF5F3FF), // Violet 50
    cyan: Color(0xFF0284C7), // Sky 600
    cyanBg: Color(0xFFF0F9FF), // Sky 50
    amber: Color(0xFFD97706), // Amber 600
    amberBg: Color(0xFFFFFBEB), // Amber 50
    rose: Color(0xFFE11D48), // Rose 600
    roseBg: Color(0xFFFFF1F2), // Rose 50
    isDark: false,
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF0F0F11), // Clean deep matte charcoal (pure dark)
    surface: Color(0xFF18181B), // Zinc 900 card surface
    surfaceMuted: Color(0xFF222226), // Elevated zinc container
    border: Color(0xFF27272A), // Zinc 800 clean hairline border
    borderSubtle: Color(0xFF323238), // Zinc 750 border
    textPrimary: Color(0xFFFAFAFA), // Crisp pure off-white
    textSecondary: Color(0xFFA1A1AA), // Zinc 400 neutral secondary
    textMuted: Color(0xFF71717A), // Zinc 500 neutral muted
    tealPrimary: Color(0xFF14B8A6), // Vibrant Teal
    tealLight: Color(0xFF2DD4BF),
    emerald: Color(0xFF10B981),
    emeraldDark: Color(0xFF34D399),
    riskCritical: Color(0xFFEF4444), // Clean red
    riskCriticalBg: Color(0x24EF4444),
    riskHigh: Color(0xFFF97316),
    riskHighBg: Color(0x24F97316),
    riskMedium: Color(0xFFF59E0B),
    riskMediumBg: Color(0x24F59E0B),
    riskLow: Color(0xFF10B981),
    riskLowBg: Color(0x2410B981),
    indigo: Color(0xFF818CF8), // Indigo 400
    indigoBg: Color(0x24818CF8),
    violet: Color(0xFFA78BFA), // Violet 400
    violetBg: Color(0x24A78BFA),
    cyan: Color(0xFF38BDF8), // Sky 400
    cyanBg: Color(0x2438BDF8),
    amber: Color(0xFFFBBF24), // Amber 400
    amberBg: Color(0x24FBBF24),
    rose: Color(0xFFFB7185), // Rose 400
    roseBg: Color(0x24FB7185),
    isDark: true,
  );

  Color get primary => tealPrimary;
  Color get surfaceSubtle => surfaceMuted;
  Color get shadow =>
      isDark ? const Color(0x38000000) : const Color(0x0A0F172A);

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.22)
              : const Color(0x0A0F172A),
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ];

  Color getCategoryColor(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('dining')) return amber;
    if (cat.contains('grocery')) return emerald;
    if (cat.contains('shop')) return violet;
    if (cat.contains('gas') || cat.contains('transport') || cat.contains('travel')) return cyan;
    if (cat.contains('entertain')) return rose;
    if (cat.contains('health') || cat.contains('fitness')) return const Color(0xFFEC4899);
    if (cat.contains('home') || cat.contains('utilities')) return indigo;
    return tealPrimary;
  }

  Color getCategoryBg(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('dining')) return amberBg;
    if (cat.contains('grocery')) return riskLowBg;
    if (cat.contains('shop')) return violetBg;
    if (cat.contains('gas') || cat.contains('transport') || cat.contains('travel')) return cyanBg;
    if (cat.contains('entertain')) return roseBg;
    if (cat.contains('health') || cat.contains('fitness')) {
      return isDark ? const Color(0x24EC4899) : const Color(0xFFFDF2F8);
    }
    if (cat.contains('home') || cat.contains('utilities')) return indigoBg;
    return isDark ? const Color(0x2414B8A6) : const Color(0xFFCCFBF1);
  }

  IconData getCategoryIcon(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('dining')) return Icons.restaurant_rounded;
    if (cat.contains('grocery')) return Icons.local_grocery_store_rounded;
    if (cat.contains('shop')) return Icons.shopping_bag_rounded;
    if (cat.contains('gas') || cat.contains('transport')) return Icons.local_gas_station_rounded;
    if (cat.contains('travel')) return Icons.flight_takeoff_rounded;
    if (cat.contains('entertain')) return Icons.movie_creation_rounded;
    if (cat.contains('health') || cat.contains('fitness')) return Icons.fitness_center_rounded;
    if (cat.contains('home')) return Icons.home_rounded;
    return Icons.receipt_long_rounded;
  }

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
    Color? indigo,
    Color? indigoBg,
    Color? violet,
    Color? violetBg,
    Color? cyan,
    Color? cyanBg,
    Color? amber,
    Color? amberBg,
    Color? rose,
    Color? roseBg,
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
      indigo: indigo ?? this.indigo,
      indigoBg: indigoBg ?? this.indigoBg,
      violet: violet ?? this.violet,
      violetBg: violetBg ?? this.violetBg,
      cyan: cyan ?? this.cyan,
      cyanBg: cyanBg ?? this.cyanBg,
      amber: amber ?? this.amber,
      amberBg: amberBg ?? this.amberBg,
      rose: rose ?? this.rose,
      roseBg: roseBg ?? this.roseBg,
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
      indigo: Color.lerp(indigo, other.indigo, t)!,
      indigoBg: Color.lerp(indigoBg, other.indigoBg, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      violetBg: Color.lerp(violetBg, other.violetBg, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      cyanBg: Color.lerp(cyanBg, other.cyanBg, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberBg: Color.lerp(amberBg, other.amberBg, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      roseBg: Color.lerp(roseBg, other.roseBg, t)!,
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.dark(
        primary: colors.tealPrimary,
        onPrimary: const Color(0xFF0F0F11),
        secondary: colors.emeraldDark,
        onSecondary: const Color(0xFF0F0F11),
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
          foregroundColor: const Color(0xFF0F0F11),
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
