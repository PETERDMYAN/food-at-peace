import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Bean-pack consumable product IDs. These MUST match the **consumable** IAP
/// products created in App Store Connect *and* `BeanPricing.packs` in the app
/// (key = Beans granted, value = product ID).
const Map<int, String> kBeanProductIds = {
  25: 'beans_25',
  100: 'beans_100',
  200: 'beans_200',
  300: 'beans_300',
  500: 'beans_500',
  800: 'beans_800',
};

/// Product ID for a Bean amount, or null if it isn't a sellable pack.
String? beanProductId(int beans) => kBeanProductIds[beans];

/// Beans granted by a product ID, or null if it isn't a Bean pack.
int? beansForProduct(String productId) {
  for (final e in kBeanProductIds.entries) {
    if (e.value == productId) return e.key;
  }
  return null;
}

/// How a [IapService.buy] attempt resolved.
enum IapOutcome { purchased, canceled, pending, error, unavailable }

class IapResult {
  const IapResult(this.outcome, {this.beans, this.message});
  final IapOutcome outcome;
  final int? beans;
  final String? message;
}

/// Abstraction over the StoreKit IAP flow so the paywall depends on an interface
/// and tests can inject a fake (the real store can't run on the simulator).
/// Implemented by [StoreKitIapService].
abstract interface class IapService {
  Future<bool> isAvailable();
  Future<List<ProductDetails>> products();
  Future<IapResult> buy(String productId);
  void dispose();
}

/// `in_app_purchase`-backed [IapService] for the consumable Bean packs.
///
/// A single [InAppPurchase.purchaseStream] listener routes each store update to
/// the pending [buy] call for that product. On a `purchased`/`restored`
/// consumable it fires [onCredited] (so the wallet credits the Beans) and
/// finishes the transaction.
///
/// NOTE (Phase 2): this credits on the *client's* report of a successful
/// StoreKit purchase. Server-side receipt validation (`/iap/validate`) — to
/// harden against fraud and enable a cross-device ledger + referral Beans — is a
/// planned follow-up (`TODO.md` §2/§7); [buy] is shaped so that hook slots in
/// before [onCredited] without touching callers.
class StoreKitIapService implements IapService {
  StoreKitIapService({this.onCredited}) {
    _sub = _iap.purchaseStream.listen(_onUpdates, onError: (_) {});
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  final void Function(int beans, String productId, String receipt)? onCredited;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<IapResult>> _pending = {};
  List<ProductDetails> _cache = const [];

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<ProductDetails>> products() async {
    if (!await _iap.isAvailable()) return const [];
    final resp = await _iap.queryProductDetails(kBeanProductIds.values.toSet());
    _cache = resp.productDetails;
    return resp.productDetails;
  }

  @override
  Future<IapResult> buy(String productId) async {
    // Reuse the product details fetched by products() (the paywall preloads them
    // via beanProductsProvider) so a tap goes straight to the purchase sheet —
    // re-querying StoreKit on every tap made the paywall feel slow.
    ProductDetails? product;
    for (final p in _cache) {
      if (p.id == productId) {
        product = p;
        break;
      }
    }
    if (product == null) {
      if (!await _iap.isAvailable()) {
        return const IapResult(IapOutcome.unavailable);
      }
      final resp = await _iap.queryProductDetails({productId});
      if (resp.productDetails.isEmpty) {
        return const IapResult(IapOutcome.error, message: 'Product not found');
      }
      product = resp.productDetails.first;
    }
    final completer = _pending.putIfAbsent(productId, Completer<IapResult>.new);
    await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    return completer.future;
  }

  void _onUpdates(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break; // wait for a terminal status before resolving buy()
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final beans = beansForProduct(p.productID);
          if (beans != null) {
            // The receipt lets the wallet validate the purchase server-side
            // before crediting (fraud-hardening); empty when unavailable.
            onCredited?.call(
              beans,
              p.productID,
              p.verificationData.serverVerificationData,
            );
          }
          _resolve(p.productID, IapResult(IapOutcome.purchased, beans: beans));
          if (p.pendingCompletePurchase) _iap.completePurchase(p);
        case PurchaseStatus.error:
          _resolve(
            p.productID,
            IapResult(IapOutcome.error, message: p.error?.message),
          );
          if (p.pendingCompletePurchase) _iap.completePurchase(p);
        case PurchaseStatus.canceled:
          _resolve(p.productID, const IapResult(IapOutcome.canceled));
          if (p.pendingCompletePurchase) _iap.completePurchase(p);
      }
    }
  }

  void _resolve(String productId, IapResult result) {
    final completer = _pending.remove(productId);
    if (completer != null && !completer.isCompleted) completer.complete(result);
  }

  @override
  void dispose() {
    _sub?.cancel();
  }
}
