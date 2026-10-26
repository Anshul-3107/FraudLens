class CardModel {
  final int id;
  final String label;

  CardModel({required this.id, required this.label});

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as int? ?? 0,
      label: json['label'] as String? ?? 'Card #${json['id']}',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
