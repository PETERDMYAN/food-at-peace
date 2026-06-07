/// A single workout/exercise session read from Apple Health — e.g. an activity
/// recorded by a Garmin device and synced in via Garmin Connect.
class WorkoutSummary {
  const WorkoutSummary({
    required this.activityType,
    required this.duration,
    this.energyBurned,
    this.source,
  });

  /// Raw HealthKit activity-type name, e.g. "RUNNING" or
  /// "TRADITIONAL_STRENGTH_TRAINING".
  final String activityType;

  /// How long the workout lasted.
  final Duration duration;

  /// Energy burned during the workout in kcal, when the device reported it.
  final double? energyBurned;

  /// The app/device that recorded it, e.g. "Garmin Connect".
  final String? source;

  /// Human-friendly activity label, e.g. "Traditional Strength Training".
  String get label => activityType
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
