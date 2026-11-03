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

  void _showFilterModal() {
    final colors = AppColors.of(context);
    final txnProvider = context.read<TransactionProvider>();
    final cardProvider = context.read<CardProvider>();
    final currencyProvider = context.read<CurrencyProvider>();

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
              border: Border.all(color: colors.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Transactions',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

                  // Card Filter
                  DropdownButtonFormField<int?>(
                    initialValue: tempCardId,
                    decoration: const InputDecoration(
                      labelText: 'Card',
                      prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Cards'),
                      ),
                      ...cardProvider.cards.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.label),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCardId = val),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter
                  DropdownButtonFormField<String?>(
                    initialValue: tempCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...kTransactionCategories.map(
                        (cat) => DropdownMenuItem<String?>(
                          value: cat,
                          child: Text(cat.replaceAll('_', ' ').toUpperCase()),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCategory = val),
                  ),
                  const SizedBox(height: 12),

                  // Min Amount
                  TextField(
                    controller: minAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Minimum Amount (${currencyProvider.activeCurrencyInfo.symbol} USD base)',
                      hintText: '50.00',
                      prefixIcon: const Icon(
                        Icons.attach_money_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date range
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dateFromController,
                          decoration: const InputDecoration(
                            labelText: 'From (YYYY-MM-DD)',
                            hintText: '2020-01-01',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dateToController,
                          decoration: const InputDecoration(
                            labelText: 'To (YYYY-MM-DD)',
                            hintText: '2021-12-31',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Flagged Only Switch
                  SwitchListTile(
                    title: const Text(
                      'Flagged / Suspicious Only',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Show only transactions with raised alerts',
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
                          child: const Text('Apply Filters'),
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
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    final totalPages = (txnProvider.count / 50).ceil();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: txnProvider.hasActiveFilters,
              backgroundColor: colors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Transaction',
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: totalPages > 1 ? 52 : 0),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateTransactionScreen(),
              ),
            );
          },
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('New Transaction'),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search merchant...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                txnProvider.setSearch('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (val) => txnProvider.setSearch(val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () =>
                      txnProvider.setSearch(_searchController.text),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  tooltip: 'Search',
                ),
              ],
            ),
          ),

          // Active filter indicator bar
          if (txnProvider.hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                border: Border(
                  bottom: BorderSide(color: colors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Active Filters Applied',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      txnProvider.resetFilters();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Transactions Count summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${NumberFormat.decimalPattern().format(txnProvider.count)} total transactions',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (totalPages > 1)
                  Text(
                    'Page ${txnProvider.page} of $totalPages',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
              ],
            ),
          ),

          // Main list content
          Expanded(
            child: txnProvider.isLoading && txnProvider.transactions.isEmpty
                ? const FintechLoadingIndicator(
                    label: 'Fetching transactions...',
                  )
                : txnProvider.errorMessage != null &&
                      txnProvider.transactions.isEmpty
                ? ErrorView(
                    message: txnProvider.errorMessage!,
                    onRetry: () => txnProvider.loadTransactions(),
                  )
                : txnProvider.transactions.isEmpty
                ? EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Transactions Found',
                    message: txnProvider.hasActiveFilters
                        ? 'No transactions match the selected filters. Try broadening your search.'
                        : 'There are no transactions recorded for your account.',
                    actionLabel: txnProvider.hasActiveFilters
                        ? 'Clear Filters'
                        : null,
                    onAction: txnProvider.hasActiveFilters
                        ? () => txnProvider.resetFilters()
                        : null,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        txnProvider.loadTransactions(page: txnProvider.page),
                    color: colors.primary,
                    child: ListView.separated(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 4,
                        bottom: totalPages > 1 ? 120 : 80,
                      ),
                      itemCount: txnProvider.transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final txn = txnProvider.transactions[index];
                        final isFlagged = txn.hasAlert;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransactionDetailScreen(transaction: txn),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isFlagged
                                    ? colors.riskCritical.withValues(
                                        alpha: 0.35,
                                      )
                                    : colors.borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Transaction Icon / Flag indicator
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isFlagged
                                        ? colors.riskCriticalBg
                                        : colors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isFlagged
                                          ? colors.riskCritical.withValues(
                                              alpha: 0.25,
                                            )
                                          : colors.borderSubtle,
                                    ),
                                  ),
                                  child: Icon(
                                    isFlagged
                                        ? Icons.warning_rounded
                                        : Icons.storefront_rounded,
                                    size: 18,
                                    color: isFlagged
                                        ? colors.riskCritical
                                        : colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Merchant and date
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              txn.merchant,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isFlagged) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colors.riskCriticalBg,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: colors.riskCritical
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Text(
                                                'FLAGGED',
                                                style: TextStyle(
                                                  color: colors.riskCritical,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${dateFormat.format(txn.occurredAt)} • ${txn.cardLabel}',
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Amount and Category
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        currencyProvider.format(txn.amount),
                                        style: TextStyle(
                                          color: isFlagged
                                              ? colors.riskCritical
                                              : colors.textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 95,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: colors.borderSubtle,
                                          ),
                                        ),
                                        child: Text(
                                          txn.formattedCategory,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
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
                  ),
          ),

          // Pagination Bar at Bottom
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: txnProvider.hasPrevious && !txnProvider.isLoading
                        ? () => txnProvider.previousPage()
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 16),
                    label: const Text('Prev'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Page ${txnProvider.page} of $totalPages',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
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
                    icon: const Icon(Icons.chevron_right_rounded, size: 16),
                    label: const Text('Next'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
