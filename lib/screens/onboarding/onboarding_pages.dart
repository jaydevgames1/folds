import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/painters/icon_painters.dart';

class OnboardPageSixSM extends StatelessWidget {
  const OnboardPageSixSM();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.extension_rounded, 'Puzzles', 'Browse all packs & daily'),
      (Icons.account_circle_rounded, 'Profile', 'XP, rank & achievements'),
      (Icons.shopping_basket_rounded, 'Store', 'Unlock more packs'),
      (Icons.settings_rounded, 'Settings', 'Timer, haptics & more'),
      (Icons.favorite_rounded, 'Socials', 'YouTube, Discord, TikTok'),
      (Icons.handshake_rounded, 'Credits', 'The team behind Folds'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFFE8E8E8), shape: BoxShape.circle),
            child: ClipOval(child: CustomPaint(painter: HomeIconPainter())),
          ),
          const SizedBox(height: 16),
          Text('The Home Button', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Tap the circle in the top-left corner of any puzzle to open the navigation menu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(item.$1, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.$2, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(item.$3, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white38)),
                    ],
                  )),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class OnboardPage1 extends StatelessWidget {
  const OnboardPage1();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFD3D3D3),
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(painter: HomeIconPainter()),
            ),
          ),
          const SizedBox(height: 36),
          Text('Welcome to Folds',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 16),
          Text(
            'A minimalist tile-switching puzzle game. Simple to learn, deeply satisfying to master.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 16, color: Colors.black54, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class OnboardPage2 extends StatelessWidget {
  const OnboardPage2();

  static const _before = [
    true,  false, true,  true,
    false, true,  false, true,
    true,  true,  false, false,
    false, false, true,  false,
  ];
  static const _after = [
    true,  false, false, true,
    false, true,  true,  false,
    true,  false, false, true,
    false, true,  true,  false,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Make it Symmetrical',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 12),
          Text(
            'Tap tiles to flip them black or white. Your goal: every row must mirror itself left to right.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OnboardMiniGrid(cells: _before, label: 'Unsolved'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('→',
                  style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black26)),
              ),
              OnboardMiniGrid(cells: _after, label: 'Solved ✓', solved: true),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardMiniGrid extends StatelessWidget {
  final List<bool> cells;
  final String label;
  final bool solved;
  const OnboardMiniGrid({required this.cells, required this.label, this.solved = false});

  @override
  Widget build(BuildContext context) {
    const n = 4;
    const cellSize = 18.0;
    const gap = 4.0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(10),
            border: solved ? Border.all(color: const Color(0xFF4CAF50), width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(n, (row) => Padding(
              padding: EdgeInsets.only(bottom: row < n - 1 ? gap : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(n, (col) => Padding(
                  padding: EdgeInsets.only(right: col < n - 1 ? gap : 0),
                  child: Container(
                    width: cellSize, height: cellSize,
                    decoration: BoxDecoration(
                      color: cells[row * n + col] ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
              ),
            )),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: solved ? const Color(0xFF4CAF50) : Colors.black38)),
      ],
    );
  }
}

class OnboardResultRow extends StatelessWidget {
  final String stamp;
  final Color stampColor;
  final String label;
  final String detail;
  const OnboardResultRow({
    required this.stamp, required this.stampColor,
    required this.label, required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(stamp, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: stampColor)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
              Text(detail, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45)),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardPageFinal extends StatelessWidget {
  const OnboardPageFinal();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧩', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('You\'re Ready!', textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('Every day a new daily puzzle drops. Hit par to earn maximum XP and a gold stamp.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54, height: 1.6)),
          const SizedBox(height: 28),
          OnboardResultRow(stamp: '★', stampColor: const Color(0xFFFFD465),
            label: 'At or under par', detail: 'Maximum XP — Gold stamp'),
          const SizedBox(height: 8),
          OnboardResultRow(stamp: '✦', stampColor: Colors.black38,
            label: 'Over par', detail: 'Partial XP earned'),
          const SizedBox(height: 8),
          OnboardResultRow(stamp: '—', stampColor: Colors.black12,
            label: 'Way over par', detail: 'No XP awarded'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFFD465)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Some tiles are linked — flipping one flips all tiles with the same shape badge.',
                style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54, height: 1.4))),
            ]),
          ),
        ],
      ),
    );
  }
}
