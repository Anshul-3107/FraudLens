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

    test('Parses official HDFC Bank SMS format with source sms', () {
      const sender = 'VK-HDFCBK';
      const text =
          'Alert: INR 750.00 debited from HDFC Bank A/c ending 9719 on 09-NOV-26 to ZOMATO. Bal: INR 15,240.00';

      final parsed = UpiParser.parse(
        packageName: 'android.telephony.sms',
        title: sender,
        text: text,
        source: 'sms',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 750.00);
      expect(parsed.merchant.toLowerCase(), contains('zomato'));
      expect(parsed.last4, '9719');
      expect(parsed.bankName, 'HDFC Bank');
      expect(parsed.source, 'sms');
      expect(parsed.inferredCategory, 'food_dining');
    });

    test('Parses official SBI Bank SMS format', () {
      const sender = 'AD-SBIINB';
      const text =
          'Your A/C ending 4321 debited by Rs 320.00 on 09Nov26 transfer to BLINKIT Ref 431987. Avail Bal Rs 4,500.00';

      final parsed = UpiParser.parse(
        packageName: 'android.telephony.sms',
        title: sender,
        text: text,
        source: 'sms',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 320.00);
      expect(parsed.merchant.toLowerCase(), contains('blinkit'));
      expect(parsed.last4, '4321');
      expect(parsed.source, 'sms');
      expect(parsed.inferredCategory, 'grocery_pos');
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
