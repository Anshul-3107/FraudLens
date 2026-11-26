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
    background: Color(0xFFF7F7F8), // Crisp neutral off-white
    surface: Color(0xFFFFFFFF), // Pure white elevated card
    surfaceMuted: Color(0xFFF1F2F4), // Neutral light pill fill
    border: Color(0xFFE4E5E9), // Clean hairline border
    borderSubtle: Color(0xFFEEEEF1), // Ultra-light inner divider
    textPrimary: Color(0xFF111113), // Deep neutral ink
    textSecondary: Color(0xFF52525B), // Neutral Zinc 600
    textMuted: Color(0xFF71717A), // Neutral Zinc 500
    tealPrimary: Color(0xFF2563EB), // Crisp Fintech Cobalt Blue
    tealLight: Color(0xFF3B82F6), // Bright Cobalt
    emerald: Color(0xFF16A34A), // Clean positive green (credits/safe only)
    emeraldDark: Color(0xFF15803D),
    riskCritical: Color(0xFFDC2626), // Alert Red
    riskCriticalBg: Color(0xFFFEF2F2),
    riskHigh: Color(0xFFEA580C), // High-risk Orange
    riskHighBg: Color(0xFFFFF7ED),
    riskMedium: Color(0xFFD97706), // Warning Amber
    riskMediumBg: Color(0xFFFFFBEB),
    riskLow: Color(0xFF16A34A),
    riskLowBg: Color(0xFFF0FDF4),
    indigo: Color(0xFF4F46E5),
    indigoBg: Color(0xFFEEF2FF),
    violet: Color(0xFF7C3AED),
    violetBg: Color(0xFFF5F3FF),
    cyan: Color(0xFF0284C7),
    cyanBg: Color(0xFFE0F2FE),
    amber: Color(0xFFD97706),
    amberBg: Color(0xFFFEF3C7),
    rose: Color(0xFFE11D48),
    roseBg: Color(0xFFFFE4E6),
    isDark: false,
  );

  static const AppColors dark = AppColors(
    background: Color(
      0xFF0A0A0A,
    ), // True neutral pure dark canvas (no blue tint)
    surface: Color(0xFF141414), // Pure neutral charcoal surface
    surfaceMuted: Color(0xFF1F1F21), // Neutral elevated fill
    border: Color(0xFF262628), // Neutral hairline border
    borderSubtle: Color(0xFF1C1C1E), // Quiet inner hairline
    textPrimary: Color(0xFFFAFAFA), // Crisp pure off-white
    textSecondary: Color(0xFFA1A1A6), // Neutral gray secondary
    textMuted: Color(0xFF737378), // Neutral gray muted
    tealPrimary: Color(0xFF3B82F6), // Vibrant Cobalt Blue
    tealLight: Color(0xFF60A5FA), // Soft Sky Cobalt for active text/icons
    emerald: Color(0xFF22C55E), // Fresh positive green
    emeraldDark: Color(0xFF4ADE80),
    riskCritical: Color(0xFFF87171),
    riskCriticalBg: Color(0x22EF4444),
    riskHigh: Color(0xFFFB923C),
    riskHighBg: Color(0x22F97316),
    riskMedium: Color(0xFFFBBF24),
    riskMediumBg: Color(0x22F59E0B),
    riskLow: Color(0xFF4ADE80),
    riskLowBg: Color(0x2222C55E),
    indigo: Color(0xFF818CF8),
    indigoBg: Color(0x226366F1),
    violet: Color(0xFFA78BFA),
    violetBg: Color(0x228B5CF6),
    cyan: Color(0xFF38BDF8),
    cyanBg: Color(0x220EA5E9),
    amber: Color(0xFFFBBF24),
    amberBg: Color(0x22F59E0B),
    rose: Color(0xFFFB7185),
    roseBg: Color(0x22F43F5E),
    isDark: true,
  );

  Color get primary => tealPrimary;
  Color get primarySoft => tealLight;
  Color get primaryBg => tealPrimary.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get surfaceSubtle => surfaceMuted;
  Color get shadow =>
      isDark ? const Color(0x00000000) : const Color(0x08000000);

  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ];

  /// Human-readable category name for everyday banking screens.
  static String friendlyCategoryName(String rawCategory) {
    switch (rawCategory.toLowerCase().trim()) {
      case 'entertainment':
        return 'Entertainment';
      case 'food_dining':
        return 'Food & Dining';
      case 'gas_transport':
        return 'Transport & Fuel';
      case 'grocery_net':
        return 'Online Groceries';
      case 'grocery_pos':
        return 'Groceries';
      case 'health_fitness':
        return 'Health & Fitness';
      case 'home':
        return 'Home & Utilities';
      case 'kids_pets':
        return 'Family & Pets';
      case 'misc_net':
        return 'Online Payments';
      case 'misc_pos':
        return 'General Purchases';
      case 'personal_care':
        return 'Personal Care';
      case 'shopping_net':
        return 'Online Shopping';
      case 'shopping_pos':
        return 'Retail Shopping';
      case 'travel':
        return 'Travel';
      default:
        final words = rawCategory
            .replaceAll('_', ' ')
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join(' ');
        return words.isEmpty ? 'Other' : words;
    }
  }

  /// Tasteful GPay-inspired category color accents for instant visual scanning.
  Color getCategoryColor(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('dining')) return amber;
    if (cat.contains('grocery')) return emerald;
    if (cat.contains('shop')) return violet;
    if (cat.contains('gas') ||
        cat.contains('transport') ||
        cat.contains('travel')) {
      return cyan;
    }
    if (cat.contains('entertain')) return rose;
    if (cat.contains('health') || cat.contains('fitness')) {
      return isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
    }
    if (cat.contains('home') || cat.contains('utilities')) return indigo;
    return isDark ? tealLight : tealPrimary;
  }

  Color getCategoryBg(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('dining')) return amberBg;
    if (cat.contains('grocery')) return riskLowBg;
    if (cat.contains('shop')) return violetBg;
    if (cat.contains('gas') ||
        cat.contains('transport') ||
        cat.contains('travel')) {
      return cyanBg;
    }
    if (cat.contains('entertain')) return roseBg;
    if (cat.contains('health') || cat.contains('fitness')) {
      return isDark ? const Color(0x22EC4899) : const Color(0xFFFCE7F3);
    }
    if (cat.contains('home') || cat.contains('utilities')) return indigoBg;
    return primaryBg;
  }

  IconData getCategoryIcon(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('dining')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('grocery')) return Icons.shopping_basket_rounded;
    if (cat.contains('shop')) return Icons.shopping_bag_rounded;
    if (cat.contains('gas') || cat.contains('transport')) {
      return Icons.directions_car_rounded;
    }
    if (cat.contains('travel')) return Icons.flight_takeoff_rounded;
    if (cat.contains('entertain')) return Icons.movie_rounded;
    if (cat.contains('health') || cat.contains('fitness')) {
      return Icons.favorite_rounded;
    }
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
  // Legacy constants preserved for backwards compatibility
  static const Color navyDark = Color(0xFF0A0A0A);
  static const Color navyMedium = Color(0xFF141414);
  static const Color navyLight = Color(0xFF262628);

  static const Color tealPrimary = Color(0xFF2563EB);
  static const Color tealLight = Color(0xFF3B82F6);
  static const Color emerald = Color(0xFF16A34A);
  static const Color emeraldDark = Color(0xFF15803D);

  static const Color backgroundLight = Color(0xFFF7F7F8);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F2F4);
  static const Color borderLight = Color(0xFFE4E5E9);
  static const Color borderSubtle = Color(0xFFEEEEF1);
  static const Color textPrimary = Color(0xFF111113);
  static const Color textSecondary = Color(0xFF52525B);
  static const Color textMuted = Color(0xFF71717A);

  static const Color riskCritical = Color(0xFFDC2626);
  static const Color riskCriticalBg = Color(0xFFFEF2F2);
  static const Color riskHigh = Color(0xFFEA580C);
  static const Color riskHighBg = Color(0xFFFFF7ED);
  static const Color riskMedium = Color(0xFFD97706);
  static const Color riskMediumBg = Color(0xFFFFFBEB);
  static const Color riskLow = Color(0xFF16A34A);
  static const Color riskLowBg = Color(0xFFF0FDF4);

  static const Color statusOpen = Color(0xFFDC2626);
  static const Color statusInReview = Color(0xFFD97706);
  static const Color statusResolved = Color(0xFF16A34A);

  static AppColors colorsOf(BuildContext context) => AppColors.of(context);

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static ThemeData get lightTheme => _buildTheme(AppColors.light);
  static ThemeData get darkTheme => _buildTheme(AppColors.dark);

  static ThemeData _buildTheme(AppColors colors) {
    final isDark = colors.isDark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: colors.tealPrimary,
            onPrimary: Colors.white,
            secondary: colors.tealLight,
            onSecondary: Colors.white,
            error: colors.riskCritical,
            onError: Colors.white,
            surface: colors.surface,
            onSurface: colors.textPrimary,
            surfaceContainerHighest: colors.surfaceMuted,
            outline: colors.border,
            outlineVariant: colors.borderSubtle,
          )
        : ColorScheme.light(
            primary: colors.tealPrimary,
            onPrimary: Colors.white,
            secondary: colors.tealLight,
            onSecondary: Colors.white,
            error: colors.riskCritical,
            onError: Colors.white,
            surface: colors.surface,
            onSurface: colors.textPrimary,
            surfaceContainerHighest: colors.surfaceMuted,
            outline: colors.border,
            outlineVariant: colors.borderSubtle,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
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
      colorScheme: colorScheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colors.surfaceMuted : colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.tealPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.riskCritical, width: 1),
        ),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.tealPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.tealPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border, width: 1),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 0.8,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: colors.tealPrimary.withValues(
          alpha: isDark ? 0.20 : 0.12,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? colors.tealLight : colors.tealPrimary,
              letterSpacing: -0.1,
            );
          }
          return TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
            letterSpacing: -0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? colors.tealLight : colors.tealPrimary,
              size: 22,
            );
          }
          return IconThemeData(color: colors.textMuted, size: 22);
        }),
      ),
    );
  }
}
