import 'dart:io' show Platform;

// `health` also exports a `WorkoutSummary`; hide it so ours (imported below) wins.
import 'package:health/health.dart' hide WorkoutSummary;

import '../models/energy_out.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import 'health_service.dart';

HealthService makeHealthService() => HealthKitService();

/// Reads energy/weight/workouts from HealthKit (iOS) / Health Connect (Android)
/// and writes logged food + weight back. Garmin data arrives via Apple Health.
class HealthKitService implements HealthService {
  final Health _health = Health();

  // (type, access) pairs. BIRTH_DATE + GENDER are HealthKit-only characteristics
  // with no Health Connect counterpart, so they're dropped on Android — the
  // platform falls back to the manual profile values there.
  static const List<(HealthDataType, HealthDataAccess)> _all = [
    (HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataAccess.READ),
    (HealthDataType.BASAL_ENERGY_BURNED, HealthDataAccess.READ),
    (HealthDataType.WEIGHT, HealthDataAccess.READ_WRITE), // read latest + log
    (HealthDataType.HEIGHT, HealthDataAccess.READ_WRITE), // read latest + edits
    (HealthDataType.BIRTH_DATE, HealthDataAccess.READ), // iOS only (→ age)
    (HealthDataType.GENDER, HealthDataAccess.READ), // iOS only
    (HealthDataType.WORKOUT, HealthDataAccess.READ),
    (HealthDataType.DIETARY_ENERGY_CONSUMED, HealthDataAccess.WRITE),
    (HealthDataType.DIETARY_PROTEIN_CONSUMED, HealthDataAccess.WRITE),
    (HealthDataType.DIETARY_FAT_SATURATED, HealthDataAccess.WRITE),
  ];

  static const Set<HealthDataType> _iosOnly = {
    HealthDataType.BIRTH_DATE,
    HealthDataType.GENDER,
  };

  // Index-aligned type/access lists, platform-filtered for requestAuthorization.
  List<(HealthDataType, HealthDataAccess)> get _pairs => Platform.isAndroid
      ? [
          for (final p in _all)
            if (!_iosOnly.contains(p.$1)) p,
        ]
      : _all;

  List<HealthDataType> get _types => [for (final p in _pairs) p.$1];
  List<HealthDataAccess> get _access => [for (final p in _pairs) p.$2];

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
  Future<EnergyOut?> readEnergyOut(DateTime day, {String? preferredSource}) async {
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

    // Active energy keeps its source so a preferred device can win; resting
    // (basal) is combined across sources.
    final activePts = <ActiveEnergyPoint>[];
    var resting = 0.0;
    var hasActive = false, hasResting = false;
    for (final p in deduped) {
      final value = p.value;
      if (value is! NumericHealthValue) continue;
      final kcal = value.numericValue.toDouble();
      if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
        activePts.add((source: p.sourceName, kcal: kcal));
        hasActive = true;
      } else if (p.type == HealthDataType.BASAL_ENERGY_BURNED) {
        resting += kcal;
        hasResting = true;
      }
    }
    if (!hasActive && !hasResting) return null;
    return EnergyOut(
      activeEnergy: sumActiveEnergy(activePts, preferredSource),
      restingEnergy: hasResting ? resting : null,
      asOf: w.end,
    );
  }

  @override
  Future<List<String>> energySources() async {
    if (!isSupported) return const [];
    await _health.configure();
    final now = DateTime.now();
    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: now.subtract(const Duration(days: 14)),
        endTime: now,
      );
    } catch (_) {
      return const [];
    }
    // Distinct source names, most-recently-seen first.
    final seen = <String>{};
    final ordered = <String>[];
    for (final p in points.reversed) {
      if (p.sourceName.isNotEmpty && seen.add(p.sourceName)) {
        ordered.add(p.sourceName);
      }
    }
    return ordered;
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
  Future<int?> readAge() async {
    if (!isSupported) return null;
    if (Platform.isAndroid) return null; // Health Connect has no birth date
    await _health.configure();
    final now = DateTime.now();
    final List<HealthDataPoint> points;
    try {
      // BIRTH_DATE is a HealthKit characteristic; the date range is ignored
      // natively, but the API requires one.
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.BIRTH_DATE],
        startTime: DateTime(1900),
        endTime: now,
      );
    } catch (_) {
      return null;
    }
    for (final p in points) {
      final value = p.value;
      if (value is! NumericHealthValue) continue;
      // Native returns the DOB as seconds since the Unix epoch.
      final dob = DateTime.fromMillisecondsSinceEpoch(
        (value.numericValue.toDouble() * 1000).round(),
      );
      var age = now.year - dob.year;
      final hadBirthday =
          now.month > dob.month ||
          (now.month == dob.month && now.day >= dob.day);
      if (!hadBirthday) age--;
      if (age > 0 && age < 120) return age;
    }
    return null;
  }

  @override
  Future<Sex?> readSex() async {
    if (!isSupported) return null;
    if (Platform.isAndroid) return null; // Health Connect has no biological sex
    await _health.configure();
    final List<HealthDataPoint> points;
    try {
      // GENDER is a HealthKit characteristic; the date range is ignored
      // natively, but the API requires one.
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.GENDER],
        startTime: DateTime(1900),
        endTime: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
    for (final p in points) {
      final value = p.value;
      if (value is! NumericHealthValue) continue;
      // HKBiologicalSex raw values: 0 notSet, 1 female, 2 male, 3 other.
      final raw = value.numericValue.toInt();
      if (raw == 1) return Sex.female;
      if (raw == 2) return Sex.male;
    }
    return null;
  }

  @override
  Future<double?> readHeightCm() async {
    if (!isSupported) return null;
    await _health.configure();
    final now = DateTime.now();
    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEIGHT],
        startTime: now.subtract(const Duration(days: 3650)),
        endTime: now,
      );
    } catch (_) {
      return null;
    }
    if (points.isEmpty) return null;
    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    for (final p in points) {
      final value = p.value;
      if (value is! NumericHealthValue) continue;
      // HEIGHT comes back in metres.
      final meters = value.numericValue.toDouble();
      if (meters > 0) return meters * 100;
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

  @override
  Future<bool> writeHeight(double cm) async {
    if (!isSupported) return false;
    await _health.configure();
    final now = DateTime.now();
    try {
      return await _health.writeHealthData(
        value: cm / 100, // HEIGHT is stored in metres
        type: HealthDataType.HEIGHT,
        startTime: now,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (_) {
      return false;
    }
  }
}
