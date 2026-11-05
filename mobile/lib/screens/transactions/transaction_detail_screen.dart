import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/alert.dart';
import '../../models/transaction.dart';
import '../../providers/currency_provider.dart';
import '../../services/alert_service.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shap_factor_card.dart';
import '../alerts/alert_detail_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  AlertModel? _associatedAlert;
  bool _loadingAlert = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction.hasAlert) {
      _loadAlertDetails();
    }
  }

  Future<void> _loadAlertDetails() async {
    setState(() => _loadingAlert = true);
    try {
      // Find alert with matching card and transaction
      final alertsResp = await AlertService().getAlerts(
        cardId: widget.transaction.card,
        page: 1,
      );
      final match = alertsResp.results.firstWhere(
        (a) => a.transaction?.id == widget.transaction.id,
        orElse: () => alertsResp.results.isNotEmpty
            ? alertsResp.results.first
            : throw Exception('Alert not found'),
      );
      if (mounted) {
        setState(() {
          _associatedAlert = match;
          _loadingAlert = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAlert = false);
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Widget? trailing,
  }) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            Flexible(child: trailing)
          else
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final txn = widget.transaction;
    final currencyProvider = context.watch<CurrencyProvider>();
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm:ss a');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Transaction Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card with amount and merchant
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: txn.hasAlert
                      ? colors.riskCritical.withValues(alpha: 0.3)
                      : colors.borderSubtle,
                  width: txn.hasAlert ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: txn.hasAlert
                          ? colors.riskCriticalBg
                          : colors.surfaceSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: txn.hasAlert
                            ? colors.riskCritical.withValues(alpha: 0.25)
                            : colors.borderSubtle,
                      ),
                    ),
                    child: Icon(
                      txn.hasAlert
                          ? Icons.warning_rounded
                          : Icons.storefront_rounded,
                      size: 28,
                      color: txn.hasAlert
                          ? colors.riskCritical
                          : colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currencyProvider.format(txn.amount),
                      style: TextStyle(
                        color: txn.hasAlert
                            ? colors.riskCritical
                            : colors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (currencyProvider.isConvertedFromUsd) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Original: \$${txn.amount.toStringAsFixed(2)} USD • Rate: 1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency}',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    txn.merchant,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (txn.hasAlert)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.riskCriticalBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colors.riskCritical.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: colors.riskCritical,
                          ),
                          Text(
                            'Flagged as Suspicious Transaction',
                            style: TextStyle(
                              color: colors.riskCritical,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Ledger Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSubtle, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ledger Details',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: colors.borderSubtle),
                  _buildDetailRow(context, 'Transaction ID', '#${txn.id}'),
                  _buildDetailRow(
                    context,
                    'Reference',
                    txn.transRef.isNotEmpty ? txn.transRef : 'N/A',
                  ),
                  _buildDetailRow(context, 'Card', txn.cardLabel),
                  _buildDetailRow(
                    context,
                    'Category',
                    txn.category.replaceAll('_', ' ').toUpperCase(),
                  ),
                  _buildDetailRow(context, 'Source', txn.source.toUpperCase()),
                  _buildDetailRow(
                    context,
                    'Date & Time',
                    dateFormat.format(txn.occurredAt),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Associated Fraud Alert Card
            if (txn.hasAlert) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.riskCritical.withValues(alpha: 0.35),
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
                          'Associated Fraud Alert',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_associatedAlert != null)
                          RiskScoreBadge(
                            score: _associatedAlert!.score,
                            threshold: _associatedAlert!.threshold,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingAlert)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_associatedAlert != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          AlertStatusBadge(status: _associatedAlert!.status),
                        ],
                      ),
                      if (_associatedAlert!.reasons.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Key Risk Factors:',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._associatedAlert!.reasons
                            .take(2)
                            .map((r) => ShapFactorCard(reason: r)),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AlertDetailScreen(alert: _associatedAlert!),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          label: const Text('Open Full Alert Investigation'),
                        ),
                      ),
                    ] else
                      Text(
                        'This transaction was flagged for investigation. Alert details could not be loaded.',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
