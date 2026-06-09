/// The meal an entry belongs to. Pure Dart (no Flutter) so it stays testable.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snack',
  };
}
