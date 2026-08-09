import 'package:flutter/material.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/painters/store_shape_painters.dart';
import 'package:folds/screens/redeem_dialog.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'STORE', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),

              // ── Expansion discount banner ─────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black),
                          children: const [
                            TextSpan(text: 'Buy now', style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: ' and you will be eligible for '),
                            TextSpan(text: 'Expansion Discounts', style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('LEARN MORE',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              
              // ── Stacked full-width packs ──────────────────
              FullWidthStoreCard(
                title: 'NO ADS',
                subtitle: 'REMOVE ALL ADS FOREVER',
                price: '\$2.99',
                shape: StoreShape.noAds,
                productId: 'games.jaydev.folds.no_ads',
              ),
              const SizedBox(height: 12),
              FullWidthStoreCard(
                title: 'RECTANGLE PACK',
                subtitle: '100 PUZZLES',
                price: '\$2.99',
                shape: StoreShape.rectangle,
                productId: 'games.jaydev.folds.rectangle_pack',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('More Puzzles Coming Soon!',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black38)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Hints row ──────────────────────────────────
              Row(
                children: [
                  Expanded(child: HintCard(label: '5 HINTS', price: '\$0.99', productId: 'games.jaydev.folds.hints_5')),
                  const SizedBox(width: 8),
                  Expanded(child: HintCard(label: '25 HINTS', price: '\$3.99', productId: 'games.jaydev.folds.hints_25')),
                  const SizedBox(width: 8),
                  Expanded(child: HintCard(label: '∞ HINTS', price: '\$7.99', productId: 'games.jaydev.folds.hints_unlimited')),
                ],
              ),
              const SizedBox(height: 8),

              // ─────────────────────────────────────────────────────────────────────────────
// REDEEM CODE SECTION (Add to Store UI Column)
// ─────────────────────────────────────────────────────────────────────────────
Container(
  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xFFE8E8E8),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'HAVE A PROMO CODE?',
        style: GoogleFonts.dmSans(
          fontSize: 14, 
          fontWeight: FontWeight.w800, 
          color: Colors.black45,
          letterSpacing: 0.5
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Redeem custom 16-digit access tokens for texture packs, puzzle packs, or unique profile marks.',
        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54, height: 1.4),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => showRedeemDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'ENTER 16-CHARACTER CODE',
              style: GoogleFonts.dmSans(
                fontSize: 14, 
                fontWeight: FontWeight.w700, 
                color: Colors.white,
                letterSpacing: 0.5
              ),
            ),
          ),
        ),
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



class FullWidthStoreCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final StoreShape shape;
  final String productId;

  const FullWidthStoreCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.shape,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  ShapeWidget(shape: shape, size: 64),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD465),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(price,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Hint card ─────────────────────────────────────────────────────────────────
class HintCard extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final String productId;

  const HintCard({
    required this.label, required this.price, required this.productId,
  }) : badge = null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                const SizedBox(height: 10),
                Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                const Icon(Icons.lightbulb_outline_rounded, color: Colors.white54, size: 28),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD465),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(price,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD465),
                    shape: BoxShape.circle,
                  ),
                  child: Text(badge!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black, height: 1.1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

