import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class CustomBackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const CustomBackButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

class ActionPill extends StatelessWidget {
  final String label;
  final Color? textColor;
  final VoidCallback onTap;

  const ActionPill({required this.label, this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor ?? Colors.black26)),
        ),
      ),
    );
  }
}

class OpenRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const OpenRow({required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('OPEN',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class DevBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  const DevBtn({required this.label, required this.onTap, this.textColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor ?? Colors.black)),
    ),
  );
}

class DevChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const DevChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
    ),
  );
}

class DevLabel extends StatelessWidget {
  final String text;
  const DevLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1.2)),
  );
}

class CustomFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const CustomFilterChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2C2C2C) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: active ? Colors.white : Colors.black45)),
    ),
  );
}

