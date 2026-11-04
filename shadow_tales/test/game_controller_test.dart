import 'package:shadow_tales/state/game_controller.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_tales/config/economy_config.dart';
import 'package:shadow_tales/models/story.dart';
import 'package:shadow_tales/services/ad_service.dart';
import 'package:shadow_tales/services/billing_service.dart';
import 'package:shadow_tales/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

class _NoAds implements AdService {
  @override
  Future<bool> showRewardedAd(BuildContext context) async => true;
}

Future<(GameController, StorageService)> _make() async {
  SharedPreferences.setMockInitialValues({});
  final story = Story.fromJson(jsonDecode(
          File('assets/stories/whisper_in_the_well.json').readAsStringSync())
      as Map<String, dynamic>);
  final storage = await StorageService.create();
  final g = GameController(
      story: story, storage: storage, ads: _NoAds(), billing: MockBillingService());
  return (g, storage);
}

void main() {
  test('story JSON validates and starts at the arrival node', () async {
    final (g, _) = await _make();
    expect(g.node.id, 'n_arrival');
    expect(g.coins, 40);
  });

  test('premium choice charges coins once; blocks when broke', () async {
    final (g, _) = await _make();
    g.advance(); // -> n_voice
    g.choose(g.node.choices.firstWhere((c) => c.id == 'c_cellar'));
    final letter = g.node.choices.firstWhere((c) => c.id == 'c_letter');
    expect(g.state.inventory, contains('misbaha'));

    g.state.coins = 5;
    expect(g.choose(letter), ChoiceResult.needsPayment);
    expect(g.node.id, 'n_cellar');

    g.state.coins = 20;
    expect(g.choose(letter), ChoiceResult.taken);
    expect(g.coins, 5);
    expect(g.state.unlockedArt, contains('sigil_qareen'));
  });

  test('chapter 2 is locked until paid; VIP bypasses', () async {
    final (g, _) = await _make();
    expect(g.isChapterUnlocked('ch2'), isFalse);
    expect(g.enterChapter('ch2'), isFalse);
    expect(g.unlockChapterWithCoins('ch2'), isTrue); // 40 -> 10
    expect(g.coins, 10);
    expect(g.enterChapter('ch2'), isTrue);

    final (g2, _) = await _make();
    await g2.subscribeVip();
    expect(g2.isChapterUnlocked('ch2'), isTrue);
    expect(g2.adsEnabled, isFalse);
  });

  test('coin pack grants coins and progress persists', () async {
    final (g, storage) = await _make();
    await g.buyCoinPack(EconomyConfig.coinPacks.first);
    expect(g.coins, 140);
    final saved = storage.load(g.story.id)!;
    expect(saved.coins, 140);
  });

  test('requirement-gated choice only visible with the item', () async {
    final (g, _) = await _make();
    g.advance();
    g.choose(g.node.choices.firstWhere((c) => c.id == 'c_pray'));
    expect(g.visibleChoices.map((c) => c.id), ['c_hold']);
    g.state.inventory.add('misbaha');
    expect(g.visibleChoices.map((c) => c.id), contains('c_seal'));
  });
}
