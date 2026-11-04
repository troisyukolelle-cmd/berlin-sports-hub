# Shadow Tales — interactive folklore horror (Flutter)

Choose-your-own-adventure built to convert short-form-video followers: dark UI, crimson /
emerald / gold accents, line-by-line story reveal, premium (gem) choices, a coin economy,
rewarded ads and a VIP pass.

## Run

```bash
cd shadow_tales
flutter create . --project-name shadow_tales --platforms android,ios   # one-time: generates android/ ios/
flutter pub get
flutter run
flutter test
```

Playable out of the box with **mock** ads and **mock** purchases (every purchase succeeds).

## Layout

| Path | Purpose |
|------|---------|
| `assets/stories/whisper_in_the_well.json` | Starter story (3-choice opening, 2 premium choices, 4 endings, locked chapter 2) |
| `docs/story_schema.md` | JSON schema for stories, nodes, choices, costs, consequences |
| `lib/models/` | `story.dart` (content + validation), `player_state.dart` (persisted progress) |
| `lib/state/game_controller.dart` | All branching + economy rules (single source of truth) |
| `lib/services/` | `storage` (local save), `ad_service` & `billing_service` (interfaces + mocks) |
| `lib/screens/story_screen.dart` | Story Viewer: navbar w/ coins + VIP, paragraph reveal, choices |
| `lib/widgets/paywall_sheet.dart` | Monetization modal: VIP vs rewarded ad vs coins vs coin packs |
| `lib/config/economy_config.dart` | Prices, product ids, ad reward |

## Monetization flow

* **Chapter locks** → paywall offers: VIP ($4.99/mo), coins, or a rewarded video.
* **Premium choice** (gem + lock) → charged in coins; if short, paywall offers VIP, a video
  for +10 coins, or *Buy 100 Coins ($1.99)*.
* **VIP** unlocks all chapters/choices and hides ad prompts.
* Navbar always shows the coin balance (tap = store) and a VIP button.
* Restarting a run keeps coins, VIP and unlocks (they are paid assets).

## Going live

1. **Ads**: implement `AdService` with `google_mobile_ads` (RewardedAd). Use test ad-unit ids first.
2. **Purchases**: implement `BillingService` with `in_app_purchase` or RevenueCat; create
   products matching `EconomyConfig` ids (`coins_100`, `coins_550`, `vip_monthly`).
   Verify receipts server-side and handle *Restore purchases* + subscription expiry.
3. Fonts load via `google_fonts` at runtime; bundle them under `assets/` for offline first run.
4. Replace the procedural sigil (`sigil_art.dart`) with real artwork assets if desired.
5. Content note: the story references Islamic practice (Ayat al-Kursi, adhan) respectfully as
   protection; have a native-speaking sensitivity reader review before publishing.
6. App Store / Play policies: disclose subscription terms next to the price and add
   privacy/terms links before submission.
