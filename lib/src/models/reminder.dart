import 'meal_type.dart';

/// A single daily food-logging reminder: a meal kind (which picks the icon and
/// the funny copy) at an [hour]:[minute] local time, individually toggleable.
/// Pure Dart (no Flutter) so it stays testable.
class Reminder {
  const Reminder({
    required this.id,
    required this.meal,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  final String id;
  final MealType meal;
  final int hour; // 0–23
  final int minute; // 0–59
  final bool enabled;

  Reminder copyWith({
    MealType? meal,
    int? hour,
    int? minute,
    bool? enabled,
  }) => Reminder(
    id: id,
    meal: meal ?? this.meal,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'meal': meal.name,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
  };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'] as String,
    meal: MealType.values.firstWhere(
      (m) => m.name == j['meal'],
      orElse: () => MealType.snack,
    ),
    hour: (j['hour'] as num).toInt(),
    minute: (j['minute'] as num).toInt(),
    enabled: j['enabled'] as bool? ?? true,
  );

  /// The reminders a fresh install starts with: breakfast, lunch and dinner on,
  /// plus a late-night (snack) check-in that's off by default. The user can
  /// retime, toggle, add or delete any of them.
  static List<Reminder> defaults() => const [
    Reminder(id: 'breakfast', meal: MealType.breakfast, hour: 8, minute: 0),
    Reminder(id: 'lunch', meal: MealType.lunch, hour: 12, minute: 0),
    Reminder(id: 'dinner', meal: MealType.dinner, hour: 19, minute: 0),
    Reminder(
      id: 'snack',
      meal: MealType.snack,
      hour: 22,
      minute: 0,
      enabled: false,
    ),
  ];
}
