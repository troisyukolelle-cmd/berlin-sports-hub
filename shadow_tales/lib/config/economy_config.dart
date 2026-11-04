/// Central place to tune prices & rewards (A/B-test these!).
/// Store product ids must match what you create in App Store Connect /
/// Google Play Console.
library;

class EconomyConfig {
  EconomyConfig._();

  // Rewarded video
  static const int adRewardCoins = 10;

  // Coin packs
  static const List<CoinPack> coinPacks = [
    CoinPack(productId: 'coins_100', coins: 100, priceLabel: r'$1.99'),
    CoinPack(
        productId: 'coins_550',
        coins: 550,
        priceLabel: r'$8.99',
        badge: 'BEST VALUE'),
  ];

  // VIP subscription
  static const String vipProductId = 'vip_monthly';
  static const String vipPriceLabel = r'$4.99/mo';
}

class CoinPack {
  final String productId;
  final int coins;
  final String priceLabel;
  final String? badge;
  const CoinPack({
    required this.productId,
    required this.coins,
    required this.priceLabel,
    this.badge,
  });
}
