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
    expect(BeanPricing.signupGrant, 21);
    expect(BeanPricing.packBeans, 100);
    expect(BeanPricing.packPriceSgd, 1.99);
    expect(BeanPricing.costPerPhoto, 1);
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
}
