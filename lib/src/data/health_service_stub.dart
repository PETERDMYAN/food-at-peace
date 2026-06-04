import '../models/energy_out.dart';
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
}
