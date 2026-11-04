import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/story.dart';
import '../theme/app_theme.dart';

/// "Exclusive artwork" card. Real art would be an asset image; this draws a
/// procedural occult sigil so the feature works with zero binary assets.
class ArtCard extends StatelessWidget {
  final Art art;
  const ArtCard({super.key, required this.art});

  @override
  Widget build(BuildContext context) {
    final color = art.premium ? AppColors.gold : AppColors.emerald;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Column(children: [
        SizedBox(
          height: 150,
          width: 150,
          child: CustomPaint(painter: _SigilPainter(color, art.id.hashCode)),
        ),
        const SizedBox(height: 8),
        Text(art.premium ? 'ARTWORK UNLOCKED · PREMIUM' : 'ARTWORK UNLOCKED',
            style: AppTheme.display(size: 10, color: color)),
        const SizedBox(height: 2),
        Text(art.title, style: AppTheme.body(size: 17, italic: true)),
      ]),
    );
  }
}

class _SigilPainter extends CustomPainter {
  final Color color;
  final int seed;
  _SigilPainter(this.color, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas
      ..drawCircle(c, r, p)
      ..drawCircle(c, r * 0.72, p..color = color.withAlpha(150));

    // Star polygon whose point count is derived from the art id.
    final n = 5 + seed.abs() % 4; // 5..8 points
    final pts = [
      for (var i = 0; i < n; i++)
        c + Offset.fromDirection(2 * math.pi * i / n - math.pi / 2, r * 0.72),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i <= n; i++) {
      final q = pts[(i * 2) % n];
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(path, p..color = color);

    // Crescent in the middle.
    canvas.drawCircle(c, r * 0.22, Paint()..color = color.withAlpha(220));
    canvas.drawCircle(c.translate(r * 0.1, 0), r * 0.2,
        Paint()..color = const Color(0xFF131316));
  }

  @override
  bool shouldRepaint(_SigilPainter old) => old.color != color || old.seed != seed;
}
