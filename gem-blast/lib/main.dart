import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_manager.dart';
import 'home_screen.dart';
import 'storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persistent state and prime the audio engine before showing the UI.
  await Storage.instance.init();
  await AudioManager.instance.init();
  AudioManager.instance.sfxEnabled = Storage.instance.sfxEnabled;
  AudioManager.instance.musicEnabled = Storage.instance.musicEnabled;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GemBlastApp());
}

class GemBlastApp extends StatelessWidget {
  const GemBlastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gem Blast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: GameTheme.bgBottom,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
