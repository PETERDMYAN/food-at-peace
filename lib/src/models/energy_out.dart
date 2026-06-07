/// Measured "calories out" read from HealthKit / Health Connect for a day.
/// Reads active energy and, when a wearable records it, resting (basal) energy
/// too — both include Garmin data synced via Apple Health. When the resting
/// portion is missing, callers fall back to the profile's estimated BMR.
class EnergyOut {
  const EnergyOut({
    required this.activeEnergy,
    this.restingEnergy,
    required this.asOf,
  });

  /// Active energy burned so far, in kcal.
  final double activeEnergy;

  /// Measured resting/basal energy burned so far, in kcal. Null when no device
  /// reported it (the caller should fall back to estimated BMR).
  final double? restingEnergy;

  /// The end of the window the data covers (now, for today).
  final DateTime asOf;
}
