import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/alert_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/notification_listener_service.dart';
import '../../services/upi_parser.dart';
import '../alerts/alerts_list_screen.dart';
import '../cards/cards_list_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  DateTime? _lastBackPress;
  StreamSubscription<ParsedUpiNotification>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _initNotificationListener();
  }

  void _initNotificationListener() {
    _notificationSub = NotificationListenerService.instance.onUpiPaymentCaptured
        .listen((upiPayment) {
          if (!mounted) return;
          _handleAutoCapturedPayment(upiPayment);
        });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await NotificationListenerService.instance
          .isPermissionGranted();
      if (!granted && mounted) {
        _showNotificationPermissionBanner();
      }
      final locGranted = await NotificationListenerService.instance
          .isLocationPermissionGranted();
      if (!locGranted) {
        await NotificationListenerService.instance.requestLocationPermission();
      }
    });
  }

  Future<void> _handleAutoCapturedPayment(
    ParsedUpiNotification upiPayment,
  ) async {
    final txnProvider = context.read<TransactionProvider>();
    final alertProvider = context.read<AlertProvider>();
    final dashProvider = context.read<DashboardProvider>();
    final cardProvider = context.read<CardProvider>();

    try {
      Map<String, dynamic>? locationData;
      try {
        locationData = await NotificationListenerService.instance
            .getCurrentLocation();
      } catch (_) {}

      final double? lat =
          locationData != null && locationData['latitude'] is num
          ? (locationData['latitude'] as num).toDouble()
          : null;
      final double? lon =
          locationData != null && locationData['longitude'] is num
          ? (locationData['longitude'] as num).toDouble()
          : null;
      final String? locName = locationData?['city'] as String?;

      final res = await txnProvider.processNotification(
        amount: upiPayment.amount,
        merchant: upiPayment.merchant,
        category: upiPayment.inferredCategory,
        last4: upiPayment.last4,
        bankName: upiPayment.bankName,
        packageName: upiPayment.packageName,
        source: upiPayment.source,
        txnType: upiPayment.txnType,
        currency: upiPayment.currency,
        merchLat: lat,
        merchLong: lon,
        locationName: locName,
      );

      final scoring = res['scoring'] as Map<String, dynamic>? ?? {};
      final bool isFlagged = scoring['flagged'] == true;
      final bool isRegistered = scoring['is_registered_account'] == true;

      await alertProvider.loadAlerts(page: 1);
      await dashProvider.loadSummary();
      await cardProvider.loadCards();

      if (!mounted) return;

      final sourceLabel = upiPayment.source == 'sms' ? 'Bank SMS' : 'UPI';
      final bool isReceived = upiPayment.isReceived;
      final colors = AppColors.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.border, width: 1),
          ),
          backgroundColor: colors.surface,
          content: Row(
            children: [
              Icon(
                isFlagged
                    ? Icons.warning_amber_rounded
                    : (isReceived
                          ? Icons.south_west_rounded
                          : Icons.check_circle_outline_rounded),
                color: isFlagged
                    ? colors.riskCritical
                    : (isReceived ? colors.riskLow : colors.tealPrimary),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFlagged
                          ? 'Unusual payment detected'
                          : (isReceived
                                ? 'Money received ($sourceLabel)'
                                : 'Payment recorded ($sourceLabel)'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${upiPayment.amount.toStringAsFixed(2)} ${isReceived ? 'from' : 'to'} ${upiPayment.merchant}'
                      '${!isRegistered ? ' · Unlinked account' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: isFlagged ? 'Review' : 'View',
            textColor: isFlagged ? colors.riskCritical : colors.primary,
            onPressed: () => _onTabSelected(isFlagged ? 2 : 1),
          ),
        ),
      );
    } catch (_) {}
  }

  void _showNotificationPermissionBanner() {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
        content: const Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enable Notification & SMS access to monitor UPI and bank payments automatically.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Enable',
          textColor: colors.primarySoft,
          onPressed: () async {
            await NotificationListenerService.instance.requestPermission();
            await NotificationListenerService.instance.requestSmsPermission();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index < 0 || index >= 4) return;
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _handleSystemBack(bool didPop, Object? result) {
    if (didPop || !mounted) return;

    if (_currentIndex != 0) {
      _lastBackPress = null;
      _onTabSelected(0);
      return;
    }

    final now = DateTime.now();
    final lastPress = _lastBackPress;

    if (lastPress != null &&
        now.difference(lastPress) <= const Duration(seconds: 2)) {
      _lastBackPress = null;
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit FraudLens'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Widget _buildAlertIcon({
    required IconData icon,
    required int openAlertsCount,
    required AppColors colors,
  }) {
    if (openAlertsCount <= 0) return Icon(icon);
    return Badge(
      backgroundColor: colors.riskCritical,
      textColor: Colors.white,
      label: Text(
        openAlertsCount > 99 ? '99+' : '$openAlertsCount',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dashProvider = context.watch<DashboardProvider>();
    final openAlertsCount = dashProvider.summary?.alertsByStatus.open ?? 0;

    final screens = [
      DashboardScreen(onNavigateTab: _onTabSelected),
      const TransactionsListScreen(),
      const AlertsListScreen(),
      CardsListScreen(onNavigateTab: _onTabSelected),
    ];

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;

          if (isWide) {
            return Scaffold(
              backgroundColor: colors.background,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _onTabSelected,
                    backgroundColor: colors.surface,
                    indicatorColor: colors.primary.withValues(alpha: 0.14),
                    extended: constraints.maxWidth >= 1024,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          if (constraints.maxWidth >= 1024) ...[
                            const SizedBox(width: 10),
                            Text(
                              'FraudLens',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton(
                            tooltip: 'Account & Settings',
                            icon: Icon(
                              Icons.settings_outlined,
                              color: colors.textSecondary,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: Text('Activity'),
                      ),
                      NavigationRailDestination(
                        icon: _buildAlertIcon(
                          icon: Icons.shield_outlined,
                          openAlertsCount: openAlertsCount,
                          colors: colors,
                        ),
                        selectedIcon: _buildAlertIcon(
                          icon: Icons.shield_rounded,
                          openAlertsCount: openAlertsCount,
                          colors: colors,
                        ),
                        label: const Text('Alerts'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        label: Text('Accounts'),
                      ),
                    ],
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  Expanded(
                    child: _FadeIndexedStack(
                      index: _currentIndex,
                      children: screens,
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: colors.background,
            body: _FadeIndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.border, width: 0.8),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabSelected,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Activity',
                  ),
                  NavigationDestination(
                    icon: _buildAlertIcon(
                      icon: Icons.shield_outlined,
                      openAlertsCount: openAlertsCount,
                      colors: colors,
                    ),
                    selectedIcon: _buildAlertIcon(
                      icon: Icons.shield_rounded,
                      openAlertsCount: openAlertsCount,
                      colors: colors,
                    ),
                    label: 'Alerts',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                    label: 'Accounts',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({required this.index, required this.children});

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
