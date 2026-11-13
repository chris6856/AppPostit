import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'shared_storage.dart';

/// Must exactly match the in-app product ID created in Play Console / App
/// Store Connect.
const String kPremiumProductId = 'apppostit_unlimited';
const String kIsPremiumKey = 'is_premium';

/// Smart Reply packs: consumable products, each adding a number of reply
/// credits. IDs must exactly match the consumable products created in Play
/// Console / App Store Connect.
const String kReplyPack50Id = 'smart_reply_50';
const String kReplyPack125Id = 'smart_reply_125';

const Map<String, int> kReplyPackCredits = {
  kReplyPack50Id: 50,
  kReplyPack125Id: 125,
};

/// Shown when the store's localized price hasn't loaded (offline, or the
/// product isn't set up yet). Keep in sync with the store prices.
const Map<String, String> kFallbackPrices = {
  kPremiumProductId: r'$0.99',
  kReplyPack50Id: r'$1.99',
  kReplyPack125Id: r'$4.99',
};

/// Wraps [InAppPurchase] for the one-time "unlock unlimited posts" product
/// and the consumable Smart Reply packs. Every call is defensive: in-app
/// purchases can be unavailable (no Play Store on the device, the product
/// not set up yet, running in a test environment, etc.), and none of that
/// should ever crash the app -- it should just mean the buy buttons don't
/// work yet.
class PurchaseService {
  PurchaseService(
    this._storage, {
    this.onPremiumUnlocked,
    this.onRepliesPurchased,
  });

  final SharedStorage _storage;
  final void Function()? onPremiumUnlocked;

  /// Called once per completed pack purchase, before the purchase is
  /// finished with the store, so a crash before crediting means the store
  /// redelivers it. [purchaseKey] identifies the transaction, letting the
  /// callee ignore a redelivery it has already credited.
  final Future<void> Function(String purchaseKey, int replies)?
      onRepliesPurchased;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};

  ProductDetails? get productDetails => _products[kPremiumProductId];

  /// The store's localized price for [productId], or the fallback.
  String priceFor(String productId) =>
      _products[productId]?.price ?? kFallbackPrices[productId] ?? '';

  Future<void> init() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) return;

      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (_) {},
      );

      final response = await _iap.queryProductDetails({
        kPremiumProductId,
        ...kReplyPackCredits.keys,
      });
      for (final product in response.productDetails) {
        _products[product.id] = product;
      }

      // Pick up a previous unlock (e.g. after reinstalling) on startup. On
      // Android this also redelivers any pack bought but never consumed
      // (the app closed mid-purchase), so it gets credited now.
      await _iap.restorePurchases();
    } catch (_) {
      // In-app purchases just aren't available right now -- the buy
      // buttons will show without working until they are.
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

  /// Starts buying a reply pack. Returns false if the store couldn't start
  /// the purchase (product not loaded, store unavailable). The credits
  /// arrive later through the purchase stream.
  Future<bool> buyReplyPack(String productId) async {
    final product = _products[productId];
    if (product == null) return false;
    try {
      return await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        // Android: consume explicitly after crediting (below) instead of
        // the plugin's in-memory auto-consume, which is lost if the app
        // closes mid-purchase. iOS requires true; the transaction is
        // finished by completePurchase.
        autoConsume: !Platform.isAndroid,
      );
    } catch (_) {
      return false;
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
      final delivered = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      final packCredits = kReplyPackCredits[purchase.productID];

      if (packCredits != null) {
        if (delivered) {
          await _deliverReplyPack(purchase, packCredits);
          continue;
        }
      } else if (purchase.productID == kPremiumProductId && delivered) {
        await _storage.setBool(kIsPremiumKey, true);
        onPremiumUnlocked?.call();
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverReplyPack(PurchaseDetails purchase, int credits) async {
    final key = purchase.purchaseID ??
        purchase.verificationData.serverVerificationData;
    await onRepliesPurchased?.call(key, credits);

    try {
      if (Platform.isAndroid) {
        // Consuming also acknowledges the purchase and lets the same pack
        // be bought again.
        await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(purchase);
      } else if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    } catch (_) {
      // Left unconsumed/unfinished, the store redelivers it on a later
      // launch; the purchase key keeps it from being credited twice.
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
