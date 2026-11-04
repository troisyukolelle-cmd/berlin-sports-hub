# Story JSON schema (v1)

One file per story in `assets/stories/`. It is parsed by `lib/models/story.dart`,
which also **validates** every reference (`to`, `next`, `startNodeId`,
`nextChapterId`) on load — a typo throws at startup instead of dead-ending a player.

```jsonc
{
  "schemaVersion": 1,
  "id": "whisper_in_the_well",          // save-slot key — never change after launch
  "title": "…", "tagline": "…",
  "startChapterId": "ch1",
  "startingResources": { "coins": 40, "stats": { "sanity": 100, "faith": 1 } },

  "stats": [ { "id": "sanity", "label": "Sanity", "max": 100, "color": "crimson|emerald|gold" } ],

  "chapters": [
    {
      "id": "ch2", "title": "…", "summary": "…", "startNodeId": "n_ch2_open",
      "unlock": { "type": "free" }
      // or: { "type": "paid", "coinCost": 30, "allowRewardedAd": true }
      // VIP always unlocks every chapter.
    }
  ],

  "nodes": {
    "<nodeId>": {
      "chapterId": "ch1",
      "mood": "neutral|crimson|emerald|gold",   // ambient background glow
      "paragraphs": ["revealed one at a time", "lines starting with \" render as speech"],
      "onEnter": { /* Effects, applied once per run */ },

      // A node is exactly one of: choices, next, or ending
      "choices": [ /* Choice */ ],
      "next": "<nodeId>",                        // "Continue" button
      "ending": { "type": "death|survival|secret|chapter_end|to_be_continued",
                  "title": "…", "nextChapterId": "ch2" },   // nextChapterId triggers the chapter paywall

      "art": { "id": "sigil_qareen", "title": "…", "premium": true }  // artwork card shown after the text
    }
  }
}
```

## Choice

```jsonc
{
  "id": "c_letter",                 // unique; used to remember premium purchases
  "text": "Break the seal on Grandmother's letter",
  "hint": "Secret lore",            // italic sub-line (standard choices)
  "to": "n_lore",
  "premium": { "cost": 15, "kind": "lore|survival|art", "teaser": "What did the family bury here?" },
  "requires": { "items": ["misbaha"], "flags": ["read_letter"], "minStats": { "faith": 2 } },
  "consequences": { /* Effects, applied when taken */ }
}
```

* **Premium** choices show a lock + gem + price. Paying once records the choice id in
  `paidChoices`, so replays are free. VIP skips the charge entirely.
* **requires** hides the choice until all conditions hold (inventory / flags / min stats).

## Effects (`onEnter` and `consequences`)

```jsonc
{
  "coins": 5,                          // reward (or negative for penalty)
  "stats": { "sanity": -10 },          // deltas, clamped to 0..max
  "addItems": ["misbaha"], "removeItems": [],
  "setFlags": ["read_letter"],
  "unlockArt": "sigil_qareen"
}
```

## Persisted player state (SharedPreferences, key `save.<storyId>`)

`coins, totalEarned, totalSpent, vipUntil, currentNodeId, unlockedChapters, paidChoices,
unlockedArt, endingsFound, visitedNodes, stats, inventory, flags` — see `lib/models/player_state.dart`.
