import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Theme System & AppColors Tests', () {
    test(
      'AppColors light and dark tokens provide consistent semantic values',
      () {
        final light = AppColors.light;
        final dark = AppColors.dark;

        // Ensure contrasts and backgrounds are appropriate
        expect(light.background, isNot(equals(dark.background)));
        expect(light.surface, isNot(equals(dark.surface)));
        expect(light.textPrimary, isNot(equals(dark.textPrimary)));

        // Semantic risk colors exist on both
        expect(light.riskCritical, isNotNull);
        expect(dark.riskCritical, isNotNull);
        expect(light.riskLow, isNotNull);
        expect(dark.riskLow, isNotNull);
      },
    );

    test('AppTheme creates valid ThemeData with AppColors extension', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      expect(lightTheme.brightness, Brightness.light);
      expect(darkTheme.brightness, Brightness.dark);

      final lightColors = lightTheme.extension<AppColors>();
      final darkColors = darkTheme.extension<AppColors>();

      expect(lightColors, isNotNull);
      expect(darkColors, isNotNull);
      expect(lightColors!.primary, isNotNull);
      expect(darkColors!.primary, isNotNull);
    });
  });

  group('ThemeProvider State & Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Defaults to ThemeMode.system when no preference is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isSystemDefault, isTrue);
      expect(provider.isDarkMode, isFalse);
    });

    test('Restores dark mode preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'fraudlens_theme_mode': 'dark'});

      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);
      expect(provider.isSystemDefault, isFalse);
    });

    test('Restores light mode preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'fraudlens_theme_mode': 'light'});

      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, isFalse);
      expect(provider.isSystemDefault, isFalse);
    });

    test('setThemeMode updates state and persists choice to storage', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 10));

      // Switch to dark
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fraudlens_theme_mode'), 'dark');

      // Switch to light
      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(prefs.getString('fraudlens_theme_mode'), 'light');

      // Switch to system
      await provider.setThemeMode(ThemeMode.system);
      expect(provider.themeMode, ThemeMode.system);
      expect(prefs.getString('fraudlens_theme_mode'), 'system');
    });
  });

  group('ProfileScreen Theme Selector Widget Test', () {
    testWidgets(
      'renders accessible 3-way SegmentedButton for System, Light, Dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final themeProvider = ThemeProvider();
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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
      },
    );
  });
}
