import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class GameOverCrack extends StatefulWidget {
  final List<bool> cells;
  final int gridRows;
  final int gridCols;
  final int moves;
  final int par;
  final bool isHoliday;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const GameOverCrack({
    super.key,
    required this.cells,
    required this.gridRows,
    required this.gridCols,
    required this.moves,
    required this.par,
    required this.onRetry,
    required this.onExit,
    this.isHoliday = false,
  });

  @override
  State<GameOverCrack> createState() => GameOverCrackState();
}

class GameOverCrackState extends State<GameOverCrack> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _drift;
  late Animation<double> _tilt; // Fixed spelling: Animatoin -> Animation
  late Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _drift = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)));
    _tilt = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack)));
    _panelFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0, curve: Curves.easeOut))); // Fixed colon to dot
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gridWidth = size.width - 64;
    final gridHeight = gridWidth * widget.gridRows / widget.gridCols;

    // Removed the accidental closing brace here so the return statement is part of build()

    return SizedBox(
      width: size.width,
      height: gridHeight + 260,
      child: Column(
        children: [
          SizedBox(
            height: gridHeight + 40,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final drift = _drift.value;
                final tilt = _tilt.value;
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none, // Fixed spelling: clipBehaviour -> clipBehavior
                  children: [
                    Transform.translate(
                      offset: Offset(-18 * drift, -6 * drift),
                      child: Transform.rotate(
                        angle: -0.09 * tilt,
                        child: ClipPath(
                          clipper: _CrackHalfClipper(isLeft: true),
                          child: SizedBox(
                            width: gridWidth,
                            height: gridHeight,
                            child: _CrackedGrid(
                              cells: widget.cells,
                              gridRows: widget.gridRows,
                              gridCols: widget.gridCols,
                              isHoliday: widget.isHoliday,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(18 * drift, 8 * drift),
                      child: Transform.rotate(
                        angle: 0.09 * tilt,
                        child: ClipPath(
                          clipper: _CrackHalfClipper(isLeft: false),
                          child: SizedBox(
                            width: gridWidth,
                            height: gridHeight,
                            child: _CrackedGrid(
                              cells: widget.cells,
                              gridRows: widget.gridRows,
                              gridCols: widget.gridCols,
                              isHoliday: widget.isHoliday,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedBuilder( 
            animation: _panelFade,
            builder: (context, child) => Opacity( 
              opacity: _panelFade.value,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - _panelFade.value)),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'OUT OF MOVES', 
                    style: GoogleFonts.dmSans(
                      fontSize: 24, 
                      fontWeight: FontWeight.w800, 
                      color: Colors.black, 
                      letterSpacing: 1
                    ),
                  ), // Fixed parentheses and comma placement
                  const SizedBox(height: 6),
                  Text(
                    '${widget.moves} moves; more than double the par of ${widget.par}.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black45)
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onExit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFEFEF), // Fixed incomplete hex code
                              borderRadius: BorderRadius.circular(14)
                            ),
                            child: Center(
                              child: Text('Exit', style: GoogleFonts.dmSans(
                                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54))
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: widget.onRetry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C), // Fixed incomplete hex code
                              borderRadius: BorderRadius.circular(14)
                            ),
                            child: Center(
                              child: Text('Try Again', style: GoogleFonts.dmSans(
                                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ], 
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrackedGrid extends StatelessWidget {
  final List<bool> cells;
  final int gridRows;
  final int gridCols;
  final bool isHoliday;
  const _CrackedGrid({required this.cells, required this.gridRows, required this.gridCols, required this.isHoliday});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isHoliday ? const Color (0xFF0D1A0D) : const Color(0xFFE8E8E8),
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final cellW = (constraints.maxWidth - gap * (gridCols - 1)) / gridCols;
          final cellH = (constraints.maxHeight - gap * (gridRows - 1)) / gridRows;
          final cellSize = min(cellW, cellH);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(gridRows, (row) => Padding(
              padding: EdgeInsets.only(bottom: row < gridRows - 1 ? gap : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(gridCols, (col) {
                  final index = row * gridCols + col;
                  final isBlack = index < cells. length && cells[index];
                  return Padding(
                    padding: EdgeInsets.only(right: col < gridCols - 1 ? gap : 0),
                    child: Container(
                      width: cellSize, height: cellSize,
                      decoration: BoxDecoration(
                        color: isBlack ? const Color(0xFF2C2C2C) : Colors.white, 
                        borderRadius: BorderRadius.circular(cellSize * 0.2),
                      ),
                    ),
                  );
                }),
              ),
            )),
          );
        },
      ),
    );
  }
}

class _CrackHalfClipper extends CustomClipper<Path> {
  final bool isLeft;
  _CrackHalfClipper({required this.isLeft});

  @override
  Path getClip(Size size) {
    final mid = size.width / 2;
    final path = Path();
    final jags = <Offset>[
      Offset(mid, 0),
      Offset(mid - 14, size.height * 0.16),
      Offset(mid + 10, size.height * 0.30),
      Offset(mid - 18, size.height * 0.46),
      Offset(mid + 8, size.height * 0.62),
      Offset(mid - 12, size.height * 0.78),
      Offset(mid, size.height),
    ];
    if (isLeft) {
      path.moveTo(0, 0);
      for (final p in jags) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(size.width, 0);
      for (final p in jags) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(size.width, size.height);
      path.close();
    }
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}