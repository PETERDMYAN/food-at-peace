import '../models/energy_out.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
// Picks the real HealthKit/Health Connect implementation on mobile, and a
// no-op stub on web — so `package:health` (which is mobile-only) never reaches
// the web compile.
import 'health_service_stub.dart' if (dart.library.io) 'health_service_io.dart';

/// Reads "calories out", weight and workouts from the platform health store,
/// and writes logged food back to it. On iOS this is Apple Health (HealthKit),
/// which also carries Garmin data synced via Garmin Connect.
abstract interface class HealthService {
  /// Whether a health store is available on this platform (false on web).
  bool get isSupported;

  /// Prompts for read access to energy/weight/workouts and write access for
  /// logged food. Returns whether it was granted.
  Future<bool> requestPermissions();

  /// Whether access has already been granted. Always false on web; may be
  /// indeterminate on iOS, where read authorization status can't be queried.
  Future<bool> hasPermissions();

  /// Active + resting energy burned for [day] (up to now if today), or null if
  /// unavailable / not permitted / no data. When [preferredSource] is set and it
  /// has active-energy data that day, only that source's active energy is counted
  /// (so a chosen device — e.g. Garmin — wins over others writing to Health);
  /// otherwise all sources are combined.
  Future<EnergyOut?> readEnergyOut(DateTime day, {String? preferredSource});

  /// Distinct source names (e.g. "Garmin Connect", "Apple Watch", "iPhone") that
  /// have written **active energy** to the health store recently — the selectable
  /// data sources. Empty when unavailable / not permitted / none found.
  Future<List<String>> energySources();

  /// The most recent body weight in kg (e.g. from a Garmin/Fitdays scale synced
  /// via Apple Health), or null if unavailable.
  Future<double?> readLatestWeightKg();

  /// The user's age in whole years, derived from Apple Health's date-of-birth
  /// characteristic. Null if unavailable / not permitted / not set.
  Future<int?> readAge();

  /// The most recent height in centimetres, or null if unavailable.
  Future<double?> readHeightCm();

  /// Biological sex from Apple Health's characteristic (read-only there), or
  /// null if unavailable / not set / not male-or-female.
  Future<Sex?> readSex();

  /// Workouts recorded on [day] (e.g. Garmin activities), longest first.
  Future<List<WorkoutSummary>> readWorkouts(DateTime day);

  /// Writes a logged food entry's calories, protein and saturated fat to the
  /// health store. Returns whether it succeeded.
  Future<bool> writeFood(FoodEntry entry);

  /// Writes a body-weight reading (kg) at [when]. Returns whether it succeeded.
  Future<bool> writeWeight(double kg, DateTime when);

  /// Writes a height reading (cm). Returns whether it succeeded. (Apple Health
  /// stores date of birth as a read-only characteristic, so age can't be
  /// written back.)
  Future<bool> writeHeight(double cm);
}

/// Platform-appropriate instance (real on mobile, stub on web).
HealthService createHealthService() => makeHealthService();

/// One active-energy sample reduced to its source + kcal.
typedef ActiveEnergyPoint = ({String source, double kcal});

/// Sum active energy, honoring [preferred] when that source has data: if the
/// preferred source contributed any points, only its points count (avoids
/// double-counting a second device); otherwise everything is summed. Pure +
/// unit-tested so the source-priority rule is verifiable without HealthKit.
double sumActiveEnergy(List<ActiveEnergyPoint> points, String? preferred) {
  if (preferred != null && preferred.isNotEmpty) {
    final pref = points.where((p) => p.source == preferred).toList();
    if (pref.isNotEmpty) {
      return pref.fold(0.0, (s, p) => s + p.kcal);
    }
  }
  return points.fold(0.0, (s, p) => s + p.kcal);
}
