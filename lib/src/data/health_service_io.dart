import 'dart:io' show Platform;

// `health` also exports a `WorkoutSummary`; hide it so ours (imported below) wins.
import 'package:health/health.dart' hide WorkoutSummary;

import '../models/energy_out.dart';
import '../models/food_entry.dart';
import '../models/workout_summary.dart';
import 'health_service.dart';

HealthService makeHealthService() => HealthKitService();

/// Reads energy/weight/workouts from HealthKit (iOS) / Health Connect (Android)
/// and writes logged food + weight back. Garmin data arrives via Apple Health.
class HealthKitService implements HealthService {
  final Health _health = Health();

  // Types and their access, kept index-aligned for requestAuthorization.
  static const List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
    HealthDataType.DIETARY_ENERGY_CONSUMED,
    HealthDataType.DIETARY_PROTEIN_CONSUMED,
    HealthDataType.DIETARY_FAT_SATURATED,
  ];

  static const List<HealthDataAccess> _access = [
    HealthDataAccess.READ, // active energy
    HealthDataAccess.READ, // basal energy
    HealthDataAccess.READ_WRITE, // weight (read latest + log new)
    HealthDataAccess.READ, // workouts
    HealthDataAccess.WRITE, // dietary energy
    HealthDataAccess.WRITE, // dietary protein
    HealthDataAccess.WRITE, // dietary saturated fat
  ];

  @override
  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  @override
  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await _health.configure();
    return _health.requestAuthorization(_types, permissions: _access);
  }

  @override
  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    final granted = await _health.hasPermissions(_types, permissions: _access);
    return granted ?? false;
  }

  /// Day window: from midnight to now (today) or to next midnight (past days).
  ({DateTime start, DateTime end}) _window(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final now = DateTime.now();
    final isToday =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final end = isToday ? now : start.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  @override
  Future<EnergyOut?> readEnergyOut(DateTime day) async {
    if (!isSupported) return null;
    await _health.configure();
    final w = _window(day);

    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.BASAL_ENERGY_BURNED,
        ],
        startTime: w.start,
        endTime: w.end,
      );
    } catch (_) {
      return null;
    }

    // Remove overlapping duplicates (e.g. Garmin + Apple Watch both writing).
    final deduped = _health.removeDuplicates(points);

    var active = 0.0, resting = 0.0;
    var hasActive = false, hasResting = false;
    for (final p in deduped) {
      final value = p.value;
      if (value is! NumericHealthValue) continue;
      final kcal = value.numericValue.toDouble();
      if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
        active += kcal;
        hasActive = true;
      } else if (p.type == HealthDataType.BASAL_ENERGY_BURNED) {
        resting += kcal;
        hasResting = true;
      }
    }
    if (!hasActive && !hasResting) return null;
    return EnergyOut(
      activeEnergy: active,
      restingEnergy: hasResting ? resting : null,
      asOf: w.end,
    );
  }

  @override
  Future<double?> readLatestWeightKg() async {
    if (!isSupported) return null;
    await _health.configure();
    final now = DateTime.now();
    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WEIGHT],
        startTime: now.subtract(const Duration(days: 365)),
        endTime: now,
      );
    } catch (_) {
      return null;
    }
    if (points.isEmpty) return null;
    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    for (final p in points) {
      final value = p.value;
      if (value is NumericHealthValue) return value.numericValue.toDouble();
    }
    return null;
  }

  @override
  Future<List<WorkoutSummary>> readWorkouts(DateTime day) async {
    if (!isSupported) return const [];
    await _health.configure();
    final w = _window(day);
    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: w.start,
        endTime: w.end,
      );
    } catch (_) {
      return const [];
    }
    final workouts = <WorkoutSummary>[];
    for (final p in points) {
      final value = p.value;
      if (value is! WorkoutHealthValue) continue;
      workouts.add(
        WorkoutSummary(
          activityType: value.workoutActivityType.name,
          duration: p.dateTo.difference(p.dateFrom),
          energyBurned: value.totalEnergyBurned?.toDouble(),
          source: p.sourceName,
        ),
      );
    }
    workouts.sort((a, b) => b.duration.compareTo(a.duration));
    return workouts;
  }

  @override
  Future<bool> writeFood(FoodEntry entry) async {
    if (!isSupported) return false;
    await _health.configure();
    final t = entry.timestamp;
    try {
      final results = await Future.wait([
        _health.writeHealthData(
          value: entry.calories,
          type: HealthDataType.DIETARY_ENERGY_CONSUMED,
          startTime: t,
          endTime: t,
          recordingMethod: RecordingMethod.manual,
        ),
        _health.writeHealthData(
          value: entry.proteinG,
          type: HealthDataType.DIETARY_PROTEIN_CONSUMED,
          startTime: t,
          endTime: t,
          recordingMethod: RecordingMethod.manual,
        ),
        _health.writeHealthData(
          value: entry.satFatG,
          type: HealthDataType.DIETARY_FAT_SATURATED,
          startTime: t,
          endTime: t,
          recordingMethod: RecordingMethod.manual,
        ),
      ]);
      return results.every((ok) => ok);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> writeWeight(double kg, DateTime when) async {
    if (!isSupported) return false;
    await _health.configure();
    try {
      return await _health.writeHealthData(
        value: kg,
        type: HealthDataType.WEIGHT,
        startTime: when,
        endTime: when,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (_) {
      return false;
    }
  }
}
