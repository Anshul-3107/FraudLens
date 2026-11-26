import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/card.dart';
import '../../models/transaction.dart';
import '../../providers/card_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/notification_listener_service.dart';
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
  bool _fetchingLocation = false;
  String _detectedCity = '';
  TransactionCreateResponse? _result;

  @override
  void initState() {
    super.initState();
    final cardProvider = context.read<CardProvider>();
    if (cardProvider.cards.isNotEmpty) {
      _selectedCard = cardProvider.cards.first;
    }
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final loc = await NotificationListenerService.instance
          .getCurrentLocation();
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        final lat = (loc['latitude'] as num).toDouble();
        final lon = (loc['longitude'] as num).toDouble();
        _latController.text = lat.toStringAsFixed(6);
        _longController.text = lon.toStringAsFixed(6);
        final city = (loc['city'] as String? ?? '').isNotEmpty
            ? loc['city'] as String
            : (loc['address'] as String? ?? '');
        if (mounted) {
          setState(() {
            _detectedCity = city;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
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
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    final currencyProvider = context.read<CurrencyProvider>();
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
            content: Text('Could not record transaction: $e'),
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
      appBar: AppBar(title: const Text('New Transaction')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log a payment to run a live risk check against your spending profile.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Scoring Result Banner
                if (_result != null) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _result!.scoring.flagged
                            ? colors.riskCritical.withValues(alpha: 0.45)
                            : colors.riskLow.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Text(
                                _result!.scoring.flagged
                                    ? 'Flagged for Review'
                                    : 'Looks Normal',
                                style: TextStyle(
                                  color: _result!.scoring.flagged
                                      ? colors.riskCritical
                                      : colors.riskLow,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              RiskScoreBadge(
                                score: _result!.scoring.score,
                                threshold: _result!.scoring.threshold,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Risk score: ${(_result!.scoring.score * 100).toStringAsFixed(1)}% '
                          '(Alert threshold: ${(_result!.scoring.threshold * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                            fontFeatures: AppTheme.tabularFigures,
                          ),
                        ),
                        if (_result!.alertId != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Added to Alerts (#${_result!.alertId})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colors.riskCritical,
                            ),
                          ),
                        ],
                        if (_result!.scoring.reasons.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Why it stood out',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._result!.scoring.reasons.map(
                            (r) => ShapFactorCard(reason: r),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Form Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<CardModel?>(
                          isExpanded: true,
                          initialValue:
                              _selectedCard ??
                              (cardProvider.cards.isNotEmpty
                                  ? cardProvider.cards.first
                                  : null),
                          decoration: const InputDecoration(
                            labelText: 'Account / Card',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 20,
                            ),
                          ),
                          items: cardProvider.cards.isEmpty
                              ? [
                                  const DropdownMenuItem<CardModel?>(
                                    value: null,
                                    child: Text('Primary Account'),
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
                          onChanged: (val) =>
                              setState(() => _selectedCard = val),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'Amount (${currencyProvider.activeCurrency})',
                            hintText: currencyProvider.activeCurrency == 'INR'
                                ? '500.00'
                                : '50.00',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Center(
                                widthFactor: 1.0,
                                child: Text(
                                  currencyProvider.activeCurrencyInfo.symbol,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
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
                              return 'Enter an amount greater than 0';
                            }
                            return null;
                          },
                        ),
                        if (currencyProvider.isConvertedFromUsd) ...[
                          const SizedBox(height: 5),
                          Builder(
                            builder: (context) {
                              final val =
                                  double.tryParse(
                                    _amountController.text.trim(),
                                  ) ??
                                  0.0;
                              final usdVal = currencyProvider.convertToUsd(val);
                              return Text(
                                'Scored as ≈ \$${usdVal.toStringAsFixed(2)} USD (1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency})',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 11.5,
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _merchantController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant',
                            hintText: 'e.g. Swiggy, Amazon, Uber',
                            prefixIcon: Icon(
                              Icons.storefront_outlined,
                              size: 20,
                            ),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Merchant name required'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined, size: 20),
                          ),
                          items: kTransactionCategories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(
                                AppColors.friendlyCategoryName(cat),
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

                        TextFormField(
                          controller: _transRefController,
                          decoration: const InputDecoration(
                            labelText: 'Reference ID (optional)',
                            hintText: 'Auto-generated if empty',
                            prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Safe Location Header (no city-name overflow)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextButton.icon(
                                onPressed: _fetchingLocation
                                    ? null
                                    : _detectLocation,
                                icon: _fetchingLocation
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                      ),
                                label: Text(
                                  _detectedCity.isNotEmpty
                                      ? _detectedCity
                                      : 'Use GPS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  hintText: '28.6139',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _longController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  hintText: '77.2090',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _source,
                          decoration: const InputDecoration(
                            labelText: 'Channel',
                            prefixIcon: Icon(
                              Icons.swap_horiz_rounded,
                              size: 20,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'upload',
                              child: Text(
                                'Test / Manual check',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'batch',
                              child: Text(
                                'Batch import',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'manual',
                              child: Text(
                                'Manual entry',
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.shield_outlined, size: 18),
                          label: Text(
                            _submitting
                                ? 'Checking payment...'
                                : 'Check & Record',
                          ),
                        ),
                      ],
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
