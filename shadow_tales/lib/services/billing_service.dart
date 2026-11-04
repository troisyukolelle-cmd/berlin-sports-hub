import '../config/economy_config.dart';

/// In-app purchase abstraction.
///
/// PRODUCTION: implement with `in_app_purchase` (or RevenueCat's
/// `purchases_flutter`). IMPORTANT: verify receipts server-side before
/// granting coins / VIP, and handle restore-purchases for the subscription.
abstract class BillingService {
  /// Consumable coin pack. Resolves `true` when the purchase succeeded.
  Future<bool> buyCoinPack(CoinPack pack);

  /// Auto-renewing VIP subscription. Resolves the expiry date, or null if
  /// cancelled / failed.
  Future<DateTime?> subscribeVip();
}

/// Development stand-in: every purchase "succeeds" after a short delay.
class MockBillingService implements BillingService {
  @override
  Future<bool> buyCoinPack(CoinPack pack) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return true;
  }

  @override
  Future<DateTime?> subscribeVip() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return DateTime.now().add(const Duration(days: 30));
  }
}
