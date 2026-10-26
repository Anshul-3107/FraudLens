import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _testingHealth = false;
  String? _healthResult;
  bool _isHealthy = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiConfig.baseUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testHealth() async {
    setState(() {
      _testingHealth = true;
      _healthResult = null;
    });

    try {
      final res = await AuthService().checkHealth();
      if (mounted) {
        setState(() {
          _testingHealth = false;
          _isHealthy = res['status'] == 'ok';
          _healthResult =
              'Backend Online: ${res['service']} (Status: ${res['status']})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testingHealth = false;
          _isHealthy = false;
          _healthResult = 'Health check failed: $e';
        });
      }
    }
  }

  Future<void> _saveUrl() async {
    await ApiConfig.setBaseUrl(_urlController.text);
    if (mounted) {
      final colors = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API base URL updated to ${ApiConfig.baseUrl}'),
          backgroundColor: colors.emeraldDark,
        ),
      );
      _testHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;

    final isEffectiveDark = themeProvider.isEffectiveDark(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Account & Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.isDark
                          ? colors.surfaceMuted
                          : colors.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (user?.username.isNotEmpty == true)
                            ? user!.username.substring(0, 1).toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: colors.tealPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.username ?? 'Analyst User',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email.isNotEmpty == true
                        ? user!.email
                        : 'No email configured',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: user?.isStaff == true
                              ? colors.riskCriticalBg
                              : colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: user?.isStaff == true
                                ? colors.riskCritical.withValues(alpha: 0.25)
                                : colors.border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          user?.isStaff == true
                              ? 'Staff / Superuser'
                              : 'Standard User',
                          style: TextStyle(
                            color: user?.isStaff == true
                                ? colors.riskCritical
                                : colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.tealPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colors.tealPrimary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${user?.cardCount ?? 0} Visible Cards',
                          style: TextStyle(
                            color: colors.tealPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Appearance & Theme Selector Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance & Theme',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose interface appearance or sync with your operating system preference.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  const SizedBox(height: 14),

                  // Segmented Theme Selector
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 16),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 16),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 16),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeProvider.setThemeMode(newSelection.first);
                    },
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    themeProvider.themeMode == ThemeMode.system
                        ? 'Following OS preference (currently ${isEffectiveDark ? "Dark" : "Light"} Mode).'
                        : themeProvider.themeMode == ThemeMode.dark
                        ? 'Dark mode active (overriding OS preference).'
                        : 'Light mode active (overriding OS preference).',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Connection Configuration Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Backend Endpoint Configuration',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure host address for Django REST backend. Supports Android emulator 10.0.2.2 or desktop localhost.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Server Base URL',
                      hintText: 'http://127.0.0.1:8000',
                      prefixIcon: Icon(Icons.link_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text(
                          'Localhost (127.0.0.1:8000)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setState(
                          () => _urlController.text = 'http://127.0.0.1:8000',
                        ),
                      ),
                      ActionChip(
                        label: const Text(
                          'Android (10.0.2.2:8000)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => setState(
                          () => _urlController.text = 'http://10.0.2.2:8000',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testingHealth ? null : _testHealth,
                          icon: _testingHealth
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.favorite_rounded, size: 15),
                          label: const Text('Health Check'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveUrl,
                          icon: const Icon(Icons.save_rounded, size: 15),
                          label: const Text('Save URL'),
                        ),
                      ),
                    ],
                  ),
                  if (_healthResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isHealthy
                            ? colors.riskLowBg
                            : colors.riskCriticalBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isHealthy
                              ? colors.riskLow.withValues(alpha: 0.25)
                              : colors.riskCritical.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _healthResult!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _isHealthy
                              ? colors.emeraldDark
                              : colors.riskCritical,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Logout Action Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Session & Security',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Signing out calls /api/auth/logout/ to revoke your authentication token server-side and flushes local credentials.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to end your current session and revoke your token?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.riskCritical,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.riskCritical,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
