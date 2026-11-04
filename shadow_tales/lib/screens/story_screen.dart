import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/story.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_button.dart';
import '../widgets/coin_badge.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/sigil_art.dart';
import '../widgets/stats_bar.dart';

/// The primary screen: top navbar (coins / VIP), ambient mood background,
/// paragraph-by-paragraph story text and dynamic choice buttons.
class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final node = g.node;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _NavBar(g: g),
      // Ambient glow that cross-fades with the node's mood.
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.1),
            radius: 1.2,
            colors: [AppColors.glow(node.mood).withAlpha(70), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: kToolbarHeight - 8),
              StatsBar(story: g.story, state: g.state),
              const SizedBox(height: 8),
              Expanded(
                // Smooth fade between nodes; the key restarts the reveal.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _NodeView(key: ValueKey(node.id), node: node),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top navigation bar
// ---------------------------------------------------------------------------

class _NavBar extends StatelessWidget implements PreferredSizeWidget {
  final GameController g;
  const _NavBar({required this.g});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: Text(g.chapter.title,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.display(size: 12, color: AppColors.textDim)),
      leading: PopupMenuButton<String>(
        icon: const Icon(Icons.menu, color: AppColors.textDim),
        color: AppColors.surfaceHi,
        onSelected: (v) {
          if (v == 'chapters') _showChapters(context);
          if (v == 'restart') _confirmRestart(context);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'chapters', child: Text('Chapters')),
          PopupMenuItem(value: 'restart', child: Text('Restart story')),
        ],
      ),
      actions: [
        // VIP hook: gold pill until subscribed, then a badge.
        if (!g.isVip)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => showPaywall(context, const PaywallRequest.store()),
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: Text('VIP', style: AppTheme.display(size: 12, color: AppColors.gold)),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.workspace_premium, color: AppColors.gold),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CoinBadge(
            coins: g.coins,
            onTap: () => showPaywall(context, const PaywallRequest.store()),
          ),
        ),
      ],
    );
  }

  void _showChapters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => ChangeNotifierProvider.value(
        value: g,
        child: Consumer<GameController>(
          builder: (_, g, __) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                for (final c in g.story.chapters)
                  ListTile(
                    leading: Icon(
                      g.isChapterUnlocked(c.id) ? Icons.menu_book : Icons.lock,
                      color: g.isChapterUnlocked(c.id)
                          ? AppColors.emerald
                          : AppColors.gold,
                    ),
                    title: Text(c.title, style: AppTheme.display(size: 14)),
                    subtitle: Text(c.summary,
                        style: AppTheme.body(size: 15, color: AppColors.textDim)),
                    onTap: () async {
                      final nav = Navigator.of(sheetCtx);
                      var ok = g.isChapterUnlocked(c.id);
                      if (!ok) ok = await showPaywall(sheetCtx, PaywallRequest.chapter(c));
                      if (ok && g.enterChapter(c.id)) nav.maybePop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRestart(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restart the story?'),
        content: const Text(
            'Your path, items and stats reset. Coins, VIP and everything '
            'you unlocked are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              g.restart();
              Navigator.pop(ctx);
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One node: staggered paragraph reveal, then art / ending / choices
// ---------------------------------------------------------------------------

class _NodeView extends StatefulWidget {
  final StoryNode node;
  const _NodeView({super.key, required this.node});

  @override
  State<_NodeView> createState() => _NodeViewState();
}

class _NodeViewState extends State<_NodeView> {
  final _scroll = ScrollController();
  Timer? _timer;
  int _revealed = 1; // paragraphs currently visible

  List<String> get _paras => widget.node.paragraphs;
  bool get _done => _revealed >= _paras.length;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Reading-time based delay before the next paragraph appears.
  void _scheduleNext() {
    _timer?.cancel();
    if (_done) return;
    final ms = (900 + _paras[_revealed - 1].length * 20).clamp(1400, 5000);
    _timer = Timer(Duration(milliseconds: ms), _revealNext);
  }

  /// Also called by tapping the screen to skip the wait.
  void _revealNext() {
    if (!mounted || _done) return;
    setState(() => _revealed++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
    _scheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final node = widget.node;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealNext,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        children: [
          for (var i = 0; i < _revealed; i++) _Paragraph(_paras[i]),
          if (!_done)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text('tap to continue',
                    style: AppTheme.body(size: 14, color: AppColors.textDim, italic: true)),
              ),
            ),
          if (_done) _FadeIn(child: _Outcome(g: g, node: node)),
        ],
      ),
    );
  }
}

/// A single paragraph that fades & drifts in when first built.
class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    final isSpeech = text.startsWith('"');
    return _FadeIn(
      duration: const Duration(milliseconds: 900),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          text,
          style: AppTheme.body(
            size: 20,
            italic: isSpeech,
            color: isSpeech ? AppColors.gold : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const _FadeIn({required this.child, this.duration = const Duration(milliseconds: 700)});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOut,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
        ),
        child: child,
      );
}

// ---------------------------------------------------------------------------
// What follows the text: artwork, ending banner, choices or "continue"
// ---------------------------------------------------------------------------

class _Outcome extends StatelessWidget {
  final GameController g;
  final StoryNode node;
  const _Outcome({required this.g, required this.node});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (node.art != null) children.add(ArtCard(art: node.art!));

    final ending = node.ending;
    if (ending != null) {
      children.add(_EndingPanel(g: g, ending: ending));
    } else if (node.choices.isNotEmpty) {
      for (final c in g.visibleChoices) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChoiceButton(
            choice: c,
            locked: g.needsPayment(c),
            vip: g.isVip,
            onTap: () => _onChoice(context, c),
          ),
        ));
      }
    } else if (node.next != null) {
      children.add(_PrimaryButton(label: 'Continue', onTap: g.advance));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Future<void> _onChoice(BuildContext context, Choice c) async {
    final messenger = ScaffoldMessenger.of(context);
    var result = g.choose(c);
    if (result == ChoiceResult.needsPayment) {
      final ok = await showPaywall(context, PaywallRequest.coins(c.premium!.cost));
      if (!ok) return;
      result = g.choose(c); // retry now that the player can afford it
    }
    if (result == ChoiceResult.taken && c.isPremium && !g.isVip) {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Secret path unlocked  (-${c.premium!.cost} coins)'),
      ));
    }
  }
}

class _EndingPanel extends StatelessWidget {
  final GameController g;
  final Ending ending;
  const _EndingPanel({required this.g, required this.ending});

  @override
  Widget build(BuildContext context) {
    final color = ending.isDeath
        ? AppColors.crimson
        : ending.type == 'secret'
            ? AppColors.gold
            : AppColors.emerald;
    final next = ending.nextChapterId == null
        ? null
        : g.story.chapter(ending.nextChapterId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withAlpha(180)),
            borderRadius: BorderRadius.circular(12),
            color: color.withAlpha(24),
          ),
          child: Text(ending.title,
              textAlign: TextAlign.center,
              style: AppTheme.display(size: 15, color: color)),
        ),
        if (next != null)
          _PrimaryButton(
            label: g.isChapterUnlocked(next.id)
                ? 'Continue: ${next.title}'
                : 'Unlock: ${next.title}',
            icon: g.isChapterUnlocked(next.id) ? null : Icons.lock,
            onTap: () async {
              var ok = g.isChapterUnlocked(next.id);
              if (!ok) ok = await showPaywall(context, PaywallRequest.chapter(next));
              if (ok) g.enterChapter(next.id);
            },
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: g.restart,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDim,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(ending.isDeath ? 'TRY AGAIN' : 'REPLAY FROM START',
              style: AppTheme.display(size: 12, color: AppColors.textDim)),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.crimson,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label,
            textAlign: TextAlign.center,
            style: AppTheme.display(size: 13, color: Colors.white)),
      );
}
