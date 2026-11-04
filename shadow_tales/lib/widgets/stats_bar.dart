import 'package:flutter/material.dart';

import '../models/player_state.dart';
import '../models/story.dart';
import '../theme/app_theme.dart';

/// Slim sanity / imaan meters shown under the navbar.
class StatsBar extends StatelessWidget {
  final Story story;
  final PlayerState state;
  const StatsBar({super.key, required this.story, required this.state});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          for (final s in story.stats) ...[
            Expanded(child: _Meter(def: s, value: state.stats[s.id] ?? 0)),
            if (s != story.stats.last) const SizedBox(width: 16),
          ],
        ]),
      );
}

class _Meter extends StatelessWidget {
  final StatDef def;
  final int value;
  const _Meter({required this.def, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.byName(def.color);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(def.label.toUpperCase(),
          style: AppTheme.display(size: 9, color: AppColors.textDim)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (value / def.max).clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 600),
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 4,
            color: color,
            backgroundColor: Colors.white10,
          ),
        ),
      ),
    ]);
  }
}
