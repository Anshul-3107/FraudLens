import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'providers/alert_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/card_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/investigation_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/navigation/app_shell.dart';
import 'widgets/loading_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => InvestigationProvider()),
        ChangeNotifierProvider(create: (_) => CardProvider()),
      ],
      child: const FraudLensApp(),
    ),
  );
}

class FraudLensApp extends StatelessWidget {
  const FraudLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'FraudLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isInitializing) {
            return const Scaffold(
              body: FintechLoadingIndicator(label: 'Initializing FraudLens...'),
            );
          }
          if (authProvider.isAuthenticated) {
            return const AppShell();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
