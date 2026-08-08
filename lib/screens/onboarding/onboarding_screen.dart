import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/main.dart';
import 'package:folds/core/constants.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/screens/onboarding/onboarding_pages.dart';
import 'tutorial_pages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _totalPages = 7;

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _goToDaily();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  void _goToDaily() {
    AppStore.hasSeenOnboarding = true;
    final dayNumber = foldsDayNumberFor(DateTime.now());
    final dailyId = dayNumber > 0 ? 'd$dayNumber' : 'p1';
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: dailyId),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _totalPages - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  OnboardPage1(),         // 0: Welcome
                  OnboardPageSixSM(),     // 1: The 6SM menu
                  OnboardPage2(),         // 2: What is symmetry
                  OnboardTutorial1(),     // 3: 1-move puzzle
                  OnboardTutorial2(),     // 4: 2-move puzzle
                  OnboardTutorial3(),     // 5: 3-move puzzle
                  OnboardPageFinal(),     // 6: Par + XP + ready
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i ? const Color(0xFF2C2C2C) : const Color(0xFFD6D6D6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    GestureDetector(
                      onTap: _back,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(16)),
                        child: Text('Back', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: _next,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isLast ? const Color(0xFF4CAF50) : const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            isLast ? '🧩 Play Today\'s Daily!' : 'Next',
                            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

