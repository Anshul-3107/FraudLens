import 'package:flutter_test/flutter_test.dart';
import 'package:fraudlens/services/upi_parser.dart';

void main() {
  group('UpiParser Indian Payment Notification Tests', () {
    test('Parses Google Pay notification with amount, merchant, and bank', () {
      const pkg = 'com.google.android.apps.nbu.paisa.user';
      const title = 'Google Pay';
      const text = 'Paid ₹500.00 to Starbucks using HDFC Bank •• 9719';

      final parsed = UpiParser.parse(
        packageName: pkg,
        title: title,
        text: text,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 500.00);
      expect(parsed.merchant.toLowerCase(), contains('starbucks'));
      expect(parsed.last4, '9719');
      expect(parsed.bankName, 'HDFC Bank');
      expect(parsed.inferredCategory, 'food_dining');
    });

    test('Parses PhonePe notification with debited format', () {
      const pkg = 'com.phonepe.app';
      const title = 'PhonePe';
      const text = 'Rs. 1,250 debited from A/c XX4321 for Swiggy';

      final parsed = UpiParser.parse(
        packageName: pkg,
        title: title,
        text: text,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1250.0);
      expect(parsed.merchant.toLowerCase(), contains('swiggy'));
      expect(parsed.last4, '4321');
      expect(parsed.inferredCategory, 'food_dining');
    });

    test('Ignores non-payment notification', () {
      const pkg = 'com.google.android.apps.nbu.paisa.user';
      const title = 'Google Pay';
      const text = 'Check out the latest cashbacks and scratch cards!';

      final parsed = UpiParser.parse(
        packageName: pkg,
        title: title,
        text: text,
      );

      expect(parsed, isNull);
    });
  });
}
