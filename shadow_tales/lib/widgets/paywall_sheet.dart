import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/economy_config.dart';
import '../models/story.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';

/// Why the paywall is being shown. Exactly one of the fields is set, except
/// for the plain store (both null).
class PaywallRequest {
  /// A locked chapter the player tried to open.
  final Chapter? chapter;

  /// A premium choice that costs this many coins more than the balance.
  final int? coinsNeeded;

  const PaywallRequest.chapter(Chapter this.chapter) : coinsNeeded = null;
  const PaywallRequest.coins(int this.coinsNeeded) : chapter = null;
  const PaywallRequest.store()
      : chapter = null,
        coinsNeeded = null;
}

/// Opens the monetisation modal. Resolves `true` when the request that
/// triggered it has been satisfied (chapter unlocked / enough coins), so the
/// caller can retry the blocked action.
Future<bool> showPaywall(BuildContext context, PaywallRequest request) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider<GameController>.value(
      value: context.read<GameController>(),
      child: _PaywallSheet(request: request),
    ),
  );
  return ok ?? false;
}

class _PaywallSheet extends StatefulWidget {
  final PaywallRequest request;
  const _PaywallSheet({required this.request});

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  bool _busy = false;

  PaywallRequest get _req => widget.request;

  /// Runs [action] with a busy lock, then closes the sheet if the original
  /// request is now satisfied.
  Future<void> _run(Future<bool> Function() action, {String? failMsg}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      if (failMsg != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failMsg)));
      }
      return;
    }
    final g = context.read<GameController>();
    final satisfied = switch (_req) {
      PaywallRequest(chapter: final c?) => g.isChapterUnlocked(c.id),
      PaywallRequest(coinsNeeded: final n?) => g.isVip || g.coins >= n,
      _ => false,
    };
    if (satisfied) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final chapter = _req.chapter;

    final title = chapter != null
        ? 'This chapter is sealed'
        : _req.coinsNeeded != null
            ? 'Not enough coins'
            : 'The Shadow Market';
    final subtitle = chapter != null
        ? chapter.title
        : _req.coinsNeeded != null
            ? 'You need ${_req.coinsNeeded} coins — you have ${g.coins}.'
            : 'Your balance: ${g.coins} coins';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: AppTheme.display(size: 22)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 17, color: AppColors.textDim)),
            const SizedBox(height: 18),

            // --- VIP (hero offer) ----------------------------------------
            if (!g.isVip)
              _OptionCard(
                highlight: true,
                icon: Icons.workspace_premium,
                iconColor: AppColors.gold,
                badge: 'RECOMMENDED',
                title: 'Unlock VIP Access (${EconomyConfig.vipPriceLabel})',
                subtitle: 'Every chapter & premium choice. No ads. Cancel anytime.',
                onTap: _busy
                    ? null
                    : () => _run(g.subscribeVip,
                        failMsg: 'Subscription was not completed.'),
              )
            else
              const _OptionCard(
                highlight: true,
                icon: Icons.verified,
                iconColor: AppColors.gold,
                title: 'VIP active',
                subtitle: 'All chapters and premium choices are unlocked.',
              ),
            const SizedBox(height: 12),

            // --- Chapter unlock: coins -----------------------------------
            if (chapter != null && !chapter.unlock.free) ...[
              _OptionCard(
                icon: Icons.toll,
                iconColor: AppColors.gold,
                title: 'Unlock for ${chapter.unlock.coinCost} coins',
                subtitle: g.coins >= chapter.unlock.coinCost
                    ? 'Balance: ${g.coins}'
                    : 'Need ${chapter.unlock.coinCost - g.coins} more coins',
                onTap: _busy || g.coins < chapter.unlock.coinCost
                    ? null
                    : () => _run(
                          () async => g.unlockChapterWithCoins(chapter.id),
                        ),
              ),
              const SizedBox(height: 12),
              // --- Chapter unlock: rewarded video ------------------------
              if (chapter.unlock.allowRewardedAd && g.adsEnabled) ...[
                _OptionCard(
                  icon: Icons.play_circle_fill,
                  iconColor: AppColors.emerald,
                  title: 'Watch a short video',
                  subtitle: 'Free — unlocks this chapter once',
                  onTap: _busy
                      ? null
                      : () => _run(
                            () => g.unlockChapterWithAd(context, chapter.id),
                            failMsg: 'Watch the full video to get the reward.',
                          ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // --- Coins via rewarded video --------------------------------
            if (chapter == null && g.adsEnabled) ...[
              _OptionCard(
                icon: Icons.play_circle_fill,
                iconColor: AppColors.emerald,
                title: 'Watch a video, get ${EconomyConfig.adRewardCoins} coins',
                subtitle: 'Free',
                onTap: _busy
                    ? null
                    : () => _run(() => g.watchAdForCoins(context),
                        failMsg: 'Watch the full video to get the reward.'),
              ),
              const SizedBox(height: 12),
            ],

            // --- Coin packs ----------------------------------------------
            for (final p in EconomyConfig.coinPacks) ...[
              _OptionCard(
                icon: Icons.diamond_outlined,
                iconColor: AppColors.crimson,
                badge: p.badge,
                title: 'Buy ${p.coins} Coins (${p.priceLabel})',
                subtitle: 'One-time purchase',
                onTap: _busy
                    ? null
                    : () => _run(() => g.buyCoinPack(p),
                        failMsg: 'Purchase was not completed.'),
              ),
              const SizedBox(height: 12),
            ],

            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: Text('Not now',
                  style: AppTheme.body(size: 16, color: AppColors.textDim)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable offer row. `onTap == null` renders it disabled.
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final bool highlight;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final border = highlight ? AppColors.gold : Colors.white12;
    return Opacity(
      opacity: enabled || highlight ? 1 : 0.45,
      child: Material(
        color: highlight
            ? AppColors.gold.withAlpha(24)
            : AppColors.surfaceHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: highlight ? 1.4 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(badge!,
                              style: AppTheme.display(
                                  size: 10, color: AppColors.gold)),
                        ),
                      Text(title, style: AppTheme.display(size: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: AppTheme.body(
                              size: 15, color: AppColors.textDim)),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right, color: AppColors.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
