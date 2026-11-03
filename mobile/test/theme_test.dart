import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/currency_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Theme System & AppColors Tests', () {
    test('AppColors.dark returns appropriate dark surfaces and borders', () {
      final darkColors = AppColors.dark;

      expect(darkColors.isDark, isTrue);
      expect(darkColors.background, const Color(0xFF0B0F17)); // Deep Slate 950
      expect(darkColors.surface, const Color(0xFF131A29)); // Refined Slate 900
      expect(darkColors.tealPrimary, const Color(0xFF14B8A6)); // Vibrant Teal
      expect(
        darkColors.textPrimary,
        const Color(0xFFF8FAFC),
      ); // Crisp White-Slate
    });

    test('AppColors.light returns crisp light surfaces and border lines', () {
      final lightColors = AppColors.light;

      expect(lightColors.isDark, isFalse);
      expect(lightColors.background, const Color(0xFFF8FAFC)); // Slate 50
      expect(lightColors.surface, Colors.white);
      expect(lightColors.tealPrimary, const Color(0xFF0D9488)); // Teal 600
      expect(lightColors.textPrimary, const Color(0xFF0F172A)); // Slate 900
    });

    test('AppTheme creates valid ThemeData with AppColors extension', () {
      final darkTheme = AppTheme.darkTheme;
      final lightTheme = AppTheme.lightTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(lightTheme.brightness, Brightness.light);

      final darkAppColors = darkTheme.extension<AppColors>();
      final lightAppColors = lightTheme.extension<AppColors>();

      expect(darkAppColors, isNotNull);
      expect(lightAppColors, isNotNull);
      expect(darkAppColors!.isDark, isTrue);
      expect(lightAppColors!.isDark, isFalse);
    });

    test(
      'ThemeProvider initializes with system mode and persists changes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = ThemeProvider();

        expect(provider.themeMode, ThemeMode.system);

        // Change to dark mode and verify
        await provider.setThemeMode(ThemeMode.dark);
        expect(provider.themeMode, ThemeMode.dark);

        // Change to light mode and verify
        await provider.setThemeMode(ThemeMode.light);
        expect(provider.themeMode, ThemeMode.light);

        // Re-initialize a new provider to test persistence restoration
        final restoredProvider = ThemeProvider();
        await restoredProvider.initialize();
        expect(restoredProvider.themeMode, ThemeMode.light);
      },
    );

    testWidgets(
      'AppColors.of(context) dynamically adapts to dark and light contexts',
      (tester) async {
        late AppColors capturedDarkColors;
        late AppColors capturedLightColors;

        // Pump dark theme context
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                capturedDarkColors = AppColors.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(capturedDarkColors.isDark, isTrue);

        // Pump light theme context
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                capturedLightColors = AppColors.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(capturedLightColors.isDark, isFalse);
      },
    );
  });

  group('ProfileScreen Theme Selector Widget Test', () {
    testWidgets(
      'renders accessible 3-way SegmentedButton for System, Light, Dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final themeProvider = ThemeProvider();
        final authProvider = AuthProvider();
        final currencyProvider = CurrencyProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<CurrencyProvider>.value(
                value: currencyProvider,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.system,
              home: const ProfileScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Appearance section and segmented buttons
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);

        // Tap 'Dark' button
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(themeProvider.themeMode, ThemeMode.dark);

        // Tap 'Light' button
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        expect(themeProvider.themeMode, ThemeMode.light);

        // Tap 'System' button
        await tester.tap(find.text('System'));
        await tester.pumpAndSettle();
        expect(themeProvider.themeMode, ThemeMode.system);
      },
    );
  });
}
