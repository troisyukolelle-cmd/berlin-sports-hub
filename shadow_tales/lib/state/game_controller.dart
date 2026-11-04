import 'package:flutter/widgets.dart';

import '../config/economy_config.dart';
import '../models/player_state.dart';
import '../models/story.dart';
import '../services/ad_service.dart';
import '../services/billing_service.dart';
import '../services/storage_service.dart';

/// Result of trying to take a choice.
enum ChoiceResult {
  /// Choice taken, story advanced.
  taken,

  /// Premium choice but not enough coins -> show the paywall.
  needsPayment,
}

/// Single source of truth for story progress and the in-app economy.
/// UI widgets read from it via `context.watch<GameController>()`.
class GameController extends ChangeNotifier {
  final Story story;
  final StorageService _storage;
  final AdService _ads;
  final BillingService _billing;

  late PlayerState state;

  GameController({
    required this.story,
    required StorageService storage,
    required AdService ads,
    required BillingService billing,
  })  : _storage = storage,
        _ads = ads,
        _billing = billing {
    final saved = _storage.load(story.id);
    if (saved != null && story.nodes.containsKey(saved.currentNodeId)) {
      state = saved;
    } else {
      _freshStart();
    }
  }

  // ---------------------------------------------------------------------
  // Read-only helpers for the UI
  // ---------------------------------------------------------------------

  StoryNode get node => story.node(state.currentNodeId);
  Chapter get chapter => story.chapter(node.chapterId);
  int get coins => state.coins;
  bool get isVip => state.isVip;

  /// VIP removes ads: the UI should hide ad entry points when this is false.
  bool get adsEnabled => !isVip;

  bool isChapterUnlocked(String chapterId) =>
      isVip ||
      story.chapter(chapterId).unlock.free ||
      state.unlockedChapters.contains(chapterId);

  /// Choices the player may currently see (requirements met).
  List<Choice> get visibleChoices =>
      node.choices.where((c) => state.meets(c.requires)).toList();

  /// True if [c] costs coins right now (premium, unpaid, non-VIP).
  bool needsPayment(Choice c) =>
      c.isPremium && !isVip && !state.paidChoices.contains(c.id);

  // ---------------------------------------------------------------------
  // Story flow
  // ---------------------------------------------------------------------

  /// Takes [c]. Premium choices are charged here (VIP bypasses the charge).
  ChoiceResult choose(Choice c) {
    if (needsPayment(c)) {
      if (state.coins < c.premium!.cost) return ChoiceResult.needsPayment;
      _spend(c.premium!.cost);
      state.paidChoices.add(c.id);
    }
    state.apply(c.consequences, story);
    _goTo(c.to);
    return ChoiceResult.taken;
  }

  /// Continue from a node with no choices (`next`).
  void advance() {
    final n = node.next;
    if (n != null) _goTo(n);
  }

  /// Moves into the first node of [chapterId]. Returns false when still locked.
  bool enterChapter(String chapterId) {
    if (!isChapterUnlocked(chapterId)) return false;
    _goTo(story.chapter(chapterId).startNodeId);
    return true;
  }

  /// Restarts the story run (path, items, stats). Coins, VIP and unlocks are
  /// real-money assets, so they are preserved.
  void restart() {
    final keepCoins = state.coins;
    final keepEarned = state.totalEarned;
    final keepSpent = state.totalSpent;
    final keepVip = state.vipUntil;
    final keepChapters = Set<String>.of(state.unlockedChapters);
    final keepPaid = Set<String>.of(state.paidChoices);
    final keepArt = Set<String>.of(state.unlockedArt);
    final keepEndings = Set<String>.of(state.endingsFound);

    _freshStart();
    state
      ..coins = keepCoins
      ..totalEarned = keepEarned
      ..totalSpent = keepSpent
      ..vipUntil = keepVip
      ..unlockedChapters.addAll(keepChapters)
      ..paidChoices.addAll(keepPaid)
      ..unlockedArt.addAll(keepArt)
      ..endingsFound.addAll(keepEndings);
    _commit();
  }

  // ---------------------------------------------------------------------
  // Monetisation actions
  // ---------------------------------------------------------------------

  /// (a) Pay coins to unlock a chapter.
  bool unlockChapterWithCoins(String chapterId) {
    final cost = story.chapter(chapterId).unlock.coinCost;
    if (state.coins < cost) return false;
    _spend(cost);
    state.unlockedChapters.add(chapterId);
    _commit();
    return true;
  }

  /// (b) Watch a rewarded ad to unlock a chapter.
  Future<bool> unlockChapterWithAd(BuildContext context, String chapterId) async {
    if (!story.chapter(chapterId).unlock.allowRewardedAd) return false;
    final rewarded = await _ads.showRewardedAd(context);
    if (!rewarded) return false;
    state.unlockedChapters.add(chapterId);
    _commit();
    return true;
  }

  /// Watch a rewarded ad for a small coin grant (premium-choice paywall).
  Future<bool> watchAdForCoins(BuildContext context) async {
    final rewarded = await _ads.showRewardedAd(context);
    if (!rewarded) return false;
    _grant(EconomyConfig.adRewardCoins);
    _commit();
    return true;
  }

  /// Coin pack purchase (consumable IAP).
  Future<bool> buyCoinPack(CoinPack pack) async {
    if (!await _billing.buyCoinPack(pack)) return false;
    _grant(pack.coins);
    _commit();
    return true;
  }

  /// (c) VIP subscription: unlocks all chapters & choices, removes ads.
  Future<bool> subscribeVip() async {
    final until = await _billing.subscribeVip();
    if (until == null) return false;
    state.vipUntil = until;
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  void _freshStart() {
    state = PlayerState.initial(story);
    _enter(state.currentNodeId);
    _commit();
  }

  void _goTo(String nodeId) {
    state.currentNodeId = nodeId;
    _enter(nodeId);
    _commit();
  }

  /// Applies a node's `onEnter` effects exactly once per run and records
  /// endings. Guarded by `visitedNodes` so re-entering never double-pays.
  void _enter(String nodeId) {
    final n = story.node(nodeId);
    if (state.visitedNodes.add(nodeId)) {
      state.apply(n.onEnter, story);
    }
    if (n.ending != null) state.endingsFound.add(nodeId);
  }

  void _spend(int n) {
    state.coins -= n;
    state.totalSpent += n;
  }

  void _grant(int n) {
    state.coins += n;
    state.totalEarned += n;
  }

  void _commit() {
    _storage.save(story.id, state); // fire-and-forget
    notifyListeners();
  }
}
