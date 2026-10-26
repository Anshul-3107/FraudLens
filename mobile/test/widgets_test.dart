import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraudlens/models/alert.dart';
import 'package:fraudlens/widgets/loading_indicator.dart';
import 'package:fraudlens/widgets/metric_card.dart';
import 'package:fraudlens/widgets/risk_badge.dart';
import 'package:fraudlens/widgets/shap_factor_card.dart';

void main() {
  group('Fintech Design Components & Badges Tests', () {
    testWidgets(
      'RiskScoreBadge displays critical, high, and low levels correctly',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  RiskScoreBadge(score: 0.95),
                  RiskScoreBadge(score: 0.70),
                  RiskScoreBadge(score: 0.15),
                ],
              ),
            ),
          ),
        );

        expect(find.text('CRITICAL (95.0%)'), findsOneWidget);
        expect(find.text('HIGH RISK (70.0%)'), findsOneWidget);
        expect(find.text('LOW RISK (15.0%)'), findsOneWidget);
      },
    );

    testWidgets(
      'AlertStatusBadge displays Open, In Review, and Resolved statuses',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AlertStatusBadge(status: 'open'),
                  AlertStatusBadge(status: 'in_review'),
                  AlertStatusBadge(status: 'resolved'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Open'), findsOneWidget);
        expect(find.text('In Review'), findsOneWidget);
        expect(find.text('Resolved'), findsOneWidget);
      },
    );

    testWidgets('VerdictBadge displays Confirmed Fraud and False Positive', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VerdictBadge(verdict: 'confirmed_fraud'),
                VerdictBadge(verdict: 'false_positive'),
                VerdictBadge(verdict: 'needs_info'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Confirmed Fraud'), findsOneWidget);
      expect(find.text('False Positive'), findsOneWidget);
      expect(find.text('Needs Info'), findsOneWidget);
    });

    testWidgets('MetricCard renders key title and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Total Volume',
              value: '\$1,234,567.89',
              subtitle: 'Portfolio total',
              icon: Icons.payments_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Total Volume'), findsOneWidget);
      expect(find.text('\$1,234,567.89'), findsOneWidget);
      expect(find.text('Portfolio total'), findsOneWidget);
    });

    testWidgets('ShapFactorCard renders TreeSHAP factor and impact gauge', (
      tester,
    ) async {
      final reason = ShapReason(
        factor: 'amount',
        impact: 0.452,
        text: 'Amount \$950.00 is 3.5x this card average spend',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ShapFactorCard(reason: reason)),
        ),
      );

      expect(find.text('Spend Amount Anomaly'), findsOneWidget);
      expect(find.text('+0.45 SHAP'), findsOneWidget);
      expect(
        find.text('Amount \$950.00 is 3.5x this card average spend'),
        findsOneWidget,
      );
    });

    testWidgets('FintechLoadingIndicator renders label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FintechLoadingIndicator(label: 'Scoring transaction...'),
          ),
        ),
      );

      expect(find.text('Scoring transaction...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
