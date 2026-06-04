import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../models/energy_out.dart';
import 'health_service.dart';

HealthService makeHealthService() => HealthKitService();

/// Reads active energy from HealthKit (iOS) / Health Connect (Android).
class HealthKitService implements HealthService {
  final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static const List<HealthDataAccess> _access = [HealthDataAccess.READ];

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
    final granted =
        await _health.hasPermissions(_types, permissions: _access);
    return granted ?? false;
  }

  @override
  Future<EnergyOut?> readEnergyOut(DateTime day) async {
    if (!isSupported) return null;
    await _health.configure();

    final start = DateTime(day.year, day.month, day.day);
    final now = DateTime.now();
    final isToday =
        start.year == now.year && start.month == now.month && start.day == now.day;
    final end = isToday ? now : start.add(const Duration(days: 1));

    final List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return null;
    }

    // Remove overlapping duplicates (e.g. Garmin + Apple Watch both writing).
    final deduped = _health.removeDuplicates(points);

    var active = 0.0;
    var hasData = false;
    for (final p in deduped) {
      final value = p.value;
      if (value is NumericHealthValue) {
        active += value.numericValue.toDouble();
        hasData = true;
      }
    }
    if (!hasData) return null;
    return EnergyOut(activeEnergy: active, asOf: end);
  }
}
