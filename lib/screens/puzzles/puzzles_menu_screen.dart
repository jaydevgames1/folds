import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:folds/state/app_store.dart';
import 'puzzle_selector_screen.dart';
import 'package:folds/core/constants.dart';
import 'dart:async';
import 'package:folds/main.dart';
import 'package:folds/painters/icon_painters.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/screens/puzzles/pilot_pack_detail_screen.dart';
import 'package:folds/screens/puzzles/daily_archive_screen.dart';
import 'package:folds/screens/gameplay_screen.dart';

class PuzzlesMenuScreen extends StatefulWidget {
  const PuzzlesMenuScreen({super.key});
  @override
  State<PuzzlesMenuScreen> createState() => PuzzlesMenuScreenState();
}

class PuzzlesMenuScreenState extends State<PuzzlesMenuScreen> {
  bool _downloadBusy = false;
  String _countdown = '';
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_tick);
    });
  }

  void _tick() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final d = midnight.difference(now);
    _countdown = '${d.inHours.toString().padLeft(2,'0')}:${(d.inMinutes % 60).toString().padLeft(2,'0')}:${(d.inSeconds % 60).toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _playPack(String prefix, int count) {
    String target = '${prefix}1';
    for (int i = 1; i <= count; i++) {
      if (!AppStore.isCompleted('$prefix$i')) { target = '$prefix$i'; break; }
    }
    Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: target),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 320),
    ), (route) => false);
  }

  Future<void> _handleDownloadTap() async {
    final has = AppStore.hasOfflinePuzzles;
    final count = AppStore.offlinePuzzleCount;

    if (has) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text('Offline Puzzles', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
          content: Text(
            '$count puzzles are cached locally (~${(count * 0.5).ceil()} KB). '
            'You can play without internet. Remove the offline data?',
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.red)),
            ),
          ],
        ),
      );
      if (remove == true) {
        await AppStore.clearOfflinePuzzles();
        setState(() {});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Offline puzzles removed.',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF2C2C2C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      return;
    }

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: Color(0xFF2C2C2C)),
            const SizedBox(width: 10),
            Text('Download Puzzles', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download all puzzle data to your device so you can play offline — anytime, anywhere, no internet needed.',
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Approx. size: ~150 KB. Progress still syncs when back online.',
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text('Cancel',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45)),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Download',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (go != true) return;
    setState(() => _downloadBusy = true);
    final result = await AppStore.downloadAllPuzzles();
    setState(() => _downloadBusy = false);
    if (!mounted) return;
    if (result != null) AppStore.unlockAchievement('just_in_case');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null
        ? '✅ ${result['count']} puzzles cached (${result['sizeKB']} KB) — play offline anytime!'
        : '❌ Download failed. Check your connection.',
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
      backgroundColor: const Color(0xFF2C2C2C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasCached = AppStore.hasOfflinePuzzles;
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: GestureDetector(
        onTap: _downloadBusy ? null : _handleDownloadTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _downloadBusy
            ? const Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              )
            : Icon(
                hasCached ? Icons.download_done_rounded : Icons.download_rounded,
                color: hasCached ? const Color(0xFF7BD957) : Colors.white,
                size: 26,
              ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'PUZZLES', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      height: 120,
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('DAILY PUZZLE', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color.fromARGB(0, 66, 66, 68), borderRadius: BorderRadius.circular(6)),
                            child: Text('#${foldsDayNumberFor(DateTime.now())}',
                              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            foldsDayNumberFor(DateTime.now()) < 1
                              ? 'Launches in $_countdown'
                              : 'Next daily in $_countdown',
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => pushFade(context, const DailyArchiveScreen()),
                    child: Container(
                      width: 76, height: 120,
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                      child: Center(child: CustomPaint(size: const Size(28, 24), painter: ArchiveIconPainter())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (!kBetaMode && !DateTime.now().isBefore(kHolidayPackUnlockDate)) ...[
                        const HolidayPackBanner(),
                        const SizedBox(height: 14),
                      ],

                      SizedBox(
                        height: 190,
                        child: kBetaMode
                            ? const LockedPackCard(title: 'PILOT PACK', subtitle: '100 PUZZLES')
                            : MenuPackCard(
                                title: 'PILOT PACK',
                                subtitle: '100 PUZZLES',
                                completedPuzzles: AppStore.completedInRange('p', 0, 100),
                                totalPuzzles: 100,
                                shapeType: PackShapeType.square,
                                onPlay: () => _playPack('p', 100),
                                onHome: () => pushFade(context, const PilotPackDetailScreen()),
                              ),
                      ),
                      const SizedBox(height: 14),

                      SizedBox(
                        height: 230,
                        child: kBetaMode
                            ? const LockedPackCard(title: 'RECTANGLE PACK', subtitle: '100 PUZZLES')
                            : MenuPackCard(
                                title: 'RECTANGLE PACK',
                                subtitle: '100 PUZZLES',
                                completedPuzzles: AppStore.completedInRange('r', 0, 100),
                                totalPuzzles: 100,
                                shapeType: PackShapeType.rectangle,
                                onPlay: () => _playPack('r', 100),
                                onHome: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => const PuzzleSelectorScreen(
                                      packName: 'RECTANGLE', totalPuzzles: 100, idPrefix: 'r', idOffset: 0),
                                  ));
                                },
                              ),
                      ),

                      if (kBetaMode) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 190,
                          child: MenuPackCard(
                            title: 'BETA PACK',
                            subtitle: '$kBetaPuzzleCount PUZZLES',
                            completedPuzzles: AppStore.completedInRange(kBetaPuzzlePrefix, 0, kBetaPuzzleCount),
                            totalPuzzles: kBetaPuzzleCount,
                            shapeType: PackShapeType.square,
                            onPlay: () => _playPack(kBetaPuzzlePrefix, kBetaPuzzleCount),
                            onHome: () => Navigator.push(context, MaterialPageRoute(
                              builder: (context) => PuzzleSelectorScreen(
                                packName: 'BETA', totalPuzzles: kBetaPuzzleCount,
                                idPrefix: kBetaPuzzlePrefix, idOffset: 0),
                            )),
                          ),
                        ),
                      ],

                      if (!kBetaMode && DateTime.now().isBefore(kHolidayPackUnlockDate)) ...[
                        const SizedBox(height: 14),
                        const HolidayPackBanner(),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Center(
                                child: Text('MORE PUZZLES COMING SOON!',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
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
  final bool disabled;
  const SixSMCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (disabled) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Unavailable in Beta Mode', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFF2C2C2C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
            return;
          }
          onTap();
        },
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Container(
            height: 160,
            decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    if (disabled) const Icon(Icons.lock_rounded, color: Colors.white38, size: 16),
                  ],
                ),
                Center(child: Icon(icon, size: 56, color: const Color(0xFF555555))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLES MENU PACK CARD (Pilot / Rectangle / Beta)
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
// LOCKED PACK CARD (Pilot / Rectangle when Beta Mode is on)
// ─────────────────────────────────────────────────────────────────────────────
class LockedPackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const LockedPackCard({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.black26, size: 32),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black38)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black26)),
          const SizedBox(height: 8),
          Text('LOCKED IN BETA', style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black26, letterSpacing: 1)),
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
    final unlockDate = kHolidayPackUnlockDate;
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