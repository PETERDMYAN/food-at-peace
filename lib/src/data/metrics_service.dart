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
    required this.subscribers,
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
  final int subscribers; // active unlimited subscribers

  /// True when these are placeholder numbers (no analytics backend wired yet).
  final bool isSample;
}

/// Fetches the owner metrics.
///
/// TODO: real numbers require (1) the app to emit `open` / `scan` / `purchase`
/// / `refund` analytics events to the backend, (2) a backend aggregation
/// endpoint the dashboard reads, and (3) the App Store Connect API for
/// downloads. Until then this returns clearly-labelled SAMPLE data so the
/// dashboard UI is reviewable.
class MetricsService {
  Future<AppMetrics> fetch() async {
    // Simulated latency so the UI's loading state is exercised.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return const AppMetrics(
      downloads: 1284,
      activeToday: 73,
      opensTotal: 5210,
      opens7d: [62, 71, 58, 80, 67, 90, 73],
      photosScanned: 1840,
      beansSold: 12400,
      revenueSgd: 246.80,
      refunds: 6,
      refundSgd: 11.94,
      subscribers: 18,
      isSample: true,
    );
  }
}
