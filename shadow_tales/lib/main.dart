import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/story.dart';
import 'screens/story_screen.dart';
import 'services/ad_service.dart';
import 'services/billing_service.dart';
import 'services/storage_service.dart';
import 'state/game_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Load story content + saved progress before the first frame.
  final json = jsonDecode(
          await rootBundle.loadString('assets/stories/whisper_in_the_well.json'))
      as Map<String, dynamic>;
  final story = Story.fromJson(json);
  final storage = await StorageService.create();

  final controller = GameController(
    story: story,
    storage: storage,
    // Swap these two for real implementations (AdMob / in_app_purchase).
    ads: MockAdService(),
    billing: MockBillingService(),
  );

  runApp(
    ChangeNotifierProvider.value(value: controller, child: const ShadowTalesApp()),
  );
}

class ShadowTalesApp extends StatelessWidget {
  const ShadowTalesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shadow Tales',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const StoryScreen(),
      );
}
