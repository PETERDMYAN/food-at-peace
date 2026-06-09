/// Biological sex, used by the Mifflin-St Jeor BMR equation.
enum Sex {
  male,
  female;

  String get label => this == Sex.male ? 'Male' : 'Female';
}

/// Activity level → multiplier applied to BMR to estimate total daily
/// energy expenditure (used in Phase 1 before HealthKit supplies real data).
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.light => 'Lightly active',
        ActivityLevel.moderate => 'Moderately active',
        ActivityLevel.active => 'Active',
        ActivityLevel.veryActive => 'Very active',
      };

  String get hint => switch (this) {
        ActivityLevel.sedentary => 'Little or no exercise',
        ActivityLevel.light => 'Exercise 1-3 days/week',
        ActivityLevel.moderate => 'Exercise 3-5 days/week',
        ActivityLevel.active => 'Exercise 6-7 days/week',
        ActivityLevel.veryActive => 'Hard exercise or physical job',
      };

  double get multiplier => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };
}

/// The user's weight goal. The adjustment is added to expenditure to get the
/// daily calorie *intake* target (a deficit for losing, surplus for gaining).
enum Goal {
  lose,
  maintain,
  gain;

  String get label => switch (this) {
        Goal.lose => 'Lose weight',
        Goal.maintain => 'Maintain',
        Goal.gain => 'Gain muscle',
      };

  /// kcal/day added to expenditure. -500 ≈ 0.45 kg/week loss.
  double get calorieAdjustment => switch (this) {
        Goal.lose => -500,
        Goal.maintain => 0,
        Goal.gain => 400,
      };
}

/// The user's profile that drives all targets. [isConfigured] is false until
/// the user saves their details in Settings (we still compute with defaults).
class UserProfile {
  const UserProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
    this.isConfigured = false,
    this.updatedAt,
    this.calorieTargetOverride,
    this.proteinTargetOverride,
    this.satFatTargetOverride,
  });

  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final Goal goal;
  final bool isConfigured;

  /// Optional manual target overrides (null = use the computed value). They
  /// drive the Today screen and sync with the profile.
  final double? calorieTargetOverride;
  final double? proteinTargetOverride;
  final double? satFatTargetOverride;

  /// Sync metadata: when the profile was last saved (null until first save).
  final DateTime? updatedAt;

  DateTime get syncUpdatedAt =>
      updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  static const UserProfile defaultProfile = UserProfile(
    sex: Sex.male,
    age: 30,
    heightCm: 175,
    weightKg: 75,
    activity: ActivityLevel.moderate,
    goal: Goal.maintain,
    isConfigured: false,
  );

  /// Sentinel so [copyWith] can tell "leave as-is" from "set to null" for the
  /// nullable target overrides (e.g. clearing a field reverts to the computed
  /// value).
  static const Object _keep = Object();

  UserProfile copyWith({
    Sex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    Goal? goal,
    bool? isConfigured,
    DateTime? updatedAt,
    Object? calorieTargetOverride = _keep,
    Object? proteinTargetOverride = _keep,
    Object? satFatTargetOverride = _keep,
  }) {
    return UserProfile(
      sex: sex ?? this.sex,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      isConfigured: isConfigured ?? this.isConfigured,
      updatedAt: updatedAt ?? this.updatedAt,
      calorieTargetOverride: identical(calorieTargetOverride, _keep)
          ? this.calorieTargetOverride
          : (calorieTargetOverride as num?)?.toDouble(),
      proteinTargetOverride: identical(proteinTargetOverride, _keep)
          ? this.proteinTargetOverride
          : (proteinTargetOverride as num?)?.toDouble(),
      satFatTargetOverride: identical(satFatTargetOverride, _keep)
          ? this.satFatTargetOverride
          : (satFatTargetOverride as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sex': sex.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity.name,
        'goal': goal.name,
        'isConfigured': isConfigured,
        'updatedAt': updatedAt?.toIso8601String(),
        'calorieTargetOverride': calorieTargetOverride,
        'proteinTargetOverride': proteinTargetOverride,
        'satFatTargetOverride': satFatTargetOverride,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        sex: Sex.values.byName(json['sex'] as String),
        age: json['age'] as int,
        heightCm: (json['heightCm'] as num).toDouble(),
        weightKg: (json['weightKg'] as num).toDouble(),
        activity: ActivityLevel.values.byName(json['activity'] as String),
        goal: Goal.values.byName(json['goal'] as String),
        isConfigured: (json['isConfigured'] as bool?) ?? true,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        calorieTargetOverride:
            (json['calorieTargetOverride'] as num?)?.toDouble(),
        proteinTargetOverride:
            (json['proteinTargetOverride'] as num?)?.toDouble(),
        satFatTargetOverride: (json['satFatTargetOverride'] as num?)?.toDouble(),
      );
}
