import 'alert.dart';

class TransactionModel {
  final int id;
  final String transRef;
  final int card;
  final String cardLabel;
  final DateTime occurredAt;
  final String merchant;
  final String category;
  final double amount;
  final String source;
  final bool hasAlert;

  TransactionModel({
    required this.id,
    required this.transRef,
    required this.card,
    required this.cardLabel,
    required this.occurredAt,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.source,
    required this.hasAlert,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int? ?? 0,
      transRef: json['trans_ref'] as String? ?? '',
      card: json['card'] as int? ?? 0,
      cardLabel: json['card_label'] as String? ?? 'Card #${json['card']}',
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      merchant: json['merchant'] as String? ?? '',
      category: json['category'] as String? ?? '',
      amount: _parseDouble(json['amount']),
      source: json['source'] as String? ?? 'simulated',
      hasAlert: json['has_alert'] as bool? ?? false,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get formattedCategory {
    return category.replaceAll('_', ' ').toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trans_ref': transRef,
    'card': card,
    'card_label': cardLabel,
    'occurred_at': occurredAt.toIso8601String(),
    'merchant': merchant,
    'category': category,
    'amount': amount.toStringAsFixed(2),
    'source': source,
    'has_alert': hasAlert,
  };
}

class TransactionScoring {
  final double score;
  final bool flagged;
  final double threshold;
  final List<ShapReason> reasons;

  TransactionScoring({
    required this.score,
    required this.flagged,
    required this.threshold,
    required this.reasons,
  });

  factory TransactionScoring.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reasons'] as List<dynamic>? ?? [];
    return TransactionScoring(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      flagged: json['flagged'] as bool? ?? false,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.65,
      reasons: rawReasons
          .map((r) => ShapReason.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TransactionCreateResponse {
  final TransactionModel transaction;
  final TransactionScoring scoring;
  final int? alertId;

  TransactionCreateResponse({
    required this.transaction,
    required this.scoring,
    this.alertId,
  });

  factory TransactionCreateResponse.fromJson(Map<String, dynamic> json) {
    return TransactionCreateResponse(
      transaction: TransactionModel.fromJson(
        json['transaction'] as Map<String, dynamic>,
      ),
      scoring: TransactionScoring.fromJson(
        json['scoring'] as Map<String, dynamic>,
      ),
      alertId: json['alert_id'] as int?,
    );
  }
}

class TransactionCreateRequest {
  final int card;
  final DateTime occurredAt;
  final String merchant;
  final String category;
  final double amount;
  final double? merchLat;
  final double? merchLong;
  final String? transRef;
  final String source;

  TransactionCreateRequest({
    required this.card,
    required this.occurredAt,
    required this.merchant,
    required this.category,
    required this.amount,
    this.merchLat,
    this.merchLong,
    this.transRef,
    this.source = 'upload',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'card': card,
      'occurred_at': occurredAt.toIso8601String(),
      'merchant': merchant.trim(),
      'category': category,
      'amount': amount.toStringAsFixed(2),
      'source': source,
    };
    if (merchLat != null) map['merch_lat'] = merchLat;
    if (merchLong != null) map['merch_long'] = merchLong;
    if (transRef != null && transRef!.trim().isNotEmpty) {
      map['trans_ref'] = transRef!.trim();
    }
    return map;
  }
}

const List<String> kTransactionCategories = [
  'entertainment',
  'food_dining',
  'gas_transport',
  'grocery_net',
  'grocery_pos',
  'health_fitness',
  'home',
  'kids_pets',
  'misc_net',
  'misc_pos',
  'personal_care',
  'shopping_net',
  'shopping_pos',
  'travel',
];
