/// A single body-weight reading logged by the user (kg).
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.kg,
    required this.timestamp,
    this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final double kg;
  final DateTime timestamp;

  /// Sync metadata (see [FoodEntry]). Null on pre-sync rows; [syncUpdatedAt]
  /// falls back to [timestamp].
  final DateTime? updatedAt;
  final bool deleted;

  DateTime get syncUpdatedAt => updatedAt ?? timestamp;

  WeightEntry copyWith({
    double? kg,
    DateTime? timestamp,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return WeightEntry(
      id: id,
      kg: kg ?? this.kg,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kg': kg,
        'timestamp': timestamp.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'deleted': deleted,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        kg: (json['kg'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        deleted: (json['deleted'] as bool?) ?? false,
      );
}
