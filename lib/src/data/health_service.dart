import '../models/energy_out.dart';
// Picks the real HealthKit/Health Connect implementation on mobile, and a
// no-op stub on web — so `package:health` (which is mobile-only) never reaches
// the web compile.
import 'health_service_stub.dart'
    if (dart.library.io) 'health_service_io.dart';

/// Reads "calories out" from the platform health store.
abstract interface class HealthService {
  /// Whether a health store is available on this platform (false on web).
  bool get isSupported;

  /// Prompts for read access to energy data. Returns whether it was granted.
  Future<bool> requestPermissions();

  /// Whether read access has already been granted.
  Future<bool> hasPermissions();

  /// Active energy burned for [day] (up to now if today), or null if
  /// unavailable / not permitted / no data.
  Future<EnergyOut?> readEnergyOut(DateTime day);
}

/// Platform-appropriate instance (real on mobile, stub on web).
HealthService createHealthService() => makeHealthService();
