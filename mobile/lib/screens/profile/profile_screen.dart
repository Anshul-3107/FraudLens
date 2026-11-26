import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/currency_service.dart';
import '../../services/notification_listener_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAvatarUploading = false;
  bool _showRegionOptions = false;
  bool? _notifGranted;
  bool? _smsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
      _loadPermissions();
    });
  }

  Future<void> _loadPermissions() async {
    final notif = await NotificationListenerService.instance
        .isPermissionGranted();
    final sms = await NotificationListenerService.instance
        .isSmsPermissionGranted();
    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _smsGranted = sms;
      });
    }
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
      final success = await context.read<AuthProvider>().uploadAvatar(
        picked.path,
      );
      if (!mounted) return;
      setState(() => _isAvatarUploading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final err =
            context.read<AuthProvider>().errorMessage ??
            'Failed to upload photo';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAvatarUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
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
          content: Text('Profile photo removed'),
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
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colors.primary,
                ),
                title: Text(
                  'Choose from gallery',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: colors.primary),
                title: Text(
                  'Take a photo',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              if (hasAvatar) ...[
                Divider(height: 1, color: colors.borderSubtle),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.riskCritical,
                  ),
                  title: Text(
                    'Remove photo',
                    style: TextStyle(color: colors.riskCritical),
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

  Widget _buildIconBadge({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    double size = 34,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: iconColor),
    );
  }

  Widget _buildPermissionTile({
    required AppColors colors,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool? granted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _buildIconBadge(
        icon: icon,
        iconColor: iconColor,
        bgColor: iconBg,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (granted != null)
            Text(
              granted ? 'On' : 'Off',
              style: TextStyle(
                color: granted ? colors.riskLow : colors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: colors.textMuted),
        ],
      ),
      onTap: onTap,
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
    final activeRegion = currencyProvider.activeRegionInfo;
    final activeCurr = currencyProvider.activeCurrencyInfo;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Account & Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Identity Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 22,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
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
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.surfaceMuted,
                                border: Border.all(
                                  color: colors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: _isAvatarUploading
                                    ? Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: colors.primary,
                                          ),
                                        ),
                                      )
                                    : hasAvatar
                                    ? Image.network(
                                        user.avatarUrl!,
                                        headers: ApiClient.instance.authHeaders,
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Center(
                                          child: Text(
                                            user.username.isNotEmpty
                                                ? user.username
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
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
                                            color: colors.textPrimary,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: colors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.border),
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 13,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.username ?? 'Account',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user != null && user.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Tap photo to change',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Appearance & Theme (Defaults to System / Device Theme)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIconBadge(
                            icon: Icons.palette_outlined,
                            iconColor: colors.primarySoft,
                            bgColor: colors.primaryBg,
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
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  themeProvider.themeMode == ThemeMode.system
                                      ? 'Following device setting (currently ${isEffectiveDark ? "Dark" : "Light"}). '
                                      : themeProvider.themeMode ==
                                            ThemeMode.dark
                                      ? 'Always dark.'
                                      : 'Always light.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(
                              Icons.brightness_auto_outlined,
                              size: 16,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('System', maxLines: 1),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined, size: 16),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Light', maxLines: 1),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined, size: 16),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Dark', maxLines: 1),
                            ),
                          ),
                        ],
                        selected: {themeProvider.themeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          themeProvider.setThemeMode(newSelection.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Currency & Region Settings (No squeezed SegmentedButton at 320px)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _buildIconBadge(
                            icon: Icons.currency_exchange_rounded,
                            iconColor: colors.cyan,
                            bgColor: colors.cyanBg,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Currency & Region',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${activeRegion.flagEmoji} ${activeRegion.name} (${activeCurr.symbol} ${currencyProvider.activeCurrency}) · ${currencyProvider.isAutoMode ? 'Auto-detected' : 'Manual'}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _showRegionOptions = !_showRegionOptions,
                            ),
                            child: Text(_showRegionOptions ? 'Done' : 'Change'),
                          ),
                        ],
                      ),

                      if (_showRegionOptions) ...[
                        const SizedBox(height: 10),
                        Divider(color: colors.borderSubtle, height: 1),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(
                                'Auto (${currencyProvider.detectedCurrency})',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: currencyProvider.isAutoMode,
                              onSelected: (_) => currencyProvider.setAutoMode(),
                            ),
                            ...CurrencyService.supportedRegions.map((region) {
                              final isSelected =
                                  !currencyProvider.isAutoMode &&
                                  currencyProvider.activeRegionCode ==
                                      region.countryCode;
                              final curr = CurrencyService
                                  .supportedCurrencies[region.currencyCode];
                              return ChoiceChip(
                                label: Text(
                                  '${region.flagEmoji} ${region.name} (${curr?.symbol ?? region.currencyCode})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: isSelected,
                                onSelected: (_) => currencyProvider
                                    .selectRegion(region.countryCode),
                              );
                            }),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currencyProvider.isConvertedFromUsd
                                    ? '1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency}'
                                          '${currencyProvider.ratesLastUpdated != null ? " · Updated ${currencyProvider.ratesLastUpdated}" : ""}'
                                    : 'Display currency matches USD base',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                  fontFeatures: AppTheme.tabularFigures,
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
                                        color: colors.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.sync_rounded,
                                      size: 17,
                                      color: colors.primary,
                                    ),
                              tooltip: 'Refresh rates',
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: currencyProvider.isSyncingRates
                                  ? null
                                  : () =>
                                        currencyProvider.syncRatesFromBackend(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Device Monitoring Permissions
                Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text(
                            'Payment Detection',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildPermissionTile(
                          colors: colors,
                          icon: Icons.notifications_none_rounded,
                          iconColor: colors.violet,
                          iconBg: colors.violetBg,
                          title: 'UPI Notification Access',
                          subtitle: 'Detect Google Pay, PhonePe & Paytm alerts',
                          granted: _notifGranted,
                          onTap: () async {
                            await NotificationListenerService.instance
                                .requestPermission();
                            _loadPermissions();
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 66,
                          color: colors.borderSubtle,
                        ),
                        _buildPermissionTile(
                          colors: colors,
                          icon: Icons.sms_outlined,
                          iconColor: colors.amber,
                          iconBg: colors.amberBg,
                          title: 'Bank SMS Access',
                          subtitle: 'Read debit & credit transaction alerts',
                          granted: _smsGranted,
                          onTap: () async {
                            await NotificationListenerService.instance
                                .requestSmsPermission();
                            _loadPermissions();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sign Out
                Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: colors.riskCritical,
                      ),
                      title: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: colors.riskCritical,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                              'Are you sure you want to sign out of FraudLens?',
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
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
