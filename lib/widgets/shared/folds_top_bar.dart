import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class FoldsTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const FoldsTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
            child: Center(
              child: Transform.rotate(
                angle: 3.1416 / 4,
                child: Container(
                  width: 14, height: 14,
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
        Text(title, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.black)),
        const SizedBox(width: 40),
      ],
    );
  }
}