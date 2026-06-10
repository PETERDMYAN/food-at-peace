import '../models/energy_out.dart';
import '../models/food_entry.dart';
import '../models/workout_summary.dart';
import 'health_service.dart';

/// Web (and any non-io platform) fallback: no health store available.
HealthService makeHealthService() => const _UnsupportedHealthService();

class _UnsupportedHealthService implements HealthService {
  const _UnsupportedHealthService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<bool> hasPermissions() async => false;

  @override
  Future<EnergyOut?> readEnergyOut(DateTime day) async => null;

  @override
  Future<double?> readLatestWeightKg() async => null;

  @override
  Future<int?> readAge() async => null;

  @override
  Future<double?> readHeightCm() async => null;

  @override
  Future<List<WorkoutSummary>> readWorkouts(DateTime day) async => const [];

  @override
  Future<bool> writeFood(FoodEntry entry) async => false;

  @override
  Future<bool> writeWeight(double kg, DateTime when) async => false;
}
