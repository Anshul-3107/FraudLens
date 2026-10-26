import 'package:flutter/material.dart';
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

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        if (isWide) {
          // Desktop / Tablet layout with NavigationRail
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
                    NavigationRailDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(
                        Icons.dashboard_rounded,
                        color: colors.primary,
                      ),
                      label: const Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(
                        Icons.receipt_long_rounded,
                        color: colors.primary,
                      ),
                      label: const Text('Transactions'),
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
                        child: Icon(
                          Icons.warning_rounded,
                          color: colors.riskCritical,
                        ),
                      ),
                      label: const Text('Fraud Alerts'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.gavel_outlined),
                      selectedIcon: Icon(
                        Icons.gavel_rounded,
                        color: colors.primary,
                      ),
                      label: const Text('Investigations'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.credit_card_outlined),
                      selectedIcon: Icon(
                        Icons.credit_card_rounded,
                        color: colors.primary,
                      ),
                      label: const Text('Cards'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(
                        Icons.person_rounded,
                        color: colors.primary,
                      ),
                      label: const Text('Profile'),
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

        // Mobile layout with NavigationBar
        return Scaffold(
          backgroundColor: colors.background,
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Transactions',
              ),
              NavigationDestination(
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
                label: 'Alerts',
              ),
              const NavigationDestination(
                icon: Icon(Icons.gavel_outlined),
                selectedIcon: Icon(Icons.gavel_rounded),
                label: 'Review',
              ),
              const NavigationDestination(
                icon: Icon(Icons.credit_card_outlined),
                selectedIcon: Icon(Icons.credit_card_rounded),
                label: 'Cards',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
