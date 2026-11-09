/// Parses UPI debit notifications, credit (money received) notifications, and official Bank SMS messages.
class ParsedUpiNotification {
  final double amount;
  final String merchant;
  final String? last4;
  final String bankName;
  final String packageName;
  final String inferredCategory;
  final String source; // 'notification' or 'sms'
  final String txnType; // 'sent' or 'received'
  final String currency; // 'INR'

  const ParsedUpiNotification({
    required this.amount,
    required this.merchant,
    this.last4,
    required this.bankName,
    required this.packageName,
    this.inferredCategory = 'misc_pos',
    this.source = 'notification',
    this.txnType = 'sent',
    this.currency = 'INR',
  });

  bool get isReceived => txnType == 'received';
  bool get isSent => txnType == 'sent';
}

class UpiParser {
  // Regex patterns for Indian UPI and Bank SMS payment notifications (Debit & Credit):
  // e.g. "Paid Rs. 500 to Starbucks"
  // e.g. "Received ₹100 from Rajesh Arohi"
  // e.g. "Rajesh Arohi sent you ₹100"
  // e.g. "INR 100.00 credited to HDFC Bank A/c ending 9719 on 09-NOV-26 by RAJESH AROHI"
  // e.g. "Rs 1,250 debited from A/c XX9719 at Starbucks"
  static final RegExp _amountRegex = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)|(?:debited by|debited with|credited by|credited with|paid|spent|received)\s*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _merchantRegex = RegExp(
    r'(?:to|at|for|paid to|sent to|spent at)\s+([A-Za-z0-9\s&.\-_]+?)(?:\s+(?:using|from|via|on|ref|upi|txn|bal|avail)|$|\.)',
    caseSensitive: false,
  );

  static final RegExp _senderReceivedRegex = RegExp(
    r'(?:from|by|received from|transfer from)\s+([A-Za-z0-9\s&.\-_/@]+?)(?:\s+(?:using|via|on|ref|upi|txn|bal|avail|balance)|\.|$)',
    caseSensitive: false,
  );

  static final RegExp _sentYouRegex = RegExp(
    r'([A-Za-z0-9\s&.\-_]+?)\s+sent\s+(?:you\s+)?(?:Rs\.?|INR|₹)',
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

  static String _cleanSenderName(String name) {
    var cleaned = name.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[\s.,;:\-_]+$'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'^(?:PhonePe|Google Pay|GPay|Paytm|Alert:?|Dear Customer,?)\s*', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  static ParsedUpiNotification? parse({
    required String packageName,
    required String title,
    required String text,
    String source = 'notification',
  }) {
    final combined = '$title $text';
    final lowerCombined = combined.toLowerCase();

    // 1. Amount Extraction
    final amtMatch = _amountRegex.firstMatch(combined);
    if (amtMatch == null) return null;

    final rawAmtStr = amtMatch.group(1) ?? amtMatch.group(2);
    if (rawAmtStr == null) return null;

    final cleanAmt = double.tryParse(rawAmtStr.replaceAll(',', ''));
    if (cleanAmt == null || cleanAmt <= 0) return null;

    // 2. Transaction Direction: Money Received (Credit) vs Money Sent (Debit)
    bool isReceived = false;
    if (lowerCombined.contains('received') ||
        lowerCombined.contains('credited') ||
        lowerCombined.contains('sent you') ||
        lowerCombined.contains('transferred to you') ||
        lowerCombined.contains('deposited') ||
        lowerCombined.contains('refunded') ||
        lowerCombined.contains('cashback') ||
        lowerCombined.contains('cr.') ||
        lowerCombined.contains('cr ') ||
        lowerCombined.contains(' credited') ||
        lowerCombined.contains('has been credited')) {
      isReceived = true;
    }

    final txnType = isReceived ? 'received' : 'sent';

    // 3. Sender / Merchant Extraction
    String merchant = isReceived ? 'Sender' : 'UPI Merchant';
    if (isReceived) {
      final sentMatch = _sentYouRegex.firstMatch(text) ?? _sentYouRegex.firstMatch(combined);
      if (sentMatch != null) {
        String cand = sentMatch.group(1)?.trim() ?? '';
        cand = _cleanSenderName(cand);
        if (cand.length >= 2) {
          merchant = cand;
        }
      } else {
        final recMatch = _senderReceivedRegex.firstMatch(combined);
        if (recMatch != null) {
          String cand = recMatch.group(1)?.trim() ?? '';
          if (cand.toUpperCase().startsWith('UPI/') || cand.toUpperCase().startsWith('VPA/')) {
            final parts = cand.split('/');
            cand = parts.last.trim();
          }
          cand = _cleanSenderName(cand);
          if (cand.length >= 2 &&
              !cand.toLowerCase().contains('account') &&
              !cand.toLowerCase().contains('bank') &&
              !cand.toLowerCase().contains('ending')) {
            merchant = cand;
          }
        }
      }
    } else {
      final merchMatch = _merchantRegex.firstMatch(combined);
      if (merchMatch != null) {
        var candidate = merchMatch.group(1)?.trim();
        if (candidate != null) {
          candidate = _cleanSenderName(candidate);
          if (candidate.length >= 2 &&
              !candidate.toLowerCase().contains('account') &&
              !candidate.toLowerCase().contains('bank') &&
              !candidate.toLowerCase().contains('ending')) {
            merchant = candidate;
          }
        }
      }
    }

    // 4. Last 4 digits extraction
    String? last4;
    final last4Match = _last4Regex.firstMatch(combined);
    if (last4Match != null) {
      last4 = last4Match.group(1);
    }

    // 5. Bank Name
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

    // 6. Inferred Category Heuristic
    final lowerMerch = merchant.toLowerCase();
    String category = 'misc_pos';
    if (isReceived) {
      category = 'misc_pos';
    } else if (lowerMerch.contains('starbucks') ||
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
      txnType: txnType,
      currency: 'INR',
    );
  }
}
