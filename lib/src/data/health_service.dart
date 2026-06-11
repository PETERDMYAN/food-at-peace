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
  /// unavailable / not permitted / no data.
  Future<EnergyOut?> readEnergyOut(DateTime day);

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
