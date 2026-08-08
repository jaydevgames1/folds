import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:folds/state/app_store.dart';
import 'puzzle_selector_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLE SIZE CARD (used by PilotPackDetailScreen)
// ─────────────────────────────────────────────────────────────────────────────
class PuzzleSizeCard extends StatelessWidget {
  final String label;
  final String puzzleCount;
  final int completed;
  final int total;
  final int gridSize;
  final VoidCallback onPlay;
  final VoidCallback onHome;

  const PuzzleSizeCard({
    super.key,
    required this.label,
    required this.puzzleCount,
    required this.completed,
    required this.total,
    required this.gridSize,
    required this.onPlay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    final pct = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelSize = constraints.maxHeight;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                          style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(puzzleCount,
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54)),
                      ],
                    ),
                    Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(color: const Color(0xFFd9d9d9), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              if (pct > 0)
                                Expanded(
                                  flex: pct,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD465),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              Expanded(flex: 100 - pct, child: const SizedBox()),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Text('$pct%',
                              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onPlay,
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: onHome,
                          child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              PreviewGridPanel(gridSize: gridSize, size: panelSize),
            ],
          );
        },
      ),
    );
  }
}

class PreviewGridPanel extends StatelessWidget {
  final int gridSize;
  final double size;
  const PreviewGridPanel({super.key, required this.gridSize, required this.size});

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    final cellSize = (size - 16 - gap * (gridSize - 1)) / gridSize;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFd9d9d9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(gridSize, (row) => Padding(
          padding: EdgeInsets.only(bottom: row < gridSize - 1 ? gap : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(gridSize, (col) => Padding(
              padding: EdgeInsets.only(right: col < gridSize - 1 ? gap : 0),
              child: Container(
                width: cellSize, height: cellSize,
                decoration: BoxDecoration(
                  color: (row + col) % 2 == 0 ? Colors.white : const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(cellSize * 0.22),
                ),
              ),
            )),
          ),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6SM MENU CARD (used by GameplayScreen's overlay menu)
// ─────────────────────────────────────────────────────────────────────────────
class SixSMCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const SixSMCard({super.key, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 160,
          decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Center(child: Icon(icon, size: 56, color: const Color(0xFF555555))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLES MENU PACK CARD (Pilot / Rectangle)
// ─────────────────────────────────────────────────────────────────────────────
enum PackShapeType { square, rectangle, circle, hexagon }

class MenuPackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int completedPuzzles;
  final int totalPuzzles;
  final PackShapeType shapeType;
  final VoidCallback onPlay;
  final VoidCallback onHome;

  const MenuPackCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.completedPuzzles,
    required this.totalPuzzles,
    required this.shapeType,
    required this.onPlay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPuzzles > 0 ? completedPuzzles / totalPuzzles : 0.0;
    final pct = (progress * 100).toInt();

    final int gridCols = shapeType == PackShapeType.rectangle ? 2 : 2;
    final int gridRows = shapeType == PackShapeType.rectangle ? 3 : 2;

    Widget gridPreview = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(gridRows, (row) => Padding(
          padding: EdgeInsets.only(bottom: row < gridRows - 1 ? 6 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(gridCols, (col) => Padding(
              padding: EdgeInsets.only(right: col < gridCols - 1 ? 6 : 0),
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: (row + col) % 2 == 0 ? Colors.white : const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )),
          ),
        )),
      ),
    );

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  gridPreview,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Stack(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      if (pct > 0)
                        Expanded(
                          flex: pct,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD465),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      Expanded(flex: 100 - pct, child: const SizedBox()),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Text('$pct%',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(child: IconButton(icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28), onPressed: onPlay)),
                Container(width: 1, height: 24, color: const Color(0xFF333333)),
                Expanded(child: IconButton(icon: const Icon(Icons.home_rounded, color: Colors.white, size: 24), onPressed: onHome)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOLIDAY PACK BANNER
// ─────────────────────────────────────────────────────────────────────────────
class HolidayPackBanner extends StatelessWidget {
  const HolidayPackBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final unlockDate = DateTime(2026, 06, 10);
    final now = DateTime.now();
    final isUnlocked = !now.isBefore(unlockDate);
    final daysLeft = unlockDate.difference(now).inDays + 1;
    final done = AppStore.completedInRange('x', 0, 25);

    if (isUnlocked) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PuzzleSelectorScreen(
            packName: 'Holiday', totalPuzzles: 25, idPrefix: 'x', idOffset: 0),
        )),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a472a), Color(0xFF2d6a2f)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🎄', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOLIDAY PACK', style: GoogleFonts.dmSans(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('25 festive puzzles', style: GoogleFonts.dmSans(
                      fontSize: 13, color: Colors.white60)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: done / 25,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD465)),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$done / 25 completed', style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Text('🎄', style: TextStyle(fontSize: 28, color: Colors.black.withValues(alpha: 0.25))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOLIDAY PACK', style: GoogleFonts.dmSans(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black38)),
                Text('Unlocks December 10, 2026', style: GoogleFonts.dmSans(
                  fontSize: 13, color: Colors.black38)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$daysLeft', style: GoogleFonts.dmSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              Text('days', style: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
            ]),
          ),
        ],
      ),
    );
  }
}