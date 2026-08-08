import 'package:flutter/material.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/screens/gameplay_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/widgets/shared/buttons.dart';
import 'package:folds/screens/store/payment_sheet.dart';


// ─────────────────────────────────────────────────────────────────────────────
// PUZZLE SELECTOR SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PuzzleSelectorScreen extends StatelessWidget {
  final String packName;
  final int totalPuzzles;
  final String idPrefix;
  final int idOffset;

  const PuzzleSelectorScreen({
    super.key,
    required this.packName,
    required this.totalPuzzles,
    required this.idPrefix,
    required this.idOffset,
  });

  @override
  Widget build(BuildContext context) {
    final completedPuzzles = Set<int>.from(
      List.generate(totalPuzzles, (i) => i + 1)
        .where((n) => AppStore.isCompleted('$idPrefix${idOffset + n}'))
    );
    final displayCount = totalPuzzles;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  FoldsTopBar(title: '$packName PACK', onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  // Progress bar
                  Container(
                    height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(8)),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: completedPuzzles.length / totalPuzzles,
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFFFFD465), borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${((completedPuzzles.length / totalPuzzles) * 100).toInt()}%',
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Scrollable puzzle grid — fills all remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: displayCount,
                  itemBuilder: (context, i) {
                    final puzzleNumber = i + 1;
                    final isCompleted = completedPuzzles.contains(puzzleNumber);
                    final puzzleId = '${idPrefix}${idOffset + puzzleNumber}';
                    return GestureDetector(
                      onTap: () {
                        // Paywall Check for Rectangle Pack
                        if (packName.contains('RECTANGLE') && puzzleNumber > 5) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              backgroundColor: Colors.white,
                              title: Text('Unlock Rectangle Pack', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 22)),
                              content: Text('You\'ve reached the end of the free preview! Unlock the remaining 95 Rectangle puzzles for endless folding fun.', style: GoogleFonts.dmSans(fontSize: 15)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Not Now', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => const PaymentSheet(
                                        productName: 'Rectangle Pack',
                                        price: '\$2.99',
                                      ),
                                    );
                                  },
                                  child: Text('Buy for \$2.99', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pushAndRemoveUntil(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: puzzleId),
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#$puzzleNumber',
                                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                                if (isCompleted)
                              Icon(
                                Icons.check_rounded,
                                color: AppStore.isParCompleted(puzzleId)
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFFD465),
                                size: 20,
                              ),
                              ],
                            ),
                            Icon(Icons.play_arrow_rounded,
                              color: isCompleted ? Colors.white54 : Colors.white, size: 28),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: CustomBackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}


