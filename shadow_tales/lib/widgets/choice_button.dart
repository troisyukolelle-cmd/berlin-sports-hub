import 'package:flutter/material.dart';

import '../models/story.dart';
import '../theme/app_theme.dart';

/// A single choice. Premium choices show a gem + price (or a crown-free
/// "VIP" tag) and use a gold outline; standard ones use crimson.
class ChoiceButton extends StatelessWidget {
  final Choice choice;

  /// True if the player must still pay coins for this choice.
  final bool locked;
  final bool vip;
  final VoidCallback onTap;

  const ChoiceButton({
    super.key,
    required this.choice,
    required this.locked,
    required this.vip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final premium = choice.isPremium;
    final accent = premium ? AppColors.gold : AppColors.crimson;
    return Material(
      color: premium ? AppColors.gold.withAlpha(18) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withAlpha(premium ? 200 : 140)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(choice.text, style: AppTheme.display(size: 14)),
                  if ((premium ? choice.premium!.teaser : choice.hint) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        premium ? choice.premium!.teaser! : choice.hint!,
                        style: AppTheme.body(
                            size: 15, color: AppColors.textDim, italic: true),
                      ),
                    ),
                ],
              ),
            ),
            if (premium) ...[
              const SizedBox(width: 10),
              _PriceTag(cost: choice.premium!.cost, locked: locked, vip: vip),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final int cost;
  final bool locked;
  final bool vip;
  const _PriceTag({required this.cost, required this.locked, required this.vip});

  @override
  Widget build(BuildContext context) {
    if (!locked) {
      // Already paid for, or VIP.
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(vip ? Icons.workspace_premium : Icons.lock_open,
            size: 18, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(vip ? 'VIP' : 'OWNED',
            style: AppTheme.display(size: 11, color: AppColors.gold)),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.lock, size: 16, color: AppColors.gold),
      const SizedBox(width: 4),
      const Icon(Icons.diamond, size: 16, color: AppColors.gold),
      const SizedBox(width: 3),
      Text('$cost', style: AppTheme.display(size: 14, color: AppColors.gold)),
    ]);
  }
}
