import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fire-and-forget, non-PII product analytics. Emits lightweight events
/// (`open` / `scan` / `purchase` / `refund`) to `<base>/event`, which feeds the
/// owner dashboard's aggregate counters.
///
/// It never throws and never blocks anything the user is waiting on — a dropped
/// analytics ping must not affect the experience. A no-op when no proxy URL is
/// baked in (e.g. tests, or a build with no backend).
class AnalyticsService {
  AnalyticsService({
    this.baseUrl = '',
    this.appToken = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String appToken;
  final http.Client _http;

  Future<void> emit(String type, {Map<String, dynamic>? fields}) async {
    if (baseUrl.isEmpty) return;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    try {
      await _http.post(
        Uri.parse('$base/event'),
        headers: {'content-type': 'application/json', 'x-app-token': appToken},
        body: jsonEncode({'type': type, ...?fields}),
      );
    } catch (_) {
      // Swallow — analytics must never surface an error to the user.
    }
  }
}
