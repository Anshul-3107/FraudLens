import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/alert.dart';
import '../../models/investigation.dart';
import '../../providers/alert_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/investigation_provider.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/shap_factor_card.dart';

class AlertDetailScreen extends StatefulWidget {
  final AlertModel alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late AlertModel _currentAlert;
  String _selectedVerdict = 'confirmed_fraud';
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _currentAlert = widget.alert;
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

      // Refresh dashboard summary and investigations list
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
            content: Text(
              'Investigation verdict "${invResult.verdictDisplay}" recorded successfully.',
            ),
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
            content: Text('Failed to record verdict: $e'),
            backgroundColor: colors.riskCritical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final alert = _currentAlert;
    final txn = alert.transaction;
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm:ss a');

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Risk Score Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.riskCritical.withValues(alpha: 0.3),
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
                        'AI FRAUD RISK EVALUATION',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      RiskScoreBadge(
                        score: alert.score,
                        threshold: alert.threshold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${(alert.score * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Probability exceeding ${(alert.threshold * 100).toStringAsFixed(0)}% decision threshold',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
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
                      backgroundColor: colors.surfaceSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        alert.score >= 0.8
                            ? colors.riskCritical
                            : colors.riskMedium,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  if (alert.latestVerdict != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Latest Analyst Verdict: ',
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

            // Associated Transaction Card
            if (txn != null) ...[
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
                      'Flagged Transaction Details',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: colors.borderSubtle),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Merchant',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          txn.merchant,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          currencyFormat.format(txn.amount),
                          style: TextStyle(
                            color: colors.riskCritical,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          txn.category.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Card Label',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          txn.cardLabel,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction Time',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          dateFormat.format(txn.occurredAt),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Explainable AI / SHAP Factors Card
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
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TreeSHAP Explainability Factors',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Identified by the model as contributing most strongly to this transaction being flagged:',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  if (alert.reasons.isEmpty)
                    Text(
                      'No specific SHAP factors provided for this score threshold.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  else
                    ...alert.reasons.map((r) => ShapFactorCard(reason: r)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Investigation Action Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSubtle, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Analyst Investigation',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assign a formal verdict and log your review findings for auditing.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Verdict Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVerdict,
                    decoration: const InputDecoration(
                      labelText: 'Investigation Verdict',
                      prefixIcon: Icon(Icons.gavel_rounded, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'confirmed_fraud',
                        child: Text('Confirmed Fraud (Block & Resolve)'),
                      ),
                      DropdownMenuItem(
                        value: 'false_positive',
                        child: Text('False Positive (Legitimate Spend)'),
                      ),
                      DropdownMenuItem(
                        value: 'needs_info',
                        child: Text('Needs More Information (Keep In Review)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVerdict = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Analyst Findings & Notes',
                      hintText: 'e.g. Cardholder contacted via SMS; confirmed unapproved transaction from foreign IP...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitVerdict,
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
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _submitting
                            ? 'Recording Verdict...'
                            : 'Submit Investigation Verdict',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedVerdict == 'confirmed_fraud'
                            ? colors.riskCritical
                            : _selectedVerdict == 'false_positive'
                            ? colors.riskLow
                            : colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
