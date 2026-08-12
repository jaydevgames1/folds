import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'state/app_store.dart';
import 'services/audio_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/splash/startup_splash_screen.dart';
import 'package:folds/widgets/shared/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Supabase.initialize(
    url: 'https://kvihtmzgthznjtwqtbvg.supabase.co',
    publishableKey: 'sb_publishable_hznxJ0hZwXRvO-KHZuoYag_RXPDWfWI',
  );
  await AppStore.init();
  await AudioService.init();
  runApp(const FoldsApp());
}

class FoldsApp extends StatefulWidget {
  const FoldsApp({super.key});
  @override
  State<FoldsApp> createState() => FoldsAppState();
}

class FoldsAppState extends State<FoldsApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  static const _threshold = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _backgroundedAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final home = AppStore.hasSeenOnboarding ? const GameplayScreen() : const OnboardingScreen();
    final showSplash = _backgroundedAt == null || DateTime.now().difference(_backgroundedAt!) > _threshold;
    return MaterialApp(
      title: 'Folds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      builder: (context, child) => OfflineBannerListener(child: child!),
      home: showSplash ? StartupSplashScreen(next: home) : home,
    );
  }
}

void pushFade(BuildContext context, Widget screen) {
  Navigator.push(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fade = Tween<double>(begin: 0.0, end: 1.0)
          .animate(CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.5)));
      return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
    },
    transitionDuration: const Duration(milliseconds: 320),
  ));
}

Future<void> launchCustomUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}