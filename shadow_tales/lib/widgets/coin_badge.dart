import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill showing the coin balance; tapping it opens the store.
/// The "+" affordance is the primary buy-coins hook in the navbar.
class CoinBadge extends StatelessWidget {
  final int coins;
  final VoidCallback onTap;
  const CoinBadge({super.key, required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withAlpha(120)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.toll, size: 18, color: AppColors.gold),
            const SizedBox(width: 6),
            // Animated count so rewards/purchases feel tangible.
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: coins, end: coins),
              duration: const Duration(milliseconds: 400),
              builder: (_, v, __) =>
                  Text('$v', style: AppTheme.display(size: 14, color: AppColors.gold)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.add_circle, size: 18, color: AppColors.gold),
          ]),
        ),
      );
}
