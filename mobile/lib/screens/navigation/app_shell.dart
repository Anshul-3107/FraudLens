import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/dashboard_provider.dart';
import '../alerts/alerts_list_screen.dart';
import '../cards/cards_list_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../investigations/investigations_list_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final ScrollController _navScrollController = ScrollController();
  final List<GlobalKey> _navItemKeys = List.generate(6, (_) => GlobalKey());

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _scrollToSelectedTab(_currentIndex);
  }

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index < 0 || index >= _navItemKeys.length) return;

    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }

    _scrollToSelectedTab(index);
  }

  void _handleSystemBack(bool didPop, Object? result) {
    if (didPop || !mounted) return;

    // Back from another tab returns to the Dashboard.
    if (_currentIndex != 0) {
      _lastBackPress = null;
      _onTabSelected(0);
      return;
    }

    // On the Dashboard, require a second Back press within
    // two seconds before exiting the app.
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

  void _scrollToSelectedTab(int index) {
    if (index < 0 || index >= _navItemKeys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final keyContext = _navItemKeys[index].currentContext;

      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.5,
        );
      }
    });
  }

  Widget _buildScrollableBottomNav({
    required BuildContext context,
    required AppColors colors,
    required int openAlertsCount,
    required double maxWidth,
  }) {
    final destinations = [
      const _NavDestinationItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      const _NavDestinationItem(
        label: 'Transactions',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
      ),
      _NavDestinationItem(
        label: 'Alerts',
        icon: Icons.warning_amber_rounded,
        selectedIcon: Icons.warning_rounded,
        badgeCount: openAlertsCount,
      ),
      const _NavDestinationItem(
        label: 'Review',
        icon: Icons.gavel_outlined,
        selectedIcon: Icons.gavel_rounded,
      ),
      const _NavDestinationItem(
        label: 'Cards',
        icon: Icons.credit_card_outlined,
        selectedIcon: Icons.credit_card_rounded,
      ),
      const _NavDestinationItem(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    // Keep each destination wide enough for its label.
    const double itemMinWidth = 88.0;

    final bool canFitAll = maxWidth >= itemMinWidth * destinations.length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: 64,
          child: SingleChildScrollView(
            controller: _navScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: maxWidth),
              child: Row(
                mainAxisAlignment: canFitAll
                    ? MainAxisAlignment.spaceEvenly
                    : MainAxisAlignment.start,
                children: [
                  for (int i = 0; i < destinations.length; i++)
                    _buildNavItem(
                      index: i,
                      item: destinations[i],
                      isSelected: _currentIndex == i,
                      colors: colors,
                      minWidth: itemMinWidth,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required _NavDestinationItem item,
    required bool isSelected,
    required AppColors colors,
    required double minWidth,
  }) {
    Widget iconWidget = Icon(
      isSelected ? item.selectedIcon : item.icon,
      size: 22,
      color: isSelected ? colors.primary : colors.textMuted,
    );

    if (item.badgeCount != null && item.badgeCount! > 0) {
      iconWidget = Badge(
        backgroundColor: colors.riskCritical,
        textColor: Colors.white,
        label: Text(
          '${item.badgeCount}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        child: iconWidget,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: _navItemKeys[index],
          onTap: () => _onTabSelected(index),
          borderRadius: BorderRadius.circular(12),
          splashColor: colors.primary.withValues(alpha: 0.12),
          highlightColor: colors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: iconWidget,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.textPrimary : colors.textMuted,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      const InvestigationsListScreen(),
      CardsListScreen(onNavigateTab: _onTabSelected),
      const ProfileScreen(),
    ];

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;

          if (isWide) {
            // Desktop and tablet layout with NavigationRail.
            return Scaffold(
              backgroundColor: colors.background,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _onTabSelected,
                    backgroundColor: colors.surface,
                    indicatorColor: colors.primary.withValues(alpha: 0.12),
                    extended: constraints.maxWidth >= 1024,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                          if (constraints.maxWidth >= 1024) ...[
                            const SizedBox(width: 12),
                            Text(
                              'FraudLens',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard_rounded),
                        label: Text('Dashboard'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: Text('Transactions'),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          isLabelVisible: openAlertsCount > 0,
                          backgroundColor: colors.riskCritical,
                          textColor: Colors.white,
                          label: Text('$openAlertsCount'),
                          child: const Icon(Icons.warning_amber_rounded),
                        ),
                        selectedIcon: Badge(
                          isLabelVisible: openAlertsCount > 0,
                          backgroundColor: colors.riskCritical,
                          textColor: Colors.white,
                          label: Text('$openAlertsCount'),
                          child: const Icon(Icons.warning_rounded),
                        ),
                        label: const Text('Fraud Alerts'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.gavel_outlined),
                        selectedIcon: Icon(Icons.gavel_rounded),
                        label: Text('Investigations'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.credit_card_outlined),
                        selectedIcon: Icon(Icons.credit_card_rounded),
                        label: Text('Cards'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: Text('Profile'),
                      ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colors.borderSubtle,
                  ),
                  Expanded(child: screens[_currentIndex]),
                ],
              ),
            );
          }

          // Mobile layout with horizontally scrollable navigation.
          return Scaffold(
            backgroundColor: colors.background,
            body: IndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar: _buildScrollableBottomNav(
              context: context,
              colors: colors,
              openAlertsCount: openAlertsCount,
              maxWidth: constraints.maxWidth,
            ),
          );
        },
      ),
    );
  }
}

class _NavDestinationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? badgeCount;

  const _NavDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount,
  });
}
