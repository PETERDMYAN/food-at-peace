/// Measured "calories out" read from HealthKit / Health Connect for a day.
/// Phase 2 reads active energy (which includes Garmin data synced via Apple
/// Health); the resting portion of the budget comes from the profile BMR.
class EnergyOut {
  const EnergyOut({required this.activeEnergy, required this.asOf});

  /// Active energy burned so far, in kcal.
  final double activeEnergy;

  /// The end of the window the data covers (now, for today).
  final DateTime asOf;
}
