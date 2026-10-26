import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/card.dart';
import '../../models/transaction.dart';
import '../../providers/card_provider.dart';
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
  final _merchantController = TextEditingController(text: 'Amazon Marketplace');
  final _amountController = TextEditingController(text: '85.50');
  final _transRefController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  DateTime _occurredAt = DateTime.now();
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
    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment card')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _result = null;
    });

    try {
      final req = TransactionCreateRequest(
        card: _selectedCard!.id,
        occurredAt: _occurredAt.toUtc(),
        merchant: _merchantController.text.trim(),
        category: _selectedCategory,
        amount: amount,
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
      // Refresh dashboard summary
      if (mounted) {
        context.read<DashboardProvider>().loadSummary();
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
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Record & Score Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ML Inference Banner
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
                      Icons.auto_awesome_rounded,
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
                          'Live ML Inference Active',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transactions are scored against card behavior profiles using Isolation Forest, XGBoost, and TreeSHAP explainability.',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        'SHAP Factor Contributions:',
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
                      initialValue:
                          _selectedCard ??
                          (cardProvider.cards.isNotEmpty
                              ? cardProvider.cards.first
                              : null),
                      decoration: const InputDecoration(
                        labelText: 'Payment Card',
                        prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                      ),
                      items: cardProvider.cards.map((c) {
                        return DropdownMenuItem<CardModel?>(
                          value: c,
                          child: Text(c.label),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCard = val),
                      validator: (val) =>
                          val == null ? 'Please select a card' : null,
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (USD)',
                        hintText: '950.00',
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
                      ),
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
                    const SizedBox(height: 14),

                    // Merchant
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Merchant Name',
                        hintText: 'fraud_Kirlin and Sons',
                        prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Merchant required'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Spending Category',
                        prefixIcon: Icon(Icons.category_rounded, size: 20),
                      ),
                      items: kTransactionCategories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat.replaceAll('_', ' ').toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Source
                    DropdownButtonFormField<String>(
                      initialValue: _source,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Ingestion Source',
                        prefixIcon: Icon(Icons.input_rounded, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'upload',
                          child: Text('User Upload'),
                        ),
                        DropdownMenuItem(
                          value: 'aa_sandbox',
                          child: Text('Account Aggregator Sandbox'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _source = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Date & Time Picker Tile
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: colors.borderSubtle),
                      ),
                      leading: Icon(
                        Icons.calendar_month_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        'Transaction Timestamp',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        dateFormat.format(_occurredAt),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.edit_calendar_rounded,
                        size: 18,
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _occurredAt,
                          firstDate: DateTime(2019),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (pickedDate == null || !context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_occurredAt),
                        );
                        if (pickedTime != null && context.mounted) {
                          setState(() {
                            _occurredAt = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Optional Reference ID
                    TextFormField(
                      controller: _transRefController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Reference ID (Optional)',
                        hintText: 'TXN-CUSTOM-001',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitTransaction,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        _submitting
                            ? 'Running ML Inference...'
                            : 'Score and Ingest Transaction',
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
