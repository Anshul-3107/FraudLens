import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/currency_service.dart';
import '../../widgets/liquid_glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAvatarUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isAvatarUploading = true);
      final success =
          await context.read<AuthProvider>().uploadAvatar(picked.path);
      if (!mounted) return;
      setState(() => _isAvatarUploading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final err = context.read<AuthProvider>().errorMessage ??
            'Failed to upload profile picture';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAvatarUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isAvatarUploading = true);
    final success = await context.read<AuthProvider>().deleteAvatar();
    if (!mounted) return;
    setState(() => _isAvatarUploading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture removed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAvatarOptionsSheet(AppColors colors, bool hasAvatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colors.primary,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: colors.primary,
                ),
                title: Text(
                  'Take a Photo',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              if (hasAvatar) ...[
                Divider(height: 1, color: colors.border),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.riskCritical,
                  ),
                  title: Text(
                    'Remove Picture',
                    style: TextStyle(
                      color: colors.riskCritical,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final user = authProvider.user;

    final isEffectiveDark = themeProvider.isEffectiveDark(context);
    final hasAvatar =
        user?.avatarUrl != null && user!.avatarUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Account & Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Card
            LiquidGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              borderRadius: 16,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isAvatarUploading
                        ? null
                        : () => _showAvatarOptionsSheet(colors, hasAvatar),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.isDark
                                ? colors.surfaceMuted
                                : const Color(0xFFF1F5F9),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.4),
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: _isAvatarUploading
                                ? Center(
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: colors.primary,
                                      ),
                                    ),
                                  )
                                : hasAvatar
                                    ? Image.network(
                                        user.avatarUrl!,
                                        width: 82,
                                        height: 82,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Center(
                                          child: Text(
                                            (user.username.isNotEmpty)
                                                ? user.username
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              color: colors.tealPrimary,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          (user?.username.isNotEmpty == true)
                                              ? user!.username
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            color: colors.tealPrimary,
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                        // Camera Action Badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.username ?? 'Analyst User',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Clean "FraudLens AI Shield Active" Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.emerald.withValues(
                        alpha: colors.isDark ? 0.12 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.emerald.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.emerald,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'FraudLens AI Shield Active',
                          style: TextStyle(
                            color: colors.isDark
                                ? colors.emeraldDark
                                : colors.emerald,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap photo to customize avatar',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Appearance & Theme Selector Card
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.violet.withValues(
                            alpha: colors.isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.violet.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          size: 19,
                          color: colors.violet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance & Theme',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose interface appearance preference',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

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

            const SizedBox(height: 16),

            // Regional Currency & Conversion Card
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.cyan.withValues(
                            alpha: colors.isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.cyan.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.public_rounded,
                          size: 19,
                          color: colors.cyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Region & Regional Currency',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live fluctuating exchange rates from backend',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mode selection: Auto-Detect vs Choose Region
                  SegmentedButton<CurrencyMode>(
                    segments: [
                      ButtonSegment(
                        value: CurrencyMode.auto,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                        label: Text(
                          'Auto-Detect (${currencyProvider.detectedCurrency})',
                        ),
                      ),
                      const ButtonSegment(
                        value: CurrencyMode.manual,
                        icon: Icon(Icons.travel_explore_rounded, size: 15),
                        label: Text('Choose Region'),
                      ),
                    ],
                    selected: {currencyProvider.mode},
                    onSelectionChanged: (newSelection) {
                      if (newSelection.first == CurrencyMode.auto) {
                        currencyProvider.setAutoMode();
                      } else {
                        currencyProvider.selectRegion(
                          currencyProvider.activeRegionCode,
                        );
                      }
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

                  if (!currencyProvider.isAutoMode) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Select Operating Region:',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: CurrencyService.supportedRegions.map((region) {
                        final isSelected =
                            currencyProvider.activeRegionCode ==
                            region.countryCode;
                        final curr =
                            CurrencyService.supportedCurrencies[region
                                .currencyCode];
                        return ChoiceChip(
                          label: Text(
                            '${region.flagEmoji} ${region.name} (${curr?.symbol ?? region.currencyCode})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              currencyProvider.selectRegion(region.countryCode),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.isDark
                          ? const Color(0xFF082F49).withValues(alpha: 0.35)
                          : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.cyan.withValues(
                          alpha: colors.isDark ? 0.3 : 0.4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: colors.cyan.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.currency_exchange_rounded,
                            size: 15,
                            color: colors.cyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            currencyProvider.isConvertedFromUsd
                                ? 'Live FX: 1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency}'
                                    '${currencyProvider.ratesLastUpdated != null ? " • Synced ${currencyProvider.ratesLastUpdated}" : ""}'
                                : 'Active Base Currency: USD (1:1 standard)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.isDark
                                  ? colors.cyan
                                  : const Color(0xFF0284C7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: currencyProvider.isSyncingRates
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.cyan,
                                  ),
                                )
                              : Icon(
                                  Icons.sync_rounded,
                                  size: 16,
                                  color: colors.cyan,
                                ),
                          tooltip: 'Sync Live Exchange Rates',
                          onPressed: currencyProvider.isSyncingRates
                              ? null
                              : () => currencyProvider.syncRatesFromBackend(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Session & Security Card
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.rose.withValues(
                            alpha: colors.isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.rose.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 19,
                          color: colors.rose,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session & Security',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Token revocation & local session flush',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
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
                    icon: Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: colors.riskCritical,
                    ),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: colors.riskCritical,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: colors.riskCritical.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: colors.riskCritical.withValues(
                        alpha: colors.isDark ? 0.1 : 0.05,
                      ),
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
