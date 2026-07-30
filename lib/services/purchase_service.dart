import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must exactly match the in-app product ID created in Play Console.
const String kPremiumProductId = 'apppostit_unlimited';
const String kIsPremiumKey = 'is_premium';

/// Wraps [InAppPurchase] for the single "unlock unlimited posts" product.
/// Every call is defensive: in-app purchases can be unavailable (no Play
/// Store on the device, the product not set up yet, running in a test
/// environment, etc.), and none of that should ever crash the app -- it
/// should just mean the paywall's buy button doesn't work yet.
class PurchaseService {
  PurchaseService(this._prefs, {this.onPremiumUnlocked});

  final SharedPreferences _prefs;
  final void Function()? onPremiumUnlocked;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? productDetails;

  bool get isPremium => _prefs.getBool(kIsPremiumKey) ?? false;

  Future<void> init() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) return;

      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (_) {},
      );

      final response = await _iap.queryProductDetails({kPremiumProductId});
      if (response.productDetails.isNotEmpty) {
        productDetails = response.productDetails.first;
      }

      // Pick up a previous purchase (e.g. after reinstalling) on startup.
      await _iap.restorePurchases();
    } catch (_) {
      // In-app purchases just aren't available right now -- the paywall
      // will show without a working price/buy button until they are.
    }
  }

  Future<void> buyPremium() async {
    final product = productDetails;
    if (product == null) return;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      // Swallow -- the purchase stream (or the user retrying) handles the
      // rest; there's no separate UI feedback path here to wire yet.
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {
      // Nothing to restore, or purchases unavailable -- no-op.
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == kPremiumProductId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        await _prefs.setBool(kIsPremiumKey, true);
        onPremiumUnlocked?.call();
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
