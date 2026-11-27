import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/alert.dart';
import '../../models/investigation.dart';
import '../../providers/alert_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/investigation_provider.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shap_factor_card.dart';
import '../chat/richie_chat_sheet.dart';

class AlertDetailScreen extends StatefulWidget {
  final AlertModel alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late AlertModel _currentAlert;
  String _selectedVerdict = 'false_positive';
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;
  bool _showTechnicalFactors = false;

  @override
  void initState() {
    super.initState();
    _currentAlert = widget.alert;
    if (_currentAlert.latestVerdict != null) {
      _selectedVerdict = _currentAlert.latestVerdict!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitVerdict() async {
    setState(() => _submitting = true);

    try {
      final req = InvestigationCreateRequest(
        verdict: _selectedVerdict,
        notes: _notesController.text.trim(),
      );

      final invResult = await context.read<AlertProvider>().recordInvestigation(
        _currentAlert.id,
        req,
      );

      if (mounted) {
        context.read<DashboardProvider>().loadSummary();
        context.read<InvestigationProvider>().loadInvestigations();

        setState(() {
          _submitting = false;
          _currentAlert = AlertModel(
            id: _currentAlert.id,
            score: _currentAlert.score,
            threshold: _currentAlert.threshold,
            reasons: _currentAlert.reasons,
            status: _selectedVerdict == 'needs_info' ? 'in_review' : 'resolved',
            createdAt: _currentAlert.createdAt,
            transaction: _currentAlert.transaction,
            latestVerdict: _selectedVerdict,
          );
        });

        final colors = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Decision saved: ${invResult.verdictDisplay}.'),
            backgroundColor: colors.riskLow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors = AppColors.of(context);
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save decision: $e'),
            backgroundColor: colors.riskCritical,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    FontWeight? fontWeight,
  }) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? colors.textPrimary,
                fontSize: 13.5,
                fontWeight: fontWeight ?? FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictOption({
    required AppColors colors,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedVerdict == value;
    return Material(
      color: isSelected
          ? accentColor.withValues(alpha: colors.isDark ? 0.14 : 0.08)
          : colors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _selectedVerdict = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: colors.isDark ? 0.16 : 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 18, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final alert = _currentAlert;
    final txn = alert.transaction;
    final currencyProvider = context.watch<CurrencyProvider>();
    final dateFormat = DateFormat('MMMM d, yyyy · h:mm a');
    final displayAmount = txn != null
        ? currencyProvider.format(txn.amount, isSourceUsd: txn.isSourceUsd)
        : '—';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Alert #${alert.id}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: AlertStatusBadge(status: alert.status)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Risk Assessment Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: alert.status == 'open'
                          ? colors.riskCritical.withValues(alpha: 0.35)
                          : colors.border,
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
                              'Unusual Activity Score',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            RiskScoreBadge(
                              score: alert.score,
                              threshold: alert.threshold,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${(alert.score * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              fontFeatures: AppTheme.tabularFigures,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Alert threshold ${(alert.threshold * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: alert.score.clamp(0.0, 1.0),
                          backgroundColor: colors.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            alert.score >= 0.8
                                ? colors.riskCritical
                                : colors.riskMedium,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      if (alert.latestVerdict != null) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Your decision:',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                            VerdictBadge(verdict: alert.latestVerdict!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Payment Details Card (Fixed USD overflow & double-conversion)
                if (txn != null) ...[
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
                            'Payment Summary',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Divider(color: colors.borderSubtle, height: 1),
                        _buildDetailRow(context, 'Merchant', txn.merchant),
                        Divider(color: colors.borderSubtle, height: 1),
                        _buildDetailRow(
                          context,
                          'Amount',
                          displayAmount,
                          valueColor: colors.riskCritical,
                          fontWeight: FontWeight.w700,
                        ),
                        if (txn.isSourceUsd &&
                            currencyProvider.isConvertedFromUsd)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Original USD: \$${txn.amount.toStringAsFixed(2)} (1 USD = ${currencyProvider.activeRateFromUsd.toStringAsFixed(2)} ${currencyProvider.activeCurrency})',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        Divider(color: colors.borderSubtle, height: 1),
                        _buildDetailRow(
                          context,
                          'Category',
                          AppColors.friendlyCategoryName(txn.category),
                        ),
                        Divider(color: colors.borderSubtle, height: 1),
                        _buildDetailRow(context, 'Account', txn.cardLabel),
                        Divider(color: colors.borderSubtle, height: 1),
                        _buildDetailRow(
                          context,
                          'Time',
                          dateFormat.format(txn.occurredAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Plain-English Reasons + Optional Technical Breakdown
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Why this was flagged',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (alert.reasons.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(
                                () => _showTechnicalFactors =
                                    !_showTechnicalFactors,
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _showTechnicalFactors
                                    ? 'Simple view'
                                    : 'Signal breakdown',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (alert.reasons.isEmpty)
                        Text(
                          'This transaction crossed your account risk threshold.',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        )
                      else if (_showTechnicalFactors)
                        ...alert.reasons.map((r) => ShapFactorCard(reason: r))
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: alert.reasons
                              .map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: r.impact >= 0.5
                                                ? colors.riskCritical
                                                : colors.textSecondary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          r.text,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 13.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            RichieChatSheet.show(
                              context,
                              initialPrompt:
                                  'Explain why Alert #${alert.id} ($displayAmount at ${txn?.merchant ?? "merchant"}) was flagged.',
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primaryBg,
                            foregroundColor: colors.isDark
                                ? colors.primarySoft
                                : colors.primary,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Ask Richie about this alert'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Human-Friendly Action Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Did you make this transaction?',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your response helps update protection for your account.',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildVerdictOption(
                        colors: colors,
                        value: 'false_positive',
                        title: 'Yes, this was me',
                        subtitle: 'Mark as legitimate spending',
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: colors.riskLow,
                      ),
                      const SizedBox(height: 8),
                      _buildVerdictOption(
                        colors: colors,
                        value: 'confirmed_fraud',
                        title: 'No, report as fraud',
                        subtitle: 'Flag unauthorized payment',
                        icon: Icons.gpp_bad_outlined,
                        accentColor: colors.riskCritical,
                      ),
                      const SizedBox(height: 8),
                      _buildVerdictOption(
                        colors: colors,
                        value: 'needs_info',
                        title: 'Not sure yet',
                        subtitle: 'Keep under review while you verify',
                        icon: Icons.schedule_rounded,
                        accentColor: colors.riskMedium,
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Add a note (optional)',
                          hintText: 'Any extra context for your record...',
                        ),
                      ),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: _submitting ? null : _submitVerdict,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Decision'),
                      ),
                    ],
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
