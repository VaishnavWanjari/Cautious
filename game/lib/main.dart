/// Entry point: loads all config + saved progress, wires up services, then runs
/// the app. Fully offline — no network or login is required to play.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/config_loader.dart';
import 'data/prefs_store.dart';
import 'game/audio/ambient_controller.dart';
import 'game/audio/audio_manager.dart';
import 'logic/progress.dart';
import 'ui/app_services.dart';
import 'ui/main_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final config = await GameConfig.load();
  final store = await PrefsStore.create();
  final progress = PlayerProgress(store);

  final audio = AudioManager(config.audioMap)..setSoundOn(progress.soundOn);
  final ambient = AmbientAudioController(config.audioMap)..setSoundOn(progress.soundOn);

  final services = AppServices(
    config: config,
    progress: progress,
    audio: audio,
    ambient: ambient,
  );

  runApp(ShefaliApp(services: services));
}

class ShefaliApp extends StatelessWidget {
  const ShefaliApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Prakriti Ki Rakshak: Shefali',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF7E57C2),
          scaffoldBackgroundColor: const Color(0xFF1A0E2E),
        ),
        home: const MainMenuScreen(),
      ),
    );
  }
}
