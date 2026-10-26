class ShapReason {
  final String factor;
  final double impact;
  final String text;

  ShapReason({required this.factor, required this.impact, required this.text});

  factory ShapReason.fromJson(Map<String, dynamic> json) {
    return ShapReason(
      factor: json['factor'] as String? ?? 'factor',
      impact: (json['impact'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'factor': factor,
    'impact': impact,
    'text': text,
  };
}

class AlertTransaction {
  final int id;
  final int card;
  final String cardLabel;
  final DateTime occurredAt;
  final String merchant;
  final String category;
  final double amount;

  AlertTransaction({
    required this.id,
    required this.card,
    required this.cardLabel,
    required this.occurredAt,
    required this.merchant,
    required this.category,
    required this.amount,
  });

  factory AlertTransaction.fromJson(Map<String, dynamic> json) {
    return AlertTransaction(
      id: json['id'] as int? ?? 0,
      card: json['card'] as int? ?? 0,
      cardLabel: json['card_label'] as String? ?? 'Card #${json['card']}',
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      merchant: json['merchant'] as String? ?? '',
      category: json['category'] as String? ?? '',
      amount: _parseDouble(json['amount']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class AlertModel {
  final int id;
  final double score;
  final double threshold;
  final List<ShapReason> reasons;
  final String status; // 'open', 'in_review', 'resolved'
  final DateTime createdAt;
  final AlertTransaction? transaction;
  final String?
  latestVerdict; // 'confirmed_fraud', 'false_positive', 'needs_info'

  AlertModel({
    required this.id,
    required this.score,
    required this.threshold,
    required this.reasons,
    required this.status,
    required this.createdAt,
    this.transaction,
    this.latestVerdict,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final reasonsList = json['reasons'] as List<dynamic>? ?? [];
    return AlertModel(
      id: json['id'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.65,
      reasons: reasonsList
          .map((r) => ShapReason.fromJson(r as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      transaction: json['transaction'] != null
          ? AlertTransaction.fromJson(
              json['transaction'] as Map<String, dynamic>,
            )
          : null,
      latestVerdict: json['latest_verdict'] as String?,
    );
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Open';
      case 'in_review':
        return 'In Review';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  String? get verdictDisplay {
    if (latestVerdict == null) return null;
    switch (latestVerdict!.toLowerCase()) {
      case 'confirmed_fraud':
        return 'Confirmed Fraud';
      case 'false_positive':
        return 'False Positive';
      case 'needs_info':
        return 'Needs Info';
      default:
        return latestVerdict;
    }
  }
}
