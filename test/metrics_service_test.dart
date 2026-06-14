import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/analytics_service.dart';
import 'package:food_at_peace/src/data/metrics_service.dart';

void main() {
  group('parseMetrics', () {
    test('maps backend JSON into AppMetrics', () {
      final m = parseMetrics({
        'downloads': 0,
        'activeToday': 1,
        'opensTotal': 5,
        'opens7d': [0, 0, 0, 0, 0, 0, 1],
        'photosScanned': 2,
        'beansSold': 220,
        'revenueSgd': 4.99,
        'refunds': 0,
        'refundSgd': 0.0,
        'isSample': false,
      });
      expect(m.opensTotal, 5);
      expect(m.opens7d, [0, 0, 0, 0, 0, 0, 1]);
      expect(m.beansSold, 220);
      expect(m.revenueSgd, 4.99);
      expect(m.isSample, isFalse);
    });
  });

  group('MetricsService', () {
    test('returns labelled sample data when no proxy is configured', () async {
      final m = await MetricsService().fetch();
      expect(m.isSample, isTrue);
    });

    test('reads <base>/metrics with the app token and parses a 200', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'downloads': 0,
            'activeToday': 1,
            'opensTotal': 7,
            'opens7d': [0, 0, 0, 0, 0, 0, 7],
            'photosScanned': 3,
            'beansSold': 0,
            'revenueSgd': 0.0,
            'refunds': 0,
            'refundSgd': 0.0,
            'isSample': false,
          }),
          200,
        );
      });
      final svc = MetricsService(
        baseUrl: 'https://x.test/', // trailing slash on purpose
        appToken: 'tok',
        httpClient: mock,
      );
      final m = await svc.fetch();
      expect(m.opensTotal, 7);
      expect(m.isSample, isFalse);
      expect(captured.url.toString(), 'https://x.test/metrics');
      expect(captured.headers['x-app-token'], 'tok');
    });

    test('falls back to sample data on a non-200', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final svc = MetricsService(
        baseUrl: 'https://x.test',
        appToken: 't',
        httpClient: mock,
      );
      expect((await svc.fetch()).isSample, isTrue);
    });
  });

  group('AnalyticsService', () {
    test('POSTs the event type to <base>/event', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('{"ok":true}', 200);
      });
      await AnalyticsService(
        baseUrl: 'https://x.test',
        appToken: 'tok',
        httpClient: mock,
      ).emit('scan');
      expect(captured.url.toString(), 'https://x.test/event');
      expect(captured.method, 'POST');
      expect((jsonDecode(captured.body) as Map)['type'], 'scan');
      expect(captured.headers['x-app-token'], 'tok');
    });

    test('is a no-op when no proxy is configured', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('', 200);
      });
      await AnalyticsService(httpClient: mock).emit('open');
      expect(called, isFalse);
    });

    test('never throws when the network fails', () async {
      final mock = MockClient((req) async => throw Exception('down'));
      await AnalyticsService(
        baseUrl: 'https://x.test',
        appToken: 't',
        httpClient: mock,
      ).emit('scan'); // completes without throwing
    });
  });
}
