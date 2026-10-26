class InvestigationModel {
  final int id;
  final int alert;
  final String? analystName;
  final String verdict;
  final String notes;
  final DateTime createdAt;
  final String merchant;
  final double amount;
  final DateTime occurredAt;

  InvestigationModel({
    required this.id,
    required this.alert,
    this.analystName,
    required this.verdict,
    required this.notes,
    required this.createdAt,
    required this.merchant,
    required this.amount,
    required this.occurredAt,
  });

  factory InvestigationModel.fromJson(Map<String, dynamic> json) {
    return InvestigationModel(
      id: json['id'] as int? ?? 0,
      alert: json['alert'] as int? ?? 0,
      analystName: json['analyst_name'] as String?,
      verdict: json['verdict'] as String? ?? 'needs_info',
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      merchant: json['merchant'] as String? ?? '',
      amount: _parseDouble(json['amount']),
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get verdictDisplay {
    switch (verdict.toLowerCase()) {
      case 'confirmed_fraud':
        return 'Confirmed Fraud';
      case 'false_positive':
        return 'False Positive';
      case 'needs_info':
        return 'Needs Info';
      default:
        return verdict;
    }
  }
}

class InvestigationCreateRequest {
  final String verdict; // 'confirmed_fraud', 'false_positive', 'needs_info'
  final String notes;

  InvestigationCreateRequest({required this.verdict, this.notes = ''});

  Map<String, dynamic> toJson() => {'verdict': verdict, 'notes': notes};
}
