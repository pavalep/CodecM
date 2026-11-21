import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/persistent_storage.dart';
import 'core/services/on_device_ai_engine.dart';
import 'features/player/presentation/bloc/player_bloc.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Persistent local storage for bookmarks, recent history, following
  try {
    await PersistentStorage.instance.initialize();
  } catch (e) {
    debugPrint('PersistentStorage initialization error: $e');
  }

  // Initialize On-Device Gemma 2B LiteRT AI Engine
  try {
    await OnDeviceAiEngine.instance.initialize();
  } catch (e) {
    debugPrint('OnDeviceAiEngine initialization error: $e');
  }

  // Initialize Android media playback notification service
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.app.codecm.channel.audio',
      androidNotificationChannelName: 'CodecM Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (_) {
    // If running in test or headless environment
  }

  // Set system UI styling for clean luxury light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CodecMApp());
}

class CodecMApp extends StatelessWidget {
  const CodecMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlayerBloc>(
      create: (context) => PlayerBloc(),
      child: MaterialApp(
        title: 'CodecM — Luxury Audio & Media Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
