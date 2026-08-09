import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Shared interactive tutorial widget
class TutorialGrid extends StatefulWidget {
  final List<bool> initialCells;
  final String hintText;
  final String successText;
  final VoidCallback? onSolved;

  const TutorialGrid({
    super.key,
    required this.initialCells,
    required this.hintText,
    required this.successText,
    this.onSolved,
  });

  @override
  State<TutorialGrid> createState() => TutorialGridState();
}

class TutorialGridState extends State<TutorialGrid> {
  late List<bool> _cells;
  bool _solved = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _cells = List.from(widget.initialCells);
  }

  bool _isSolved() {
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        if (_cells[row * 4 + col] != _cells[row * 4 + (3 - col)]) return false;
      }
    }
    return true;
  }

  double get _progress {
    int matched = 0;
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        if (_cells[row * 4 + col] == _cells[row * 4 + (3 - col)]) matched++;
      }
    }
    return matched / 8;
  }

  void _tap(int index) {
    if (_solved) return;
    setState(() {
      _cells[index] = !_cells[index];
      _moves++;
      if (_isSolved()) {
        _solved = true;
        widget.onSolved?.call();
      }
    });
  }

  void _reset() => setState(() {
    _cells = List.from(widget.initialCells);
    _solved = false;
    _moves = 0;
  });

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    const cellSize = 56.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _solved ? const Color(0xFFE8F5E9) : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(18),
            border: _solved ? Border.all(color: const Color(0xFF4CAF50), width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (row) => Padding(
              padding: EdgeInsets.only(bottom: row < 3 ? gap : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (col) {
                  final i = row * 4 + col;
                  return Padding(
                    padding: EdgeInsets.only(right: col < 3 ? gap : 0),
                    child: GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: cellSize, height: cellSize,
                        decoration: BoxDecoration(
                          color: _cells[i] ? const Color(0xFF2C2C2C) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: const Color(0xFFE8E8E8),
            valueColor: AlwaysStoppedAnimation<Color>(
              _solved ? const Color(0xFF4CAF50) : const Color(0xFFFFD465)),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _solved
              ? Column(key: const ValueKey('s'), children: [
                  Text(widget.successText, textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800,
                      color: const Color(0xFF4CAF50))),
                  const SizedBox(height: 4),
                  Text('$_moves move${_moves == 1 ? '' : 's'} used',
                    style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                  const SizedBox(height: 8),
                  GestureDetector(onTap: _reset,
                    child: Text('Try again', style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38,
                      decoration: TextDecoration.underline))),
                ])
              : Column(key: const ValueKey('h'), children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFFD465)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(widget.hintText, textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54))),
                  ]),
                  const SizedBox(height: 4),
                  Text('Moves: $_moves', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black26)),
                ]),
        ),
      ],
    );
  }
}

class TutorialPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget grid;

  const TutorialPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 24),
          grid,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class OnboardTutorial1 extends StatelessWidget {
  const OnboardTutorial1({super.key});

  @override
  Widget build(BuildContext context) {
    return TutorialPageShell(
      title: 'Your First Fold',
      subtitle: 'Every row must mirror itself left to right. One cell is out of place — find it.',
      grid: const TutorialGrid(
        initialCells: [
          false, false, false, true,
          false, false, false, false,
          false, false, false, false,
          false, false, false, false,
        ],
        hintText: 'Look at the top row — one corner doesn\'t match its pair. Tap the top-left cell.',
        successText: '✓ Perfectly symmetrical!',
      ),
    );
  }
}

class OnboardTutorial2 extends StatelessWidget {
  const OnboardTutorial2({super.key});

  @override
  Widget build(BuildContext context) {
    return TutorialPageShell(
      title: 'Two to Fix',
      subtitle: 'Now two rows are unbalanced. Fix both to solve the puzzle.',
      grid: const TutorialGrid(
        initialCells: [
          true,  false, false, false,
          false, false, false, false,
          false, false, false, false,
          false, false, false, true,
        ],
        hintText: 'Top row and bottom row each have a mismatch. Tap the odd corner in each.',
        successText: '✓ Both rows balanced!',
      ),
    );
  }
}

class OnboardTutorial3 extends StatelessWidget {
  const OnboardTutorial3({super.key});

  @override
  Widget build(BuildContext context) {
    return TutorialPageShell(
      title: 'Think it Through',
      subtitle: 'Three rows need balancing. Check each row left-to-right.',
      grid: const TutorialGrid(
        initialCells: [
          true,  false, false, false,
          false, false, true,  false,
          false, false, false, true,
          false, false, false, false,
        ],
        hintText: 'Each of the first three rows has exactly one mismatched pair. Fix one row at a time.',
        successText: '✓ You\'re ready to Fold!',
      ),
    );
  }
}