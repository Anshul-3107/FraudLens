import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/card_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/transaction_card.dart';
import 'create_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final txnProvider = context.read<TransactionProvider>();
      if (txnProvider.transactions.isEmpty) {
        txnProvider.loadTransactions();
      }
      context.read<CardProvider>().loadCards();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    if (dt.year == now.year) return DateFormat('EEE, MMM d').format(dt);
    return DateFormat('MMM d, yyyy').format(dt);
  }

  List<_TxnGroup> _groupByDate(List<TransactionModel> items) {
    final now = DateTime.now();
    final groups = <_TxnGroup>[];
    for (final txn in items) {
      final key = _formatDateHeader(txn.occurredAt, now);
      if (groups.isEmpty || groups.last.header != key) {
        groups.add(_TxnGroup(header: key, items: [txn]));
      } else {
        groups.last.items.add(txn);
      }
    }
    return groups;
  }

  void _showFilterModal() {
    final colors = AppColors.of(context);
    final txnProvider = context.read<TransactionProvider>();
    final cardProvider = context.read<CardProvider>();

    int? tempCardId = txnProvider.cardId;
    String? tempCategory = txnProvider.category;
    bool tempFlagged = txnProvider.flaggedOnly;
    final dateFromController = TextEditingController(
      text: txnProvider.dateFrom ?? '',
    );
    final dateToController = TextEditingController(
      text: txnProvider.dateTo ?? '',
    );
    final minAmountController = TextEditingController(
      text: txnProvider.minAmount != null
          ? txnProvider.minAmount.toString()
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(color: colors.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Filter Activity',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: tempCardId,
                    decoration: const InputDecoration(
                      labelText: 'Account / Card',
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'All Accounts',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...cardProvider.cards.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCardId = val),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: tempCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All Categories',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...kTransactionCategories.map(
                        (cat) => DropdownMenuItem<String?>(
                          value: cat,
                          child: Text(
                            AppColors.friendlyCategoryName(cat),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCategory = val),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: minAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minimum Amount',
                      hintText: '50.00',
                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dateFromController,
                          decoration: const InputDecoration(
                            labelText: 'From (YYYY-MM-DD)',
                            hintText: '2026-01-01',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dateToController,
                          decoration: const InputDecoration(
                            labelText: 'To (YYYY-MM-DD)',
                            hintText: '2026-12-31',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    title: const Text(
                      'Needs review only',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Only show transactions flagged as unusual',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    value: tempFlagged,
                    activeThumbColor: colors.riskCritical,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setModalState(() => tempFlagged = val),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _searchController.clear();
                            txnProvider.resetFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            txnProvider.setCard(tempCardId);
                            txnProvider.setCategory(tempCategory);
                            txnProvider.setFlaggedOnly(tempFlagged);
                            txnProvider.setDateRange(
                              dateFromController.text.trim().isEmpty
                                  ? null
                                  : dateFromController.text.trim(),
                              dateToController.text.trim().isEmpty
                                  ? null
                                  : dateToController.text.trim(),
                            );
                            final minAmt = double.tryParse(
                              minAmountController.text.trim(),
                            );
                            txnProvider.setMinAmount(minAmt);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final txnProvider = context.watch<TransactionProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final totalPages = (txnProvider.count / 50).ceil();
    final grouped = _groupByDate(txnProvider.transactions);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: txnProvider.hasActiveFilters,
              backgroundColor: colors.primary,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New transaction',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateTransactionScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                txnProvider.loadTransactions(page: txnProvider.page),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & quick filter controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (val) => txnProvider.setSearch(val),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search merchant or store...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: colors.textMuted,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              txnProvider.setSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        selected: !txnProvider.hasActiveFilters,
                        selectedColor: colors.primary,
                        onTap: () {
                          _searchController.clear();
                          txnProvider.resetFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Needs review',
                        selected: txnProvider.flaggedOnly,
                        selectedColor: colors.riskCritical,
                        onTap: () => txnProvider.setFlaggedOnly(
                          !txnProvider.flaggedOnly,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: txnProvider.cardId != null
                            ? 'Account filtered'
                            : 'More filters',
                        selected:
                            txnProvider.cardId != null ||
                            txnProvider.category != null ||
                            txnProvider.dateFrom != null ||
                            txnProvider.dateTo != null ||
                            (txnProvider.minAmount ?? 0) > 0,
                        selectedColor: colors.violet,
                        onTap: _showFilterModal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Count & current page indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${NumberFormat.decimalPattern().format(txnProvider.count)} ${txnProvider.count == 1 ? 'transaction' : 'transactions'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (totalPages > 1)
                  Text(
                    'Page ${txnProvider.page} of $totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
              ],
            ),
          ),

          // Ledger body
          Expanded(
            child: txnProvider.isLoading && txnProvider.transactions.isEmpty
                ? const FintechLoadingIndicator(label: 'Loading activity...')
                : txnProvider.errorMessage != null &&
                      txnProvider.transactions.isEmpty
                ? ErrorView(
                    message: txnProvider.errorMessage!,
                    onRetry: () => txnProvider.loadTransactions(),
                  )
                : txnProvider.transactions.isEmpty
                ? EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Activity Yet',
                    message: txnProvider.hasActiveFilters
                        ? 'No transactions match these filters.'
                        : 'Payments detected from SMS, UPI, or manual checks appear here.',
                    actionLabel: txnProvider.hasActiveFilters
                        ? 'Clear filters'
                        : 'Check a transaction',
                    onAction: txnProvider.hasActiveFilters
                        ? () {
                            _searchController.clear();
                            txnProvider.resetFilters();
                          }
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateTransactionScreen(),
                              ),
                            );
                          },
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        txnProvider.loadTransactions(page: txnProvider.page),
                    color: colors.primary,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: grouped.length,
                          itemBuilder: (context, groupIndex) {
                            final group = grouped[groupIndex];
                            final double daySpendDisplay = group.items
                                .where((t) => !t.isReceived)
                                .fold<double>(
                                  0.0,
                                  (sum, t) =>
                                      sum +
                                      (t.isSourceUsd
                                          ? currencyProvider.convertFromUsd(
                                              t.amount,
                                            )
                                          : t.amount),
                                );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      0,
                                      4,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            group.header,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (daySpendDisplay > 0)
                                          Text(
                                            currencyProvider.format(
                                              daySpendDisplay,
                                              isSourceUsd: false,
                                            ),
                                            style: TextStyle(
                                              color: colors.textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures:
                                                  AppTheme.tabularFigures,
                                            ),
                                            maxLines: 1,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: colors.border),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        for (
                                          int i = 0;
                                          i < group.items.length;
                                          i++
                                        ) ...[
                                          if (i > 0)
                                            Divider(
                                              height: 1,
                                              indent: 68,
                                              color: colors.borderSubtle,
                                            ),
                                          TransactionCard(
                                            transaction: group.items[i],
                                            onTap: () {
                                              final txn = group.items[i];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TransactionDetailScreen(
                                                        transaction: txn,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),

          // Non-overlapping pagination bar
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          txnProvider.hasPrevious && !txnProvider.isLoading
                          ? () => txnProvider.previousPage()
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      label: const Text('Prev'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Page ${txnProvider.page} of $totalPages',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTheme.tabularFigures,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: txnProvider.hasNext && !txnProvider.isLoading
                          ? () => txnProvider.nextPage()
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      label: const Text('Next'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TxnGroup {
  final String header;
  final List<TransactionModel> items;
  _TxnGroup({required this.header, required this.items});
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? selectedColor;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final activeBg = selectedColor ?? colors.textPrimary;
    final activeFg = (selectedColor != null || !colors.isDark)
        ? Colors.white
        : const Color(0xFF0F0F11);

    return Material(
      color: selected ? activeBg : colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? activeBg : colors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeFg : colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
