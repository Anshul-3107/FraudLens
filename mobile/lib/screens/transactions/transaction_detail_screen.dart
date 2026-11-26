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
import '../chat/richie_chat_sheet.dart';

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

  String _sourceLabel(String src) {
    switch (src.toLowerCase()) {
      case 'notification':
        return 'UPI notification';
      case 'sms':
        return 'Bank SMS';
      case 'upload':
        return 'Manual entry';
      case 'aa_sandbox':
        return 'Account aggregator';
      default:
        return 'Card activity';
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
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 14),
          if (trailing != null)
            Flexible(child: trailing)
          else
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.end,
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
    final dateFormat = DateFormat('MMMM d, yyyy · h:mm a');
    final displayAmount =
        '${txn.isReceived ? '+' : ''}${currencyProvider.format(txn.amount, isSourceUsd: txn.isSourceUsd)}';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Transaction')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Receipt Summary Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: txn.hasAlert
                          ? colors.riskCritical.withValues(alpha: 0.3)
                          : colors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: txn.hasAlert
                              ? colors.riskCriticalBg
                              : (txn.isReceived
                                    ? colors.riskLowBg
                                    : colors.surfaceMuted),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          txn.hasAlert
                              ? Icons.priority_high_rounded
                              : (txn.isReceived
                                    ? Icons.south_west_rounded
                                    : colors.getCategoryIcon(txn.category)),
                          size: 22,
                          color: txn.hasAlert
                              ? colors.riskCritical
                              : (txn.isReceived
                                    ? colors.riskLow
                                    : colors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          displayAmount,
                          style: TextStyle(
                            color: txn.hasAlert
                                ? colors.riskCritical
                                : (txn.isReceived
                                      ? colors.riskLow
                                      : colors.textPrimary),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            fontFeatures: AppTheme.tabularFigures,
                          ),
                        ),
                      ),
                      if (txn.isSourceUsd &&
                          currencyProvider.isConvertedFromUsd) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Original: \$${txn.amount.toStringAsFixed(2)} USD · 1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        txn.merchant,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(txn.occurredAt),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (txn.hasAlert) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.riskCriticalBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: colors.riskCritical,
                              ),
                              Text(
                                'Flagged for review',
                                style: TextStyle(
                                  color: colors.riskCritical,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Associated Security Alert Card
                if (txn.hasAlert) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.riskCritical.withValues(alpha: 0.3),
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
                                'Security Alert',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_associatedAlert != null)
                                RiskScoreBadge(
                                  score: _associatedAlert!.score,
                                  threshold: _associatedAlert!.threshold,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_loadingAlert)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
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
                              const SizedBox(width: 8),
                              Flexible(
                                child: AlertStatusBadge(
                                  status: _associatedAlert!.status,
                                ),
                              ),
                            ],
                          ),
                          if (_associatedAlert!.reasons.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Why it was flagged',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._associatedAlert!.reasons
                                .take(2)
                                .map((r) => ShapFactorCard(reason: r)),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlertDetailScreen(
                                      alert: _associatedAlert!,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Review & Respond'),
                            ),
                          ),
                        ] else
                          Text(
                            'This transaction looked unusual compared to your normal activity.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Clean Receipt Details
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'Details',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Divider(color: colors.borderSubtle, height: 1),
                      _buildDetailRow(context, 'Account', txn.cardLabel),
                      Divider(color: colors.borderSubtle, height: 1),
                      _buildDetailRow(
                        context,
                        'Category',
                        AppColors.friendlyCategoryName(txn.category),
                      ),
                      Divider(color: colors.borderSubtle, height: 1),
                      _buildDetailRow(
                        context,
                        'Detected via',
                        _sourceLabel(txn.source),
                      ),
                      Divider(color: colors.borderSubtle, height: 1),
                      _buildDetailRow(
                        context,
                        'Reference',
                        txn.transRef.isNotEmpty ? txn.transRef : '—',
                      ),
                      Divider(color: colors.borderSubtle, height: 1),
                      _buildDetailRow(context, 'Record ID', '#${txn.id}'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Ask Richie Contextual Action
                OutlinedButton.icon(
                  onPressed: () {
                    RichieChatSheet.show(
                      context,
                      initialPrompt:
                          'Can you review my $displayAmount payment at ${txn.merchant}?',
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Ask Richie about this payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
