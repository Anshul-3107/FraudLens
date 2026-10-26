class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> itemJson) fromItemJson,
  ) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: resultsList
          .map((item) => fromItemJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasNext => next != null && next!.isNotEmpty;
  bool get hasPrevious => previous != null && previous!.isNotEmpty;
}
