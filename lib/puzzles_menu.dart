import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// We reference the exact components from your main file
class PuzzlesMenuScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onPlayPilot;
  final VoidCallback onOpenPilotDetails;

  const PuzzlesMenuScreen({
    super.key,
    required this.onBack,
    required this.onPlayPilot,
    required this.onOpenPilotDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // ── Custom Top Bar ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8E8E8),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: 3.1416 / 4,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.black, width: 2.5),
                                bottom: BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'PUZZLES',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 24),

              // ── Daily Puzzle Banner ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'DAILY PUZZLE',
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF444444),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#551',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Archive
                  Container(
                    width: 76,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 2x2 Pack Grid ─────────────────────────────────────────────
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Using standard containers to guarantee zero dependency crashes
                    _StaticPackCard(
                      title: 'PILOT PACK',
                      subtitle: '100 PUZZLES',
                      progress: 0.79,
                      isCircle: false,
                      onPlay: onPlayPilot,
                      onHome: onOpenPilotDetails,
                    ),
                    _StaticPackCard(
                      title: 'RECTANGLE PACK',
                      subtitle: '100 PUZZLES',
                      progress: 0.0,
                      isCircle: false,
                      onPlay: () {},
                      onHome: () {},
                    ),
                    _StaticPackCard(
                      title: 'RADIAL PACK',
                      subtitle: '100 PUZZLES',
                      progress: 0.0,
                      isCircle: true,
                      onPlay: () {},
                      onHome: () {},
                    ),
                    _StaticPackCard(
                      title: 'HEXA PACK',
                      subtitle: '100 PUZZLES',
                      progress: 0.0,
                      isCircle: false,
                      onPlay: () {},
                      onHome: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticPackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final bool isCircle;
  final VoidCallback onPlay;
  final VoidCallback onHome;

  const _StaticPackCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.isCircle,
    required this.onPlay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF444444),
                      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: isCircle ? null : BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        title.replaceAll(' PACK', '\nPACK'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white60)),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF444444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        if (progress > 0)
                          Expanded(
                            flex: (progress * 100).toInt(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD465),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        Expanded(
                          flex: ((1.0 - progress) * 100).toInt(),
                          child: const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: IconButton(icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24), onPressed: onPlay)),
                Container(width: 1, height: 20, color: const Color(0xFF333333)),
                Expanded(child: IconButton(icon: const Icon(Icons.home_rounded, color: Colors.white, size: 20), onPressed: onHome)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}