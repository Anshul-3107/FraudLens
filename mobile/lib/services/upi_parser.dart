/// Parses UPI debit notifications and official Bank SMS debits.
class ParsedUpiNotification {
  final double amount;
  final String merchant;
  final String? last4;
  final String bankName;
  final String packageName;
  final String inferredCategory;
  final String source; // 'notification' or 'sms'

  const ParsedUpiNotification({
    required this.amount,
    required this.merchant,
    this.last4,
    required this.bankName,
    required this.packageName,
    this.inferredCategory = 'misc_pos',
    this.source = 'notification',
  });
}

class UpiParser {
  // Regex patterns for Indian UPI and Bank SMS payment debit notifications:
  // e.g. "Paid Rs. 500 to Starbucks"
  // e.g. "Rs 1,250 debited from A/c XX9719 at Starbucks"
  // e.g. "Sent Rs. 350 to Swiggy using HDFC Bank •• 9719"
  // e.g. "Debited INR 450.00 from your SBI account ... to Zomato"
  // e.g. "Alert: INR 500.00 debited from HDFC Bank A/c ending 9719 on 09-NOV-26 to STARBUCKS. Bal: INR 12,450.00"
  static final RegExp _amountRegex = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)|(?:debited by|paid|spent)\s*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _merchantRegex = RegExp(
    r'(?:to|at|for|paid to|sent to|spent at)\s+([A-Za-z0-9\s&.\-_]+?)(?:\s+(?:using|from|via|on|ref|upi|txn|bal|avail)|$|\.)',
    caseSensitive: false,
  );

  static final RegExp _last4Regex = RegExp(
    r'(?:a/c|ac|account|card|ending|••|xx|x)\s*[:#\s]*([0-9]{4})\b',
    caseSensitive: false,
  );

  static final RegExp _bankRegex = RegExp(
    r'\b(HDFC|SBI|ICICI|AXIS|KOTAK|PNB|BOB|CANARA|UNION|INDUSIND|YES|PAYTM)\b',
    caseSensitive: false,
  );

  static ParsedUpiNotification? parse({
    required String packageName,
    required String title,
    required String text,
    String source = 'notification',
  }) {
    final combined = '$title $text';

    // 1. Amount Extraction
    final amtMatch = _amountRegex.firstMatch(combined);
    if (amtMatch == null) return null;

    final rawAmtStr = amtMatch.group(1) ?? amtMatch.group(2);
    if (rawAmtStr == null) return null;

    final cleanAmt = double.tryParse(rawAmtStr.replaceAll(',', ''));
    if (cleanAmt == null || cleanAmt <= 0) return null;

    // 2. Merchant Extraction
    String merchant = 'UPI Merchant';
    final merchMatch = _merchantRegex.firstMatch(combined);
    if (merchMatch != null) {
      final candidate = merchMatch.group(1)?.trim();
      if (candidate != null &&
          candidate.length >= 2 &&
          !candidate.toLowerCase().contains('account') &&
          !candidate.toLowerCase().contains('bank') &&
          !candidate.toLowerCase().contains('ending')) {
        merchant = candidate;
      }
    }

    // 3. Last 4 digits extraction
    String? last4;
    final last4Match = _last4Regex.firstMatch(combined);
    if (last4Match != null) {
      last4 = last4Match.group(1);
    }

    // 4. Bank Name
    String bankName = 'UPI Bank';
    final bankMatch = _bankRegex.firstMatch(combined);
    if (bankMatch != null) {
      bankName = '${bankMatch.group(1)?.toUpperCase()} Bank';
    } else if (packageName.contains('paisa')) {
      bankName = 'Google Pay';
    } else if (packageName.contains('phonepe')) {
      bankName = 'PhonePe';
    } else if (source == 'sms') {
      bankName = 'Bank SMS';
    }

    // 5. Inferred Category Heuristic
    final lowerMerch = merchant.toLowerCase();
    String category = 'misc_pos';
    if (lowerMerch.contains('starbucks') ||
        lowerMerch.contains('swiggy') ||
        lowerMerch.contains('zomato') ||
        lowerMerch.contains('cafe') ||
        lowerMerch.contains('restaurant') ||
        lowerMerch.contains('food') ||
        lowerMerch.contains('mcdonald') ||
        lowerMerch.contains('burger')) {
      category = 'food_dining';
    } else if (lowerMerch.contains('grocery') ||
        lowerMerch.contains('blinkit') ||
        lowerMerch.contains('zepto') ||
        lowerMerch.contains('instamart') ||
        lowerMerch.contains('supermarket')) {
      category = 'grocery_pos';
    } else if (lowerMerch.contains('uber') ||
        lowerMerch.contains('ola') ||
        lowerMerch.contains('fuel') ||
        lowerMerch.contains('petrol') ||
        lowerMerch.contains('metro')) {
      category = 'gas_transport';
    } else if (lowerMerch.contains('amazon') ||
        lowerMerch.contains('flipkart') ||
        lowerMerch.contains('myntra')) {
      category = 'shopping_net';
    } else if (lowerMerch.contains('pvr') ||
        lowerMerch.contains('inox') ||
        lowerMerch.contains('cinema') ||
        lowerMerch.contains('netflix') ||
        lowerMerch.contains('spotify')) {
      category = 'entertainment';
    }

    return ParsedUpiNotification(
      amount: cleanAmt,
      merchant: merchant,
      last4: last4,
      bankName: bankName,
      packageName: packageName,
      inferredCategory: category,
      source: source,
    );
  }
}
