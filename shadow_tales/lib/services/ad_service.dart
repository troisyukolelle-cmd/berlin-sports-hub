import 'dart:async';

import 'package:flutter/material.dart';

/// Rewarded-video abstraction. The UI only depends on this interface.
///
/// PRODUCTION: implement with `google_mobile_ads`:
///   RewardedAd.load(adUnitId: ..., rewardedAdLoadCallback: ...);
///   ad.show(onUserEarnedReward: (_, __) => completer.complete(true));
/// and complete with `false` if the ad is dismissed before the reward fires.
abstract class AdService {
  /// Resolves `true` only if the user earned the reward.
  Future<bool> showRewardedAd(BuildContext context);
}

/// Development stand-in: shows a fake 3-second "ad" with a countdown.
class MockAdService implements AdService {
  @override
  Future<bool> showRewardedAd(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _FakeAdDialog(),
    );
    return ok ?? false;
  }
}

class _FakeAdDialog extends StatefulWidget {
  const _FakeAdDialog();
  @override
  State<_FakeAdDialog> createState() => _FakeAdDialogState();
}

class _FakeAdDialogState extends State<_FakeAdDialog> {
  int _left = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sponsored video (mock)'),
        content: Text('Reward in $_left…'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip (no reward)'),
          ),
        ],
      );
}
