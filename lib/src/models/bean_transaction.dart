/// What a Beans ledger entry represents. Beans are the in-app credit: one photo
/// analysis spends one Bean. Pure Dart (no Flutter) so it stays testable.
enum BeanTxnType {
  /// The 100 free Beans granted once on first launch.
  signupGrant,

  /// Spent one Bean analyzing a food photo.
  spend,

  /// Bought a Beans pack (e.g. 100 Beans for SGD 1.99).
  purchase,

  /// A purchase was refunded (Beans removed, money returned).
  refund,
}

/// One immutable entry in the Beans ledger. [amount] is signed: positive adds
/// Beans (grant / purchase), negative removes them (spend / refund).
class BeanTransaction {
  const BeanTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    this.note,
    this.priceSgd,
  });

  final String id;
  final BeanTxnType type;
  final int amount; // signed Beans delta
  final DateTime timestamp;

  /// Optional human note (e.g. the dish name for a spend).
  final String? note;

  /// Money moved, in SGD, for purchase/refund rows (null for grants/spends).
  final double? priceSgd;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'ts': timestamp.toIso8601String(),
    if (note != null) 'note': note,
    if (priceSgd != null) 'price': priceSgd,
  };

  factory BeanTransaction.fromJson(Map<String, dynamic> j) => BeanTransaction(
    id: j['id'] as String,
    type: BeanTxnType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => BeanTxnType.spend,
    ),
    amount: (j['amount'] as num).toInt(),
    timestamp:
        DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime(2026),
    note: j['note'] as String?,
    priceSgd: (j['price'] as num?)?.toDouble(),
  );
}

/// Pricing + free-grant constants for the Beans economy.
class BeanPricing {
  BeanPricing._();

  /// Free Beans granted once on first launch.
  static const int signupGrant = 100;

  /// Base pack (the smallest tier) — also the per-100 rate used to price a
  /// custom amount.
  static const int packBeans = 100;
  static const double packPriceSgd = 1.99;

  /// Top-up packs shown in the paywall (Beans → SGD). Each MUST map to a fixed
  /// Apple **consumable** IAP product (an App Store Connect price tier) — Apple
  /// IAP has no arbitrary pricing, so the "custom" amount has to resolve to one
  /// of these tiers (or the nearest) rather than a free-form price.
  static const List<({int beans, double sgd})> packs = [
    (beans: 100, sgd: 1.99),
    (beans: 200, sgd: 3.99),
    (beans: 300, sgd: 5.99),
    (beans: 500, sgd: 9.48),
    (beans: 800, sgd: 13.98),
  ];

  /// Indicative price (SGD) for an arbitrary Bean amount at the per-100 rate.
  static double priceFor(int beans) =>
      (beans / packBeans) * packPriceSgd;

  /// The fixed SGD price for a Bean pack tier, or null if [beans] isn't a tier.
  static double? sgdForBeans(int beans) {
    for (final p in packs) {
      if (p.beans == beans) return p.sgd;
    }
    return null;
  }

  /// Beans spent per food-photo analysis.
  static const int costPerPhoto = 1;
}

/// Merge two Beans ledgers into one, newest first. The ledger is append-only and
/// every entry is immutable, so the union is taken **by id** (an id seen in both
/// is the same transaction). The one exception is the welcome [signupGrant]: each
/// device grants its own local 100 on first launch, so a union could hold several
/// — they are collapsed to a **single grant** (the earliest), since the bonus is
/// once per account. Pure (no Flutter / IO) so it is unit-tested directly.
List<BeanTransaction> mergeBeansLedgers(
  Iterable<BeanTransaction> a,
  Iterable<BeanTransaction> b,
) {
  final byId = <String, BeanTransaction>{};
  for (final t in a) {
    byId[t.id] = t;
  }
  for (final t in b) {
    byId.putIfAbsent(t.id, () => t);
  }
  var list = byId.values.toList();
  final grants = list.where((t) => t.type == BeanTxnType.signupGrant).toList()
    ..sort((x, y) {
      final c = x.timestamp.compareTo(y.timestamp);
      return c != 0 ? c : x.id.compareTo(y.id);
    });
  if (grants.length > 1) {
    final keepId = grants.first.id;
    list = list
        .where((t) => t.type != BeanTxnType.signupGrant || t.id == keepId)
        .toList();
  }
  list.sort((x, y) => y.timestamp.compareTo(x.timestamp)); // newest first
  return list;
}
