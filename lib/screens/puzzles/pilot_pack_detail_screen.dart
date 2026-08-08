import 'package:flutter/material.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/screens/gameplay_screen.dart';
import 'package:folds/main.dart';
import 'pack_cards.dart';
import 'package:folds/widgets/shared/buttons.dart';
import 'puzzle_selector_screen.dart';


class PilotPackDetailScreen extends StatelessWidget {
  const PilotPackDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Read live from AppStore
    final done4x4 = AppStore.completedInRange('p', 0, 50);
    final done6x6 = AppStore.completedInRange('p', 50, 30);
    final done8x8 = AppStore.completedInRange('p', 80, 20);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'PILOT PACK', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PuzzleSizeCard(
                        label: '4x4',
                        puzzleCount: '50 PUZZLES',
                        completed: done4x4,
                        total: 50,
                        gridSize: 4,
                        onPlay: () {
                          String targetId = 'p1';
                          for (int i = 1; i <= 50; i++) {
                            if (!AppStore.isCompleted('p$i')) {
                              targetId = 'p$i';
                              break;
                            }
                          }
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        onHome: () => pushFade(context, const PuzzleSelectorScreen(
                          packName: '4x4', totalPuzzles: 50, idPrefix: 'p', idOffset: 0)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: PuzzleSizeCard(
                        label: '6x6',
                        puzzleCount: '30 PUZZLES',
                        completed: done6x6,
                        total: 30,
                        gridSize: 6,
                        onPlay: () {
                          String targetId = 'p51';
                          for (int i = 51; i <= 80; i++) {
                            if (!AppStore.isCompleted('p$i')) {
                              targetId = 'p$i';
                              break;
                            }
                          }
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        onHome: () => pushFade(context, const PuzzleSelectorScreen(
                          packName: '6x6', totalPuzzles: 30, idPrefix: 'p', idOffset: 50)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: PuzzleSizeCard(
                        label: '8x8',
                        puzzleCount: '20 PUZZLES',
                        completed: done8x8,
                        total: 20,
                        gridSize: 8,
                        onPlay: () {
                          String targetId = 'p81';
                          for (int i = 81; i <= 100; i++) {
                            if (!AppStore.isCompleted('p$i')) {
                              targetId = 'p$i';
                              break;
                            }
                          }
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        onHome: () => pushFade(context, const PuzzleSelectorScreen(
                          packName: '8x8', totalPuzzles: 20, idPrefix: 'p', idOffset: 80)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomBackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

