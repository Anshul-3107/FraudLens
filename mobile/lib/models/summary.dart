class CategorySpend {
  final String category;
  final double total;
  final int count;

  CategorySpend({
    required this.category,
    required this.total,
    required this.count,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> json) {
    return CategorySpend(
      category: json['category'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }

  String get formattedCategory {
    return category.replaceAll('_', ' ').toUpperCase();
  }
}

class MonthlySpend {
  final String month; // e.g. "2020-01"
  final double total;
  final int count;

  MonthlySpend({required this.month, required this.total, required this.count});

  factory MonthlySpend.fromJson(Map<String, dynamic> json) {
    return MonthlySpend(
      month: json['month'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class AlertsByStatus {
  final int open;
  final int inReview;
  final int resolved;

  AlertsByStatus({
    required this.open,
    required this.inReview,
    required this.resolved,
  });

  factory AlertsByStatus.fromJson(Map<String, dynamic> json) {
    return AlertsByStatus(
      open: json['open'] as int? ?? 0,
      inReview: json['in_review'] as int? ?? 0,
      resolved: json['resolved'] as int? ?? 0,
    );
  }

  int get total => open + inReview + resolved;
}

class SummaryModel {
  final double totalSpend;
  final int transactionCount;
  final AlertsByStatus alertsByStatus;
  final List<CategorySpend> byCategory;
  final List<MonthlySpend> monthly;

  SummaryModel({
    required this.totalSpend,
    required this.transactionCount,
    required this.alertsByStatus,
    required this.byCategory,
    required this.monthly,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    final alertsMap = json['alerts_by_status'] as Map<String, dynamic>? ?? {};
    final catList = json['by_category'] as List<dynamic>? ?? [];
    final monthList = json['monthly'] as List<dynamic>? ?? [];

    return SummaryModel(
      totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      alertsByStatus: AlertsByStatus.fromJson(alertsMap),
      byCategory: catList
          .map((c) => CategorySpend.fromJson(c as Map<String, dynamic>))
          .toList(),
      monthly: monthList
          .map((m) => MonthlySpend.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
