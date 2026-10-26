import 'package:flutter_test/flutter_test.dart';
import 'package:fraudlens/models/alert.dart';
import 'package:fraudlens/models/card.dart';
import 'package:fraudlens/models/investigation.dart';
import 'package:fraudlens/models/paginated_response.dart';
import 'package:fraudlens/models/summary.dart';
import 'package:fraudlens/models/transaction.dart';
import 'package:fraudlens/models/user.dart';

void main() {
  group('Backend API Response Contracts & Model Parsing', () {
    test('UserMe parses GET /api/auth/me/ format', () {
      final json = {
        'id': 1,
        'username': 'anshularohi',
        'email': 'example@gmail.com',
        'is_staff': true,
        'card_count': 100,
      };

      final user = UserMe.fromJson(json);
      expect(user.id, 1);
      expect(user.username, 'anshularohi');
      expect(user.email, 'example@gmail.com');
      expect(user.isStaff, true);
      expect(user.cardCount, 100);
    });

    test('CardModel parses CardSerializer format', () {
      final json = {'id': 42, 'label': 'Visa 9876'};
      final card = CardModel.fromJson(json);
      expect(card.id, 42);
      expect(card.label, 'Visa 9876');
    });

    test('TransactionModel parses TransactionSerializer format', () {
      final json = {
        'id': 101,
        'trans_ref': 'ref-abc-123',
        'card': 5,
        'card_label': 'Mastercard 1234',
        'occurred_at': '2021-01-05T23:30:00Z',
        'merchant': 'fraud_Kirlin and Sons',
        'category': 'grocery_pos',
        'amount': '124.50',
        'source': 'upload',
        'has_alert': true,
      };

      final txn = TransactionModel.fromJson(json);
      expect(txn.id, 101);
      expect(txn.transRef, 'ref-abc-123');
      expect(txn.card, 5);
      expect(txn.cardLabel, 'Mastercard 1234');
      expect(txn.merchant, 'fraud_Kirlin and Sons');
      expect(txn.category, 'grocery_pos');
      expect(txn.formattedCategory, 'GROCERY POS');
      expect(txn.amount, 124.50);
      expect(txn.source, 'upload');
      expect(txn.hasAlert, true);
    });

    test('AlertModel parses AlertSerializer with SHAP reasons format', () {
      final json = {
        'id': 7,
        'score': 0.892,
        'threshold': 0.65,
        'reasons': [
          {
            'factor': 'amount',
            'impact': 0.452,
            'text': 'Amount \$950.00 is 3.5x this card\'s average spend',
          },
          {
            'factor': 'time',
            'impact': 0.281,
            'text': 'Late-night transaction (02:00)',
          },
        ],
        'status': 'open',
        'created_at': '2021-01-05T23:31:00Z',
        'transaction': {
          'id': 101,
          'card': 5,
          'card_label': 'Mastercard 1234',
          'occurred_at': '2021-01-05T23:30:00Z',
          'merchant': 'fraud_Kirlin and Sons',
          'category': 'grocery_pos',
          'amount': '950.00',
        },
        'latest_verdict': null,
      };

      final alert = AlertModel.fromJson(json);
      expect(alert.id, 7);
      expect(alert.score, 0.892);
      expect(alert.threshold, 0.65);
      expect(alert.status, 'open');
      expect(alert.statusDisplay, 'Open');
      expect(alert.reasons.length, 2);
      expect(alert.reasons[0].factor, 'amount');
      expect(alert.reasons[0].impact, 0.452);
      expect(alert.reasons[0].text, contains('\$950.00'));
      expect(alert.transaction?.merchant, 'fraud_Kirlin and Sons');
      expect(alert.transaction?.amount, 950.00);
      expect(alert.latestVerdict, isNull);
    });

    test('InvestigationModel parses InvestigationSerializer format', () {
      final json = {
        'id': 12,
        'alert': 7,
        'analyst_name': 'anshularohi',
        'verdict': 'confirmed_fraud',
        'notes': 'Cardholder confirmed account takeover',
        'created_at': '2021-01-06T10:00:00Z',
        'merchant': 'fraud_Kirlin and Sons',
        'amount': '950.00',
        'occurred_at': '2021-01-05T23:30:00Z',
      };

      final inv = InvestigationModel.fromJson(json);
      expect(inv.id, 12);
      expect(inv.alert, 7);
      expect(inv.analystName, 'anshularohi');
      expect(inv.verdict, 'confirmed_fraud');
      expect(inv.verdictDisplay, 'Confirmed Fraud');
      expect(inv.notes, contains('Cardholder confirmed'));
      expect(inv.amount, 950.00);
    });

    test('SummaryModel parses SummaryView output format', () {
      final json = {
        'total_spend': 54321.80,
        'transaction_count': 1200,
        'alerts_by_status': {'open': 15, 'in_review': 4, 'resolved': 50},
        'by_category': [
          {'category': 'grocery_pos', 'total': 12000.50, 'count': 350},
          {'category': 'gas_transport', 'total': 8000.25, 'count': 210},
        ],
        'monthly': [
          {'month': '2020-01', 'total': 25000.00, 'count': 600},
          {'month': '2020-02', 'total': 29321.80, 'count': 600},
        ],
      };

      final summary = SummaryModel.fromJson(json);
      expect(summary.totalSpend, 54321.80);
      expect(summary.transactionCount, 1200);
      expect(summary.alertsByStatus.open, 15);
      expect(summary.alertsByStatus.inReview, 4);
      expect(summary.alertsByStatus.resolved, 50);
      expect(summary.alertsByStatus.total, 69);
      expect(summary.byCategory.length, 2);
      expect(summary.byCategory[0].category, 'grocery_pos');
      expect(summary.monthly.length, 2);
      expect(summary.monthly[0].month, '2020-01');
    });

    test('PaginatedResponse handles DRF PageNumberPagination schema', () {
      final json = {
        'count': 150,
        'next': 'http://127.0.0.1:8000/api/cards/?page=2',
        'previous': null,
        'results': [
          {'id': 1, 'label': 'Card 1'},
          {'id': 2, 'label': 'Card 2'},
        ],
      };

      final resp = PaginatedResponse<CardModel>.fromJson(
        json,
        (item) => CardModel.fromJson(item),
      );

      expect(resp.count, 150);
      expect(resp.hasNext, true);
      expect(resp.hasPrevious, false);
      expect(resp.results.length, 2);
      expect(resp.results[0].id, 1);
      expect(resp.results[1].label, 'Card 2');
    });
  });
}
