/// Structured nutrition estimate returned by Claude's vision analysis.
/// Maps from the `log_food` tool input Claude is forced to produce.
class FoodAnalysis {
  const FoodAnalysis({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.satFatG,
    required this.portionDescription,
    required this.confidence,
    this.items = const [],
    this.notes,
  });

  final String name;
  final double calories;
  final double proteinG;
  final double satFatG;
  final String portionDescription;

  /// 'low' | 'medium' | 'high'.
  final String confidence;
  final List<String> items;
  final String? notes;

  factory FoodAnalysis.fromToolInput(Map<String, dynamic> input) {
    double asNum(Object? v) => v is num ? v.toDouble() : 0.0;
    final name = (input['name'] as String?)?.trim();
    return FoodAnalysis(
      name: (name == null || name.isEmpty) ? 'Food' : name,
      calories: asNum(input['calories']),
      proteinG: asNum(input['proteinG']),
      satFatG: asNum(input['satFatG']),
      portionDescription:
          (input['portionDescription'] as String?)?.trim() ?? '',
      confidence:
          (input['confidence'] as String?)?.trim().toLowerCase() ?? 'medium',
      items: (input['items'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      notes: (input['notes'] as String?)?.trim(),
    );
  }
}
