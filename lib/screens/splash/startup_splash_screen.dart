// lib/screens/splash/startup_splash_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StartupSplashScreen extends StatefulWidget {
  final Widget next;
  const StartupSplashScreen({super.key, required this.next});
  @override
  State<StartupSplashScreen> createState() => StartupSplashScreenState();
}

class StartupSplashScreenState extends State<StartupSplashScreen> with TickerProviderStateMixin {
  // Entrance (fades/scales the mark in)
  late final AnimationController _entrance =
      AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..forward();

  // Continuous "alive" loop for the mark — runs for the whole 5s dwell.
  late final AnimationController _loop =
      AnimationController(duration: const Duration(milliseconds: 2200), vsync: this)..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    // Shown only on a cold launch (FoldsApp decides that) — always the full
    // 5 seconds so the brand actually registers, even if data loads instantly.
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 450),
      ));
    });
  }

  @override
  void dispose() { _entrance.dispose(); _loop.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_entrance, _loop]),
          builder: (_, __) {
            final entrance = Curves.easeOut.transform(_entrance.value);
            // Slow breathing rotation + scale — reads as "alive" without a
            // video/gif asset. Swap this whole builder for a Rive/Lottie
            // widget later if you want a hand-authored animated mark; see
            // note below.
            final breathe = Curves.easeInOut.transform(_loop.value); // 0..1..0
            final scale = (0.85 + 0.15 * Curves.easeOutBack.transform(entrance)) *
                (1.0 + 0.04 * breathe);
            final rotation = (breathe - 0.5) * 0.06; // gentle rock, ~±3.4°
            return Opacity(
              opacity: entrance,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TODO: swap Image.asset for a Rive/Lottie animation for a
                      // real hand-authored motion mark (recommended over gif/mp4 —
                      // both are heavier and Flutter has no native video-as-logo
                      // widget without extra plugins + buffering). Packages:
                      // `rive` (rive.app) or `lottie` (bodymovin/After Effects export).
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFFFD465).withValues(alpha: 0.25 + 0.15 * breathe),
                            blurRadius: 30, spreadRadius: 4)],
                        ),
                        child: Image.asset('assets/jaydev_mark.png', width: 96, height: 96),
                      ),
                      const SizedBox(height: 18),
                      Text('JAYDEV GAMES', style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 3)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
