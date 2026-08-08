import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'shared_storage.dart';

/// Must exactly match the in-app product ID created in Play Console / App
/// Store Connect.
const String kPremiumProductId = 'apppostit_unlimited';
const String kIsPremiumKey = 'is_premium';

/// Wraps [InAppPurchase] for the single "unlock unlimited posts" product.
/// Every call is defensive: in-app purchases can be unavailable (no Play
/// Store on the device, the product not set up yet, running in a test
/// environment, etc.), and none of that should ever crash the app -- it
/// should just mean the paywall's buy button doesn't work yet.
class PurchaseService {
  PurchaseService(this._storage, {this.onPremiumUnlocked});

  final SharedStorage _storage;
  final void Function()? onPremiumUnlocked;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? productDetails;

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

  /// Returns whether a premium purchase was found and restored. The
  /// paywall only ever shows when the user isn't already premium, so if
  /// [kIsPremiumKey] is true after this call, it must have just been set
  /// by the restore -- there's no other way it could have flipped.
  Future<bool> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {
      // Fall through -- still check storage in case a purchase update
      // arrived before the error (some platforms report errors for
      // reasons unrelated to whether anything was actually restored).
    }
    // Give any purchaseStream events the restore call triggered a moment
    // to finish processing (setting is_premium) before checking.
    await Future.delayed(const Duration(milliseconds: 500));
    return await _storage.getBool(kIsPremiumKey) ?? false;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == kPremiumProductId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        await _storage.setBool(kIsPremiumKey, true);
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
