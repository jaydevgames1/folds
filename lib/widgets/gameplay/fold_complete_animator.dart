import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

class FoldCompleteAnimator extends StatefulWidget {
  final double maxWidth;
  final double maxHeight;
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
  final bool hideXP;

  const FoldCompleteAnimator({
    super.key,
    required this.maxWidth,
    required this.maxHeight,
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
    this.hideXP = false,
  });
  @override
  State<FoldCompleteAnimator> createState() => FoldCompleteAnimatorState();
}

class FoldCompleteAnimatorState extends State<FoldCompleteAnimator> with TickerProviderStateMixin {
  // Stage 0: lift  |  Stage 1: fold in half  |  Stage 2: turn 90° (flat spin)  |  Stage 3: stamp  |  Stage 4: stats
  late final AnimationController _liftCtrl  = AnimationController(duration: const Duration(milliseconds: 260), vsync: this);
  late final AnimationController _foldCtrl  = AnimationController(duration: const Duration(milliseconds: 480), vsync: this);
  late final AnimationController _turnCtrl  = AnimationController(duration: const Duration(milliseconds: 480), vsync: this);
  late final AnimationController _stampCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
  late final AnimationController _statsCtrl = AnimationController(duration: const Duration(milliseconds: 380), vsync: this);

  int _stage = 0;
  bool get _isUnderPar => widget.moves <= widget.par;

  static const _grey = Color(0xFFE8E8E8);
  static const _greyHoliday = Color(0xFF0D1A0D);
  static const _dark = Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    if (widget.skipAnimation) {
      _liftCtrl.value = _foldCtrl.value = _turnCtrl.value = _stampCtrl.value = 1;
      _stage = 4;
    }
    _run();
  }

  Future<void> _run() async {
    if (widget.skipAnimation) { await _statsCtrl.forward(); return; }
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _liftCtrl.forward();  if (!mounted) return; setState(() => _stage = 1);
    await _foldCtrl.forward();  if (!mounted) return; setState(() => _stage = 2);
    await _turnCtrl.forward();  if (!mounted) return; setState(() => _stage = 3);
    await _stampCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _stage = 4);
    await _statsCtrl.forward();
  }

  @override
  void dispose() {
    _liftCtrl.dispose(); _foldCtrl.dispose(); _turnCtrl.dispose();
    _stampCtrl.dispose(); _statsCtrl.dispose();
    super.dispose();
  }

  String get _shareText {
    final cleanTime = widget.timeDisplay.split('.').first;
    return 'Folds\n#${widget.puzzleShareNumber} ${widget.puzzleTitle}\n$cleanTime, ${widget.moves}/${widget.par}\nhttps://folds.jaydev.games/puzzles/${widget.packPath}/${widget.puzzleShareNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final startWidth = math.min(widget.maxWidth - 16, widget.gridCols * 90.0).clamp(120.0, widget.maxWidth);
    final startHeight = startWidth * widget.gridRows / widget.gridCols;
    final rightCols = widget.gridCols - (widget.gridCols ~/ 2);
    final foldedWidth = startWidth * rightCols / widget.gridCols;
    final finalWidth = math.min(widget.maxWidth - 24, 300.0);
    final finalHeight = finalWidth / 2; // fixed 2:1 landscape card
    final stageHeight = math.max(startHeight, finalHeight) + 34;
    final panel = widget.isHoliday ? _greyHoliday : _grey;
    final card = widget.isHoliday ? _greyHoliday : _dark;

    return SizedBox(
      width: widget.maxWidth,
      child: Column(children: [
        SizedBox(
          height: stageHeight,
          child: Center(
            child: ClipRect(
              clipBehavior: Clip.none,
              child: OverflowBox(
                maxWidth: widget.maxWidth * 1.4,
                maxHeight: stageHeight * 1.4,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_liftCtrl, _foldCtrl, _turnCtrl, _stampCtrl]),
                  builder: (context, _) {
                    // ── Stage 0: lift — grey panel rises + fades in.
                    if (_stage == 0) {
                      final lift = Curves.easeOut.transform(_liftCtrl.value) * 18;
                      return Transform.translate(
                        offset: Offset(0, -lift),
                        child: Opacity(
                          opacity: _liftCtrl.value,
                          child: Container(width: startWidth, height: startHeight,
                            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16))),
                        ),
                      );
                    }
                    // ── Stage 1: fold — grey book-fold in place.
                    if (_stage == 1) {
                      final t = Curves.easeInCubic.transform(_foldCtrl.value);
                      return Transform.translate(
                        offset: const Offset(0, -18),
                        child: SizedBox(width: startWidth, height: startHeight,
                          child: Stack(clipBehavior: Clip.none, children: [
                            Positioned(right: 0, top: 0, width: foldedWidth, height: startHeight,
                              child: DecoratedBox(decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)))),
                            Positioned(left: 0, top: 0, width: startWidth - foldedWidth, height: startHeight,
                              child: Transform(
                                alignment: Alignment.centerRight,
                                transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(t * (math.pi / 2)),
                                child: DecoratedBox(decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16))),
                              )),
                          ]),
                        ),
                      );
                    }
                    // ── Stage 2/3: FLAT (Z-axis) spin — never edge-on, never vanishes.
                    // Also morphs size portrait→landscape and darkens to the solved colour.
                    final tt = _turnCtrl.value.clamp(0.0, 1.0);
                    final eased = Curves.easeInOutCubic.transform(tt);
                    final angle = eased * (math.pi / 2); // quarter turn, flat in the screen plane

                    final w = lerpDouble(foldedWidth, finalWidth, eased)!;
                    final h = lerpDouble(startHeight, finalHeight, eased)!;
                    final colorT = ((tt - 0.6) / 0.4).clamp(0.0, 1.0);
                    final color = Color.lerp(panel, card, colorT)!;

                    return Transform.translate(
                      offset: const Offset(0, -18),
                      child: Transform.rotate(
                        angle: angle, // Z-axis — a flat, in-plane spin
                        child: Container(
                          width: w, height: h,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 8))]),
                          child: _stage >= 3 ? Center(
                            child: Transform.rotate(
                              angle: -angle, // counter-rotate the stamp so it stays upright
                              child: Transform.scale(
                                scale: Curves.elasticOut.transform(_stampCtrl.value).clamp(0.0, 10.0),
                                child: StampWidget(isGold: _isUnderPar),
                              ),
                            ),
                          ) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (_stage >= 4)
          AnimatedBuilder(
            animation: _statsCtrl,
            builder: (_, child) => Opacity(opacity: _statsCtrl.value,
              child: Transform.translate(offset: Offset(0, 10 * (1 - _statsCtrl.value)), child: child)),
            child: StatsCard(
              timeDisplay: widget.timeDisplay,
              moves: widget.moves,
              par: widget.par,
              earnedXP: widget.earnedXP,
              hideXP: widget.hideXP,
              isUnderPar: _isUnderPar,
              shareText: _shareText,
              onRetry: widget.onRetry,
              onNext: widget.onNext,
            ),
          ),
      ]),
    );
  }
}

// ── Stamp widget ──────────────────────────────────────────────────────────────
class StampWidget extends StatefulWidget {
  final bool isGold;
  const StampWidget({required this.isGold});
  @override
  State<StampWidget> createState() => StampWidgetState();
}

class StampWidgetState extends State<StampWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isGold ? const Color(0xFFFFD465) : const Color(0xFFBBBBBB);
    return SizedBox(
      width: 110, height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (context, child) {
              final t = _ringCtrl.value;
              return Opacity(
                opacity: (1 - t).clamp(0.0, 0.35),
                child: Transform.scale(
                  scale: 0.85 + t * 0.5,
                  child: Container(
                    width: 78, height: 78,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 2)),
                  ),
                ),
              );
            },
          ),
          if (widget.isGold) ...List.generate(6, (i) {
            final angle = (i / 6) * 2 * math.pi;
            return Transform.translate(
              offset: Offset(42 * math.cos(angle), 42 * math.sin(angle)),
              child: Icon(Icons.star_rounded, size: 8 + (i % 3) * 3.0, color: accent.withValues(alpha: 0.7)),
            );
          }),
          Container(
            width: 78, height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 2)],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.isGold ? Icons.star_rounded : Icons.check_rounded,
                    size: 24, color: widget.isGold ? Colors.black : Colors.white),
                  Text(widget.isGold ? 'PAR' : 'SOLVED',
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800,
                      color: widget.isGold ? Colors.black : Colors.white, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
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
  final bool hideXP;

  const StatsCard({
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.isUnderPar,
    required this.shareText,
    required this.onRetry,
    this.onNext,
    required this.earnedXP,
    this.hideXP = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatItem(icon: Icons.timer_outlined, value: timeDisplay),
                StatItem(icon: Icons.lightbulb_outline_rounded, value: '0'),
                StatItem(icon: Icons.arrow_forward_rounded, value: '$moves/$par'),
                if (!hideXP) XPCountUp(target: earnedXP),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              return GestureDetector(
                onTap: () {
                  final RenderBox? box = context.findRenderObject() as RenderBox?;
                  final Rect? sharePositionOrigin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                  Share.share(shareText, subject: 'Folds', sharePositionOrigin: sharePositionOrigin);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.ios_share_rounded, color: Colors.white, size: 17),
                        const SizedBox(width: 8),
                        Text('Share Fold', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Copied to clipboard', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF2C2C2C),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('Copy', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
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
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Next', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                          ],
                        ),
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
  final IconData icon;
  final String value;
  const StatItem({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
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

class XPCountUpState extends State<XPCountUp> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: Duration(milliseconds: (widget.target * 18).clamp(600, 1800)), vsync: this);
    _anim = IntTween(begin: 0, end: widget.target).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _ctrl.forward(); });
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
          const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFD465)),
          const SizedBox(height: 4),
          Text('+${_anim.value} XP', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
        ],
      ),
    );
  }
}