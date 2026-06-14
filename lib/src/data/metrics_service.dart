import 'dart:convert';

import 'package:http/http.dart' as http;

/// Aggregate, cross-user product metrics for the owner dashboard.
class AppMetrics {
  const AppMetrics({
    required this.downloads,
    required this.activeToday,
    required this.opensTotal,
    required this.opens7d,
    required this.photosScanned,
    required this.beansSold,
    required this.revenueSgd,
    required this.refunds,
    required this.refundSgd,
    required this.isSample,
  });

  final int downloads; // lifetime installs (App Store Connect)
  final int activeToday; // DAU
  final int opensTotal; // lifetime app opens
  final List<int> opens7d; // opens per day, last 7 days (oldest → newest)
  final int photosScanned; // Beans spent on photo analysis
  final int beansSold; // Beans purchased across all packs
  final double revenueSgd; // gross purchase revenue
  final int refunds; // refunded transactions
  final double refundSgd; // refunded amount

  /// True when these are placeholder numbers (no analytics backend reached).
  final bool isSample;
}

/// Clearly-labelled placeholder numbers, shown when no analytics backend is
/// configured (or a fetch fails) so the dashboard UI stays reviewable.
const AppMetrics sampleMetrics = AppMetrics(
  downloads: 1284,
  activeToday: 73,
  opensTotal: 5210,
  opens7d: [62, 71, 58, 80, 67, 90, 73],
  photosScanned: 1840,
  beansSold: 12400,
  revenueSgd: 246.80,
  refunds: 6,
  refundSgd: 11.94,
  isSample: true,
);

/// Parses the `/metrics` JSON into [AppMetrics]. Pure — unit-tested.
AppMetrics parseMetrics(Map<String, dynamic> j) {
  int asInt(Object? v) => (v as num?)?.toInt() ?? 0;
  double asDouble(Object? v) => (v as num?)?.toDouble() ?? 0;
  return AppMetrics(
    downloads: asInt(j['downloads']),
    activeToday: asInt(j['activeToday']),
    opensTotal: asInt(j['opensTotal']),
    opens7d: ((j['opens7d'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
    photosScanned: asInt(j['photosScanned']),
    beansSold: asInt(j['beansSold']),
    revenueSgd: asDouble(j['revenueSgd']),
    refunds: asInt(j['refunds']),
    refundSgd: asDouble(j['refundSgd']),
    isSample: j['isSample'] == true,
  );
}

/// Fetches the owner metrics from the analytics backend (`GET <base>/metrics`).
///
/// When no proxy is configured — or the request fails — it returns the
/// clearly-labelled [sampleMetrics] so the dashboard stays reviewable. `opens`
/// and `photosScanned` are live; `downloads` still needs the App Store Connect
/// API and `revenue` only moves once real IAP is wired (both report 0 for now).
class MetricsService {
  MetricsService({
    this.baseUrl = '',
    this.appToken = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String appToken;
  final http.Client _http;

  Future<AppMetrics> fetch() async {
    if (baseUrl.isEmpty) return sampleMetrics;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    try {
      final resp = await _http.get(
        Uri.parse('$base/metrics'),
        headers: {'x-app-token': appToken},
      );
      if (resp.statusCode != 200) return sampleMetrics;
      return parseMetrics(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (_) {
      return sampleMetrics;
    }
  }
}
