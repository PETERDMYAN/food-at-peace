import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/weather_service.dart';
import 'package:food_at_peace/src/models/weather.dart';

void main() {
  group('WeatherService.fetch', () {
    test('parses a 200 Open-Meteo current response', () async {
      late Uri captured;
      final mock = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({
            'current': {
              'temperature_2m': 18.4,
              'weather_code': 61, // rain
              'is_day': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final weather = await WeatherService(client: mock).fetch(1.35, 103.8);

      expect(weather, isNotNull);
      expect(weather!.tempC, 18.4);
      expect(weather.code, 61);
      expect(weather.isDay, isFalse);
      expect(weather.condition, WeatherCondition.rain);
      // Coordinates + current fields are in the query.
      expect(captured.queryParameters['latitude'], '1.35');
      expect(captured.queryParameters['current'], contains('weather_code'));
    });

    test('returns null on a non-200', () async {
      final mock = MockClient((req) async => http.Response('nope', 500));
      expect(await WeatherService(client: mock).fetch(0, 0), isNull);
    });

    test('returns null when fields are missing', () async {
      final mock = MockClient(
        (req) async => http.Response(jsonEncode({'current': {}}), 200),
      );
      expect(await WeatherService(client: mock).fetch(0, 0), isNull);
    });
  });

  group('WeatherService.ipCoords (fallback)', () {
    test('parses lat/lon from the IP geolocation response', () async {
      final mock = MockClient((req) async {
        expect(req.url.host, 'ipapi.co');
        return http.Response(
          jsonEncode({
            'latitude': 1.29,
            'longitude': 103.85,
            'city': 'Singapore',
          }),
          200,
        );
      });
      final coords = await WeatherService(client: mock).ipCoords();
      expect(coords, isNotNull);
      expect(coords!.$1, 1.29);
      expect(coords.$2, 103.85);
    });

    test('returns null on a rate-limit/error response', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode({'error': true, 'reason': 'RateLimited'}),
          200,
        ),
      );
      expect(await WeatherService(client: mock).ipCoords(), isNull);
    });
  });

  group('weatherConditionFromCode', () {
    test('maps representative WMO codes', () {
      expect(weatherConditionFromCode(0), WeatherCondition.clear);
      expect(weatherConditionFromCode(2), WeatherCondition.partlyCloudy);
      expect(weatherConditionFromCode(3), WeatherCondition.cloudy);
      expect(weatherConditionFromCode(48), WeatherCondition.fog);
      expect(weatherConditionFromCode(53), WeatherCondition.drizzle);
      expect(weatherConditionFromCode(65), WeatherCondition.rain);
      expect(weatherConditionFromCode(81), WeatherCondition.rain);
      expect(weatherConditionFromCode(75), WeatherCondition.snow);
      expect(weatherConditionFromCode(95), WeatherCondition.thunder);
    });
  });
}
