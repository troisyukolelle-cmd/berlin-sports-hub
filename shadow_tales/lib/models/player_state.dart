/// Everything about the player that must survive an app restart.
/// Serialised as JSON into SharedPreferences by [StorageService].
library;

import 'story.dart';

class PlayerState {
  // --- Economy ----------------------------------------------------------
  int coins;
  int totalEarned;
  int totalSpent;

  /// VIP pass: unlocks all choices & removes ads while active.
  DateTime? vipUntil;

  // --- Progress ---------------------------------------------------------
  String currentNodeId;
  final Set<String> unlockedChapters;

  /// Premium choices already paid for (so replays are free).
  final Set<String> paidChoices;
  final Set<String> unlockedArt;
  final Set<String> endingsFound; // node ids of endings reached
  final Set<String> visitedNodes;

  // --- Character --------------------------------------------------------
  final Map<String, int> stats;
  final Set<String> inventory;
  final Set<String> flags;

  PlayerState({
    required this.coins,
    required this.currentNodeId,
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.vipUntil,
    Set<String>? unlockedChapters,
    Set<String>? paidChoices,
    Set<String>? unlockedArt,
    Set<String>? endingsFound,
    Set<String>? visitedNodes,
    Map<String, int>? stats,
    Set<String>? inventory,
    Set<String>? flags,
  })  : unlockedChapters = unlockedChapters ?? {},
        paidChoices = paidChoices ?? {},
        unlockedArt = unlockedArt ?? {},
        endingsFound = endingsFound ?? {},
        visitedNodes = visitedNodes ?? {},
        stats = stats ?? {},
        inventory = inventory ?? {},
        flags = flags ?? {};

  /// Fresh save for a story.
  factory PlayerState.initial(Story story) => PlayerState(
        coins: story.startingCoins,
        totalEarned: story.startingCoins,
        currentNodeId: story.chapter(story.startChapterId).startNodeId,
        unlockedChapters: {
          for (final c in story.chapters)
            if (c.unlock.free) c.id,
        },
        stats: Map.of(story.startingStats),
      );

  bool get isVip => vipUntil != null && vipUntil!.isAfter(DateTime.now());

  /// Whether [r] is satisfied by the current inventory / flags / stats.
  bool meets(Requirements r) =>
      r.items.every(inventory.contains) &&
      r.flags.every(flags.contains) &&
      r.minStats.entries.every((e) => (stats[e.key] ?? 0) >= e.value);

  /// Applies [e] (stat deltas are clamped to the stat's range when known).
  void apply(Effects e, Story story) {
    if (e.coins != 0) {
      coins += e.coins;
      if (e.coins > 0) totalEarned += e.coins;
    }
    e.stats.forEach((id, delta) {
      final max = story.statDef(id)?.max ?? 1 << 30;
      stats[id] = ((stats[id] ?? 0) + delta).clamp(0, max);
    });
    inventory
      ..addAll(e.addItems)
      ..removeAll(e.removeItems);
    flags.addAll(e.setFlags);
    if (e.unlockArt != null) unlockedArt.add(e.unlockArt!);
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'coins': coins,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
        'vipUntil': vipUntil?.toIso8601String(),
        'currentNodeId': currentNodeId,
        'unlockedChapters': unlockedChapters.toList(),
        'paidChoices': paidChoices.toList(),
        'unlockedArt': unlockedArt.toList(),
        'endingsFound': endingsFound.toList(),
        'visitedNodes': visitedNodes.toList(),
        'stats': stats,
        'inventory': inventory.toList(),
        'flags': flags.toList(),
      };

  factory PlayerState.fromJson(Map<String, dynamic> j) {
    Set<String> set(String k) => Set<String>.from(j[k] as List? ?? const []);
    return PlayerState(
      coins: (j['coins'] as num).toInt(),
      totalEarned: (j['totalEarned'] as num?)?.toInt() ?? 0,
      totalSpent: (j['totalSpent'] as num?)?.toInt() ?? 0,
      vipUntil:
          j['vipUntil'] == null ? null : DateTime.tryParse(j['vipUntil'] as String),
      currentNodeId: j['currentNodeId'] as String,
      unlockedChapters: set('unlockedChapters'),
      paidChoices: set('paidChoices'),
      unlockedArt: set('unlockedArt'),
      endingsFound: set('endingsFound'),
      visitedNodes: set('visitedNodes'),
      stats: ((j['stats'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      inventory: set('inventory'),
      flags: set('flags'),
    );
  }
}
