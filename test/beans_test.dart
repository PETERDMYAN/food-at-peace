import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/bean_transaction.dart';
import 'package:food_at_peace/src/providers/providers.dart';

BeanTransaction _txn(BeanTxnType type, int amount) => BeanTransaction(
  id: '${type.name}1',
  type: type,
  amount: amount,
  timestamp: DateTime(2026, 6, 13, 9),
);

void main() {
  test('pricing constants match the spec', () {
    expect(BeanPricing.signupGrant, 100);
    expect(BeanPricing.packBeans, 100);
    expect(BeanPricing.packPriceSgd, 1.99);
    expect(BeanPricing.costPerPhoto, 1);
  });

  test('beans_25 is the entry pack at S\$0.49 (a real IAP, not the hidden freebie)', () {
    final p25 = BeanPricing.packs.where((p) => p.beans == 25).toList();
    expect(p25.length, 1);
    expect(p25.single.sgd, 0.49);
    expect(BeanPricing.isHidden(25), isFalse); // sold via StoreKit, not local credit
    expect(BeanPricing.sgdForBeans(25), 0.49);
  });

  test('balance is the signed sum of the ledger', () {
    final state = BeansState(
      ledger: [
        _txn(BeanTxnType.spend, -1),
        _txn(BeanTxnType.purchase, 100),
        _txn(BeanTxnType.signupGrant, 21),
      ],
    );
    expect(state.balance, 120);
  });

  group('canAnalyze', () {
    test('true when Beans remain', () {
      final s = BeansState(ledger: [_txn(BeanTxnType.signupGrant, 21)]);
      expect(s.canAnalyze, isTrue);
    });

    test('false at zero balance', () {
      final s = BeansState(
        ledger: [
          _txn(BeanTxnType.signupGrant, 21),
          _txn(BeanTxnType.spend, -21),
        ],
      );
      expect(s.balance, 0);
      expect(s.canAnalyze, isFalse);
    });
  });

  test('transaction JSON round-trips', () {
    final t = BeanTransaction(
      id: 'buy_1',
      type: BeanTxnType.purchase,
      amount: 100,
      timestamp: DateTime(2026, 6, 13, 9, 30),
      priceSgd: 1.99,
      note: 'pack',
    );
    final back = BeanTransaction.fromJson(t.toJson());
    expect(back.id, t.id);
    expect(back.type, BeanTxnType.purchase);
    expect(back.amount, 100);
    expect(back.priceSgd, 1.99);
    expect(back.note, 'pack');
    expect(back.timestamp, t.timestamp);
  });

  group('mergeBeansLedgers', () {
    BeanTransaction g(String id, BeanTxnType type, int amount, DateTime ts) =>
        BeanTransaction(id: id, type: type, amount: amount, timestamp: ts);

    test('unions by id — the same txn on both sides is not double-counted', () {
      final purchase =
          g('buy_1', BeanTxnType.purchase, 200, DateTime(2026, 6, 16, 10));
      final local = [
        g('grant_1', BeanTxnType.signupGrant, 100, DateTime(2026, 6, 16, 9)),
        purchase,
      ];
      final merged = mergeBeansLedgers([purchase], local); // server already has it
      expect(merged.length, 2);
      expect(merged.fold<int>(0, (s, x) => s + x.amount), 300);
    });

    test('brings in server-only transactions (cross-device)', () {
      final local = [
        g('grant_1', BeanTxnType.signupGrant, 100, DateTime(2026, 6, 16, 9)),
      ];
      final server = [
        g('buy_seed80', BeanTxnType.purchase, 80, DateTime(2026, 6, 16, 5)),
      ];
      final merged = mergeBeansLedgers(server, local);
      expect(merged.map((x) => x.id), containsAll(['grant_1', 'buy_seed80']));
      expect(merged.fold<int>(0, (s, x) => s + x.amount), 180);
    });

    test('collapses multiple signup grants to the earliest (one per account)', () {
      final early =
          g('grant_A', BeanTxnType.signupGrant, 100, DateTime(2026, 6, 1));
      final later =
          g('grant_B', BeanTxnType.signupGrant, 100, DateTime(2026, 6, 16));
      final merged = mergeBeansLedgers([early], [later]);
      final grants =
          merged.where((x) => x.type == BeanTxnType.signupGrant).toList();
      expect(grants.length, 1);
      expect(grants.single.id, 'grant_A'); // earliest kept
      expect(merged.fold<int>(0, (s, x) => s + x.amount), 100); // not 200
    });

    test('returns newest first', () {
      final older = g('a', BeanTxnType.purchase, 100, DateTime(2026, 6, 10));
      final newer = g('b', BeanTxnType.purchase, 100, DateTime(2026, 6, 16));
      final merged = mergeBeansLedgers([older], [newer]);
      expect(merged.first.id, 'b');
      expect(merged.last.id, 'a');
    });
  });
}
