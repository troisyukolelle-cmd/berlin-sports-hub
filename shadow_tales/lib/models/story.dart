/// Immutable story content model, parsed from the JSON schema documented in
/// `docs/story_schema.md`. Nothing in here is mutated at runtime — all player
/// progress lives in [PlayerState].
library;

/// Ambient colour mood of a node. Drives the background glow of the viewer.
enum Mood { neutral, crimson, emerald, gold }

Mood _moodFrom(String? s) => Mood.values.firstWhere(
      (m) => m.name == s,
      orElse: () => Mood.neutral,
    );

/// Side-effects applied to the player (used by node `onEnter` and choice
/// `consequences`). All fields are optional in JSON.
class Effects {
  final int coins;
  final Map<String, int> stats; // delta per stat id, e.g. {"sanity": -10}
  final List<String> addItems;
  final List<String> removeItems;
  final List<String> setFlags;
  final String? unlockArt;

  const Effects({
    this.coins = 0,
    this.stats = const {},
    this.addItems = const [],
    this.removeItems = const [],
    this.setFlags = const [],
    this.unlockArt,
  });

  static const none = Effects();

  factory Effects.fromJson(Map<String, dynamic>? j) {
    if (j == null) return none;
    return Effects(
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      stats: ((j['stats'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      addItems: List<String>.from(j['addItems'] ?? const []),
      removeItems: List<String>.from(j['removeItems'] ?? const []),
      setFlags: List<String>.from(j['setFlags'] ?? const []),
      unlockArt: j['unlockArt'] as String?,
    );
  }
}

/// Conditions that must hold for a choice to be shown.
class Requirements {
  final List<String> items;
  final List<String> flags;
  final Map<String, int> minStats;

  const Requirements({
    this.items = const [],
    this.flags = const [],
    this.minStats = const {},
  });

  factory Requirements.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Requirements();
    return Requirements(
      items: List<String>.from(j['items'] ?? const []),
      flags: List<String>.from(j['flags'] ?? const []),
      minStats: ((j['minStats'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
    );
  }
}

/// Marks a choice as "premium": costs coins (or is free for VIP) and unlocks
/// secret lore, a survival path or exclusive artwork.
class PremiumInfo {
  final int cost;
  final String kind; // lore | survival | art
  final String? teaser;

  const PremiumInfo({required this.cost, this.kind = 'lore', this.teaser});

  factory PremiumInfo.fromJson(Map<String, dynamic> j) => PremiumInfo(
        cost: (j['cost'] as num).toInt(),
        kind: j['kind'] as String? ?? 'lore',
        teaser: j['teaser'] as String?,
      );
}

class Choice {
  final String id;
  final String text;
  final String? hint;
  final String to; // target node id
  final PremiumInfo? premium;
  final Requirements requires;
  final Effects consequences;

  const Choice({
    required this.id,
    required this.text,
    required this.to,
    this.hint,
    this.premium,
    this.requires = const Requirements(),
    this.consequences = Effects.none,
  });

  bool get isPremium => premium != null;

  factory Choice.fromJson(Map<String, dynamic> j) => Choice(
        id: j['id'] as String,
        text: j['text'] as String,
        hint: j['hint'] as String?,
        to: j['to'] as String,
        premium: j['premium'] == null
            ? null
            : PremiumInfo.fromJson(j['premium'] as Map<String, dynamic>),
        requires: Requirements.fromJson(j['requires'] as Map<String, dynamic>?),
        consequences:
            Effects.fromJson(j['consequences'] as Map<String, dynamic>?),
      );
}

class Art {
  final String id;
  final String title;
  final bool premium;
  const Art({required this.id, required this.title, this.premium = false});

  factory Art.fromJson(Map<String, dynamic> j) => Art(
        id: j['id'] as String,
        title: j['title'] as String,
        premium: j['premium'] as bool? ?? false,
      );
}

/// Terminal state of a node. `chapter_end` and `secret` may point to the next
/// chapter, which is where the chapter paywall triggers.
class Ending {
  final String type; // death | survival | secret | chapter_end | to_be_continued
  final String title;
  final String? nextChapterId;

  const Ending({required this.type, required this.title, this.nextChapterId});

  bool get isDeath => type == 'death';

  factory Ending.fromJson(Map<String, dynamic> j) => Ending(
        type: j['type'] as String,
        title: j['title'] as String,
        nextChapterId: j['nextChapterId'] as String?,
      );
}

class StoryNode {
  final String id;
  final String chapterId;
  final Mood mood;
  final List<String> paragraphs;
  final Effects onEnter;
  final List<Choice> choices;
  final String? next; // auto-continue target when there are no choices
  final Ending? ending;
  final Art? art;

  const StoryNode({
    required this.id,
    required this.chapterId,
    required this.paragraphs,
    this.mood = Mood.neutral,
    this.onEnter = Effects.none,
    this.choices = const [],
    this.next,
    this.ending,
    this.art,
  });

  factory StoryNode.fromJson(String id, Map<String, dynamic> j) => StoryNode(
        id: id,
        chapterId: j['chapterId'] as String,
        mood: _moodFrom(j['mood'] as String?),
        paragraphs: List<String>.from(j['paragraphs'] as List),
        onEnter: Effects.fromJson(j['onEnter'] as Map<String, dynamic>?),
        choices: ((j['choices'] as List?) ?? const [])
            .map((c) => Choice.fromJson(c as Map<String, dynamic>))
            .toList(),
        next: j['next'] as String?,
        ending: j['ending'] == null
            ? null
            : Ending.fromJson(j['ending'] as Map<String, dynamic>),
        art: j['art'] == null
            ? null
            : Art.fromJson(j['art'] as Map<String, dynamic>),
      );
}

/// How a chapter is unlocked.
class ChapterUnlock {
  final bool free;
  final int coinCost;
  final bool allowRewardedAd;

  const ChapterUnlock({
    this.free = true,
    this.coinCost = 0,
    this.allowRewardedAd = false,
  });

  factory ChapterUnlock.fromJson(Map<String, dynamic>? j) {
    if (j == null || j['type'] == 'free') return const ChapterUnlock();
    return ChapterUnlock(
      free: false,
      coinCost: (j['coinCost'] as num?)?.toInt() ?? 0,
      allowRewardedAd: j['allowRewardedAd'] as bool? ?? false,
    );
  }
}

class Chapter {
  final String id;
  final String title;
  final String summary;
  final String startNodeId;
  final ChapterUnlock unlock;

  const Chapter({
    required this.id,
    required this.title,
    required this.summary,
    required this.startNodeId,
    required this.unlock,
  });

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'] as String,
        title: j['title'] as String,
        summary: j['summary'] as String? ?? '',
        startNodeId: j['startNodeId'] as String,
        unlock: ChapterUnlock.fromJson(j['unlock'] as Map<String, dynamic>?),
      );
}

class StatDef {
  final String id;
  final String label;
  final int max;
  final String color; // crimson | emerald | gold
  const StatDef(this.id, this.label, this.max, this.color);

  factory StatDef.fromJson(Map<String, dynamic> j) => StatDef(
        j['id'] as String,
        j['label'] as String,
        (j['max'] as num?)?.toInt() ?? 100,
        j['color'] as String? ?? 'gold',
      );
}

class Story {
  final String id;
  final String title;
  final String tagline;
  final String startChapterId;
  final int startingCoins;
  final Map<String, int> startingStats;
  final List<StatDef> stats;
  final List<Chapter> chapters;
  final Map<String, StoryNode> nodes;

  const Story({
    required this.id,
    required this.title,
    required this.tagline,
    required this.startChapterId,
    required this.startingCoins,
    required this.startingStats,
    required this.stats,
    required this.chapters,
    required this.nodes,
  });

  Chapter chapter(String id) => chapters.firstWhere((c) => c.id == id);
  StoryNode node(String nodeId) {
    final n = nodes[nodeId];
    if (n == null) throw StateError('Story "$id" has no node "$nodeId"');
    return n;
  }

  StatDef? statDef(String id) {
    for (final s in stats) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory Story.fromJson(Map<String, dynamic> j) {
    final start = (j['startingResources'] as Map?) ?? const {};
    final story = Story(
      id: j['id'] as String,
      title: j['title'] as String,
      tagline: j['tagline'] as String? ?? '',
      startChapterId: j['startChapterId'] as String,
      startingCoins: (start['coins'] as num?)?.toInt() ?? 0,
      startingStats: ((start['stats'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      stats: ((j['stats'] as List?) ?? const [])
          .map((s) => StatDef.fromJson(s as Map<String, dynamic>))
          .toList(),
      chapters: (j['chapters'] as List)
          .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
          .toList(),
      nodes: (j['nodes'] as Map<String, dynamic>).map(
        (id, n) => MapEntry(id, StoryNode.fromJson(id, n as Map<String, dynamic>)),
      ),
    );
    story.validate();
    return story;
  }

  /// Fails fast on dangling references so authoring mistakes show up on load,
  /// not when a player hits a broken branch.
  void validate() {
    for (final c in chapters) {
      if (!nodes.containsKey(c.startNodeId)) {
        throw StateError('Chapter ${c.id}: unknown startNodeId ${c.startNodeId}');
      }
    }
    for (final n in nodes.values) {
      for (final ch in n.choices) {
        if (!nodes.containsKey(ch.to)) {
          throw StateError('Node ${n.id} choice ${ch.id}: unknown target ${ch.to}');
        }
      }
      if (n.next != null && !nodes.containsKey(n.next)) {
        throw StateError('Node ${n.id}: unknown next ${n.next}');
      }
      final nc = n.ending?.nextChapterId;
      if (nc != null && !chapters.any((c) => c.id == nc)) {
        throw StateError('Node ${n.id}: unknown nextChapterId $nc');
      }
    }
  }
}
