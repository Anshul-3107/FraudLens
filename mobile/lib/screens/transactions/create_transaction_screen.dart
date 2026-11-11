import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/card.dart';
import '../../models/transaction.dart';
import '../../providers/card_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shap_factor_card.dart';

class CreateTransactionScreen extends StatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  CardModel? _selectedCard;
  String _selectedCategory = 'grocery_pos';
  String _source = 'upload';
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _transRefController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  final DateTime _occurredAt = DateTime.now();
  bool _submitting = false;
  TransactionCreateResponse? _result;

  @override
  void initState() {
    super.initState();
    final cardProvider = context.read<CardProvider>();
    if (cardProvider.cards.isNotEmpty) {
      _selectedCard = cardProvider.cards.first;
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _transRefController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final rawInput = double.tryParse(_amountController.text.trim());
    if (rawInput == null || rawInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final currencyProvider = context.read<CurrencyProvider>();
    // If the active currency is non-USD (e.g. INR), convert to USD base for the ML models
    final amountInUsd = currencyProvider.convertToUsd(rawInput);

    setState(() {
      _submitting = true;
      _result = null;
    });

    try {
      final req = TransactionCreateRequest(
        card: _selectedCard?.id,
        occurredAt: _occurredAt.toUtc(),
        merchant: _merchantController.text.trim(),
        category: _selectedCategory,
        amount: amountInUsd,
        transRef: _transRefController.text.trim().isNotEmpty
            ? _transRefController.text.trim()
            : null,
        merchLat: double.tryParse(_latController.text.trim()),
        merchLong: double.tryParse(_longController.text.trim()),
        source: _source,
      );

      final resp = await context.read<TransactionProvider>().createTransaction(
        req,
      );
      // Refresh dashboard summary and cards
      if (mounted) {
        context.read<DashboardProvider>().loadSummary();
        context.read<CardProvider>().loadCards();
        setState(() {
          _submitting = false;
          _result = resp;
        });
      }
    } catch (e) {
      if (mounted) {
        final colors = AppColors.of(context);
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit transaction: $e'),
            backgroundColor: colors.riskCritical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cardProvider = context.watch<CardProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Record Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Security Protection Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real-Time Fraud Protection Active',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transactions are automatically analyzed against card spending patterns to detect anomalies in real time.',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // If we have a scoring result, display it at the top!
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _result!.scoring.flagged
                        ? colors.riskCritical
                        : colors.riskLow,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          _result!.scoring.flagged
                              ? 'ALERT GENERATED'
                              : 'CLEARED / NORMAL',
                          style: TextStyle(
                            color: _result!.scoring.flagged
                                ? colors.riskCritical
                                : colors.riskLow,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        RiskScoreBadge(
                          score: _result!.scoring.score,
                          threshold: _result!.scoring.threshold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fraud probability score: ${(_result!.scoring.score * 100).toStringAsFixed(2)}% '
                      '(Decision threshold: ${(_result!.scoring.threshold * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (_result!.alertId != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Created Fraud Alert #${_result!.alertId}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.riskCritical,
                        ),
                      ),
                    ],
                    if (_result!.scoring.reasons.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Key Risk Contributors:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._result!.scoring.reasons.map(
                        (r) => ShapFactorCard(reason: r),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Input Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSubtle, width: 1),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Selection
                    DropdownButtonFormField<CardModel?>(
                      isExpanded: true,
                      initialValue:
                          _selectedCard ??
                          (cardProvider.cards.isNotEmpty
                              ? cardProvider.cards.first
                              : null),
                      decoration: const InputDecoration(
                        labelText: 'Payment Card',
                        prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                      ),
                      items: cardProvider.cards.isEmpty
                          ? [
                              const DropdownMenuItem<CardModel?>(
                                value: null,
                                child: Text('Primary Account (Auto-linked)'),
                              ),
                            ]
                          : cardProvider.cards.map((c) {
                              return DropdownMenuItem<CardModel?>(
                                value: c,
                                child: Text(
                                  c.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                      onChanged: (val) => setState(() => _selectedCard = val),
                    ),
                    const SizedBox(height: 14),

                    // Amount Input
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Amount in ${currencyProvider.activeCurrencyInfo.name} (${currencyProvider.activeCurrencyInfo.symbol})',
                        hintText: currencyProvider.activeCurrency == 'INR'
                            ? '500.00'
                            : '50.00',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text(
                              currencyProvider.activeCurrencyInfo.symbol,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Amount required';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return 'Must be a positive number';
                        }
                        return null;
                      },
                    ),
                    if (currencyProvider.isConvertedFromUsd) ...[
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final val =
                              double.tryParse(_amountController.text.trim()) ??
                              0.0;
                          final usdVal = currencyProvider.convertToUsd(val);
                          return Text(
                            '≈ \$${usdVal.toStringAsFixed(2)} USD base equivalent (1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency})',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Merchant
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Merchant Name',
                        hintText: 'e.g. Swiggy, Amazon, Starbucks',
                        prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Merchant required'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Spending Category',
                        prefixIcon: Icon(Icons.category_rounded, size: 20),
                      ),
                      items: kTransactionCategories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(
                            cat.replaceAll('_', ' ').toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Trans Ref (Optional)
                    TextFormField(
                      controller: _transRefController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Reference (Optional)',
                        hintText: 'Auto-generated if blank',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Geo Coordinates
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              hintText: '36.16',
                              prefixIcon: Icon(Icons.place_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _longController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              hintText: '-86.78',
                              prefixIcon: Icon(Icons.place_outlined, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Source
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _source,
                      decoration: const InputDecoration(
                        labelText: 'Ingestion Channel',
                        prefixIcon: Icon(Icons.input_rounded, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'upload',
                          child: Text(
                            'Simulated Real-time Transaction',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'batch',
                          child: Text(
                            'Batch Ingestion',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'manual',
                          child: Text(
                            'Manual Analyst Entry',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _source = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitTransaction,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        _submitting
                            ? 'Verifying Transaction...'
                            : 'Verify & Record Transaction',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
