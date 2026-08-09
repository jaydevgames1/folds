import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import 'dart:math';


class FoldCompleteAnimator extends StatefulWidget {
  final String puzzleId;
  final String puzzleTitle;
  final String puzzleShareNumber;
  final String packPath;
  final String timeDisplay;
  final int moves;
  final int par;
  final int earnedXP;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final List<bool> cells;
  final bool skipAnimation;
  final bool isHoliday;
  final int gridRows;
  final int gridCols;

  const FoldCompleteAnimator({
    super.key,
    required this.puzzleId,
    required this.puzzleTitle,
    required this.puzzleShareNumber,
    required this.packPath,
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.earnedXP,
    required this.onRetry,
    this.onNext,
    required this.cells,
    this.skipAnimation = false,
    this.isHoliday = false,
    this.gridRows = 4,
    this.gridCols = 4,
  });
  @override
  State<FoldCompleteAnimator> createState() => FoldCompleteAnimatorState();
}

class FoldCompleteAnimatorState extends State<FoldCompleteAnimator>
    with TickerProviderStateMixin {
  // Stage 0: fold left half onto right half, in place (no sliding)
  late AnimationController _foldCtrl;
  // Stage 1: rotate the now-folded card 90° into landscape
  late AnimationController _turnCtrl;
  // Stage 2: stamp pops onto the rotated card
  late AnimationController _stampCtrl;
  // Stage 3: stats/buttons fade in below
  late AnimationController _statsCtrl;

  late Animation<double> _foldAngle;
  late Animation<double> _turnAngle;
  late Animation<double> _stampScale;
  late Animation<double> _statsFade;

  int _stage = 0; // 0=folding 1=turning 2=stamp 3=stats

  bool get _isUnderPar => widget.moves <= widget.par;

  @override
  void initState() {
    super.initState();
    _foldCtrl = AnimationController(duration: const Duration(milliseconds: 750), vsync: this);
    _turnCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _stampCtrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _statsCtrl = AnimationController(duration: const Duration(milliseconds: 450), vsync: this);

    _foldAngle = Tween<double>(begin: 0, end: pi / 2)
        .animate(CurvedAnimation(parent: _foldCtrl, curve: Curves.easeInCubic));
    _turnAngle = Tween<double>(begin: 0, end: pi / 2)
        .animate(CurvedAnimation(parent: _turnCtrl, curve: Curves.easeInOutCubic));
    _stampScale = Tween<double>(begin: 2.5, end: 1.0)
        .animate(CurvedAnimation(parent: _stampCtrl, curve: Curves.elasticOut));
    _statsFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut));

    if (widget.skipAnimation) {
      _foldCtrl.value = 1;
      _turnCtrl.value = 1;
      _stampCtrl.value = 1;
      _stage = 3;
    }
    _runSequence();
  }

  Future<void> _runSequence() async {
    if (widget.skipAnimation) {
      await _statsCtrl.forward();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _foldCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _stage = 1);
    await _turnCtrl.forward();
    setState(() => _stage = 2);
    await _stampCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _stage = 3);
    await _statsCtrl.forward();
  }

  @override
  void dispose() {
    _foldCtrl.dispose();
    _turnCtrl.dispose();
    _stampCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  String get _shareText {
    final cleanTime = widget.timeDisplay.split('.').first;
    return 'Folds\n#${widget.puzzleShareNumber} ${widget.puzzleTitle}\n$cleanTime ⏳, 0 💡, ${widget.moves}/${widget.par} ➡️\nhttps://folds.jaydev.games/puzzles/${widget.packPath}/${widget.puzzleShareNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Preserve the puzzle's real aspect ratio — this is what makes it work
    // for 4x4, 6x6, 8x8, AND rectangular (rows≠cols) puzzles.
    final gridWidth = size.width - 32;
    final gridHeight = gridWidth * widget.gridRows / widget.gridCols;

    final leftCols = widget.gridCols ~/ 2;
    final rightCols = widget.gridCols - leftCols;
    final foldedWidth = gridWidth * rightCols / widget.gridCols;

    // Big enough square to hold the card at any rotation without clipping
    final boundSize = math.max(foldedWidth, gridHeight);

    return SizedBox(
      width: size.width,
      height: boundSize + 240,
      child: Column(
        children: [
          SizedBox(
            height: boundSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── Stage 0: fold left onto right, on the spot ──────────
                if (_stage == 0)
                  AnimatedBuilder(
                    animation: _foldCtrl,
                    builder: (context, child) => SizedBox(
                      width: gridWidth,
                      height: gridHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: 0, top: 0,
                            width: foldedWidth, height: gridHeight,
                            child: GridHalf(
                              cells: widget.cells, isLeft: false,
                              gridRows: widget.gridRows, gridCols: widget.gridCols,
                              isHoliday: widget.isHoliday,
                            ),
                          ),
                          Positioned(
                            left: 0, top: 0,
                            width: gridWidth - foldedWidth, height: gridHeight,
                            child: Transform(
                              alignment: Alignment.centerRight,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(_foldAngle.value),
                              child: GridHalf(
                                cells: widget.cells, isLeft: true,
                                gridRows: widget.gridRows, gridCols: widget.gridCols,
                                isHoliday: widget.isHoliday,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Stage 1+: folded card turning into landscape ────────
                if (_stage >= 1)
                  AnimatedBuilder(
                    animation: Listenable.merge([_turnCtrl, _stampCtrl]),
                    builder: (context, child) {
                      final angle = _stage == 1 ? _turnAngle.value : pi / 2;
                      return Transform.rotate(
                        angle: angle,
                        child: Container(
                          width: foldedWidth,
                          height: gridHeight,
                          decoration: BoxDecoration(
                            color: widget.isHoliday ? const Color(0xFF0D1A0D) : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16, offset: const Offset(0, 8))],
                          ),
                          child: _stage >= 2
                              ? Transform.rotate(
                                  // keep the stamp upright once the card itself is landscape
                                  angle: -pi / 2,
                                  child: SizedBox(
                                    width: gridHeight,
                                    height: foldedWidth,
                                    child: Center(
                                      child: Transform.scale(
                                        scale: _stampScale.value.clamp(0.0, 10.0),
                                        child: StampWidget(isGold: _isUnderPar),
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // ── Stats + buttons, always upright underneath the card ─────
          if (_stage >= 3)
            AnimatedBuilder(
              animation: _statsCtrl,
              builder: (context, child) => Opacity(
                opacity: _statsFade.value,
                child: StatsCard(
                  timeDisplay: widget.timeDisplay,
                  moves: widget.moves,
                  par: widget.par,
                  earnedXP: widget.earnedXP,
                  isUnderPar: _isUnderPar,
                  shareText: _shareText,
                  onRetry: widget.onRetry,
                  onNext: widget.onNext,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GridHalf extends StatelessWidget {
  final List<bool> cells;
  final bool isLeft;
  final int gridRows;
  final int gridCols;
  final bool isHoliday;

  const GridHalf({
    required this.cells,
    required this.isLeft,
    required this.gridRows,
    required this.gridCols,
    this.isHoliday = false,
  });

  @override
  Widget build(BuildContext context) {
    final leftCols = gridCols ~/ 2;
    final halfCols = isLeft ? leftCols : gridCols - leftCols;
    final startCol = isLeft ? 0 : leftCols;
    const gap = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - gap * (halfCols - 1) - 16) / halfCols;
        final cellH = constraints.maxHeight > 0
            ? (constraints.maxHeight - gap * (gridRows - 1) - 16) / gridRows
            : cellW;
        final cellSize = min(cellW, cellH);

        return Container(
          color: isHoliday ? const Color(0xFF0D1A0D) : const Color(0xFFE8E8E8),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(gridRows, (row) {
              return Padding(
                padding: EdgeInsets.only(bottom: row < gridRows - 1 ? gap : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(halfCols, (colIdx) {
                    final col = startCol + colIdx;
                    final index = row * gridCols + col;
                    final isBlack = index < cells.length && cells[index];
                    return Padding(
                      padding: EdgeInsets.only(right: colIdx < halfCols - 1 ? gap : 0),
                      child: Container(
                        width: cellSize, height: cellSize,
                        decoration: BoxDecoration(
                          color: isBlack
                              ? (isHoliday ? const Color(0xFF8B0000) : const Color(0xFF2C2C2C))
                              : (isHoliday ? const Color(0xFF1B5E20) : Colors.white),
                          borderRadius: BorderRadius.circular(cellSize * 0.22),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}


// ── Stamp widget ──────────────────────────────────────────────────────────────
class StampWidget extends StatelessWidget {
  final bool isGold;
  const StampWidget({required this.isGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isGold ? const Color(0xFFFFD465) : const Color(0xFFBBBBBB),
        boxShadow: [
          BoxShadow(
            color: (isGold ? const Color(0xFFFFD465) : const Color(0xFFBBBBBB)).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isGold ? '★' : '✦',
              style: TextStyle(
                fontSize: 28,
                color: isGold ? Colors.black : Colors.white,
              ),
            ),
            Text(
              isGold ? 'PAR' : 'SOLVED',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isGold ? Colors.black : Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────
class StatsCard extends StatelessWidget {
  final String timeDisplay;
  final int moves;
  final int par;
  final bool isUnderPar;
  final String shareText;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final int earnedXP;

  const StatsCard({
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.isUnderPar,
    required this.shareText,
    required this.onRetry,
    this.onNext,
    required this.earnedXP,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatItem(emoji: '⏳', value: timeDisplay),
                StatItem(emoji: '💡', value: '0'),
                StatItem(emoji: '➡️', value: '$moves/$par'),
                XPCountUp(target: earnedXP),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Share button
          
                    // Share button
          Builder(
            builder: (context) {
              return GestureDetector(
                onTap: () {
                  // Find the visual render boundary of this button
                  final RenderBox? box = context.findRenderObject() as RenderBox?;
                  
                  // Construct a non-zero origin box for iOS share sheet popovers
                  final Rect? sharePositionOrigin = box != null 
                      ? box.localToGlobal(Offset.zero) & box.size 
                      : null;

                  Share.share(
                    shareText, 
                    subject: 'Folds',
                    sharePositionOrigin: sharePositionOrigin,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Share Fold',
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Copy + Retry row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Copied to clipboard',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF2C2C2C),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('Copy',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('Retry',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                ),
              ),
              if (onNext != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text('Next →',
                          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String emoji;
  final String value;
  const StatItem({required this.emoji, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
      ],
    );
  }
}

class XPCountUp extends StatefulWidget {
  final int target;
  const XPCountUp({required this.target});
  @override
  State<XPCountUp> createState() => XPCountUpState();
}


class XPCountUpState extends State<XPCountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: Duration(milliseconds: (widget.target * 18).clamp(600, 1800)),
      vsync: this,
    );
    _anim = IntTween(begin: 0, end: widget.target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    // Delay to let the stats card finish sliding in
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('+${_anim.value} XP',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
        ],
      ),
    );
  }
}
