import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:folds/core/constants.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/main.dart';
import 'package:folds/painters/icon_painters.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/screens/puzzles/pack_cards.dart';
import 'package:folds/screens/puzzles/pilot_pack_detail_screen.dart';
import 'package:folds/screens/puzzles/puzzle_selector_screen.dart';
import 'package:folds/screens/puzzles/daily_archive_screen.dart';

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
              // Replace the Expanded GridView.count with:
Expanded(
  child: SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Column(
      children: [
        // Holiday pack at TOP when unlocked
        if (!DateTime.now().isBefore(DateTime(2026, 12, 10))) ...[
          const HolidayPackBanner(),
          const SizedBox(height: 14),
        ],
        SizedBox(
          height: 190,
          child: MenuPackCard(
            title: 'PILOT PACK',
            subtitle: '100 PUZZLES',
            completedPuzzles: AppStore.completedInRange('p', 0, 100),
            totalPuzzles: 100,
            shapeType: PackShapeType.square,
            onPlay: () => Navigator.pop(context),
            onHome: () => pushFade(context, const PilotPackDetailScreen()),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: MenuPackCard(
            title: 'RECTANGLE PACK',
            subtitle: '100 PUZZLES',
            completedPuzzles: AppStore.completedInRange('r', 0, 100),
            totalPuzzles: 100,
            shapeType: PackShapeType.rectangle,
            onPlay: () {},
            onHome: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const PuzzleSelectorScreen(
                  packName: 'RECTANGLE', totalPuzzles: 100, idPrefix: 'r', idOffset: 0),
              ));
            },
          ),
        ),
        // Holiday pack at BOTTOM when not yet unlocked
        if (DateTime.now().isBefore(DateTime(2026, 12, 10))) ...[
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

