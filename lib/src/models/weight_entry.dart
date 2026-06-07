/// A single body-weight reading logged by the user (kg).
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.kg,
    required this.timestamp,
  });

  final String id;
  final double kg;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kg': kg,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        kg: (json['kg'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
