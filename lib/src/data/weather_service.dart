import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// Resolves the device location and fetches current conditions from Open-Meteo
/// (free, no API key). Returns null on any failure — denied permission,
/// disabled location services, no network — so callers degrade gracefully.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Asks for "while in use" location (if not already decided), gets a coarse
  /// position, then fetches the weather there.
  Future<Weather?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      // Last known is instant; fall back to a fresh low-accuracy fix.
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return fetch(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Pure HTTP fetch for a coordinate — unit-testable with a mock client.
  Future<Weather?> fetch(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,weather_code,is_day',
    );
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final current = body['current'] as Map<String, dynamic>?;
      if (current == null) return null;
      final temp = (current['temperature_2m'] as num?)?.toDouble();
      final code = (current['weather_code'] as num?)?.toInt();
      if (temp == null || code == null) return null;
      final isDay = ((current['is_day'] as num?)?.toInt() ?? 1) == 1;
      return Weather(tempC: temp, code: code, isDay: isDay);
    } catch (_) {
      return null;
    }
  }
}
