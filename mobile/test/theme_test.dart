import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/user.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/currency_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/screens/profile/profile_screen.dart';
import 'package:fraudlens/services/auth_service.dart';

class _MockAuthService extends AuthService {
  @override
  Future<UserMe> getMe() async => UserMe(
    id: 1,
    username: 'anshul',
    email: 'anshul@example.com',
    isStaff: false,
    cardCount: 1,
  );
}

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
      expect(darkColors.background, const Color(0xFF0A0A0A));
      expect(darkColors.surface, const Color(0xFF141414));
      expect(darkColors.tealPrimary, const Color(0xFF3B82F6));
      expect(darkColors.textPrimary, const Color(0xFFFAFAFA));
    });

    test('AppColors.light returns crisp light surfaces and border lines', () {
      final lightColors = AppColors.light;

      expect(lightColors.isDark, isFalse);
      expect(lightColors.background, const Color(0xFFF7F7F8));
      expect(lightColors.surface, Colors.white);
      expect(lightColors.tealPrimary, const Color(0xFF2563EB));
      expect(lightColors.textPrimary, const Color(0xFF111113));
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

    test('ThemeProvider initializes with system mode (device default) and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();

      expect(provider.themeMode, ThemeMode.system);

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);

      final restoredProvider = ThemeProvider();
      await restoredProvider.initialize();
      expect(restoredProvider.themeMode, ThemeMode.light);
    });

    testWidgets(
      'AppColors.of(context) dynamically adapts to dark and light contexts',
      (tester) async {
        late AppColors capturedDarkColors;
        late AppColors capturedLightColors;

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
      'renders accessible 3-way SegmentedButton for System, Light, Dark on 320px without overflow',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final themeProvider = ThemeProvider();
        final authProvider = AuthProvider(authService: _MockAuthService());
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);

        await tester.tap(find.text('Dark'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(themeProvider.themeMode, ThemeMode.dark);

        await tester.tap(find.text('Light'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(themeProvider.themeMode, ThemeMode.light);

        await tester.tap(find.text('System'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(themeProvider.themeMode, ThemeMode.system);
      },
    );
  });
}
